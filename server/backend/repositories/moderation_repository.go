package repositories

import (
	"context"
	"database/sql"
	"fmt"

	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
)

type ModerationRepository struct {
	db *sqlxcache.DB
}

func NewModerationRepository(db *sqlxcache.DB) *ModerationRepository {
	return &ModerationRepository{db: db}
}

func (r *ModerationRepository) GetAllModerators(ctx context.Context) ([]data.Moderator, error) {
	var moderators []data.Moderator
	query := `
		SELECT id, user_id, created_at
		FROM fieldkit.moderators
	`

	err := r.db.SelectContext(ctx, &moderators, query)
	if err != nil {
		return nil, err
	}

	return moderators, nil
}

func (r *ModerationRepository) GetAllModerationRequests(ctx context.Context, page, pageSize int32) ([]*data.ModerationRequestDetail, int32, error) {
	query := `
		SELECT 
			mr.id,
			mr.post_id,
			mr.post_type,
			mr.reported_by,
			reporter.name as reporter_name,
			mr.reported_at,
			mr.acknowledged_by,
			acknowledger.name as acknowledger_name,
			mr.acknowledged_at
		FROM fieldkit.moderation_request mr
		LEFT JOIN fieldkit.user reporter ON reporter.id = mr.reported_by
		LEFT JOIN fieldkit.user acknowledger ON acknowledger.id = mr.acknowledged_by
		ORDER BY mr.reported_at DESC
		LIMIT :pageSize OFFSET :offset
	`

	params := map[string]interface{}{
		"pageSize": pageSize,
		"offset":   page * pageSize,
	}

	rows, err := r.db.NamedQueryContext(ctx, query, params)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var requests []*data.ModerationRequestDetail
	for rows.Next() {
		var req data.ModerationRequestDetail
		var reporterName, acknowledgerName sql.NullString

		err := rows.Scan(
			&req.ID,
			&req.PostID,
			&req.PostType,
			&req.ReportedBy,
			&reporterName,
			&req.ReportedAt,
			&req.AcknowledgedBy,
			&acknowledgerName,
			&req.AcknowledgedAt,
		)
		if err != nil {
			return nil, 0, err
		}

		if reporterName.Valid {
			req.ReportedByName = &reporterName.String
		}
		if acknowledgerName.Valid {
			req.AcknowledgedByName = &acknowledgerName.String
		}

		requests = append(requests, &req)
	}

	var totalCount int32
	err = r.db.GetContext(ctx, &totalCount, "SELECT COUNT(*) FROM fieldkit.moderation_request")
	if err != nil {
		return nil, 0, err
	}

	totalPages := (totalCount + pageSize - 1) / pageSize

	return requests, totalPages, nil
}

func (r *ModerationRepository) AddModerationRequest(ctx context.Context, request *data.ModerationRequest) (*data.ModerationRequest, error) {
	query := `
		INSERT INTO fieldkit.moderation_request
		(post_id, post_type, reported_by, reported_at)
		VALUES (:post_id, :post_type, :reported_by, :reported_at)
		RETURNING id
	`

	err := r.db.NamedGetContext(ctx, request, query, request)
	if err != nil {
		return nil, err
	}

	return request, nil
}

func (r *ModerationRepository) GetModerationRequest(ctx context.Context, requestID int) (*data.ModerationRequest, error) {
	var moderationRequest data.ModerationRequest
	query := `
		SELECT id, post_id, post_type, reported_by, reported_at, acknowledged_by, acknowledged_at
		FROM fieldkit.moderation_requests
		WHERE id = $1
	`

	err := r.db.GetContext(ctx, &moderationRequest, query, requestID)
	if err != nil {
		return nil, err
	}

	return &moderationRequest, nil
}

func (r *ModerationRepository) UpdateModerationRequest(ctx context.Context, request *data.ModerationRequest) error {
	query := `
		UPDATE fieldkit.moderation_requests
		SET acknowledged_by = $1, acknowledged_at = $2
		WHERE id = $3
	`

	_, err := r.db.ExecContext(ctx, query, request.AcknowledgedBy, request.AcknowledgedAt, request.ID)
	if err != nil {
		return err
	}

	return nil
}

func (r *ModerationRepository) AcknowledgeRequest(ctx context.Context, requestID, userID int32, action string) (*data.ModerationRequestDetail, error) {
	fetchQuery := `
		SELECT 
			mr.id,
			mr.post_id,
			mr.post_type
		FROM fieldkit.moderation_request mr
		WHERE mr.id = $1
	`

	var req struct {
		ID       int32  `db:"id"`
		PostID   int32  `db:"post_id"`
		PostType string `db:"post_type"`
	}

	err := r.db.GetContext(ctx, &req, fetchQuery, requestID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("moderation request not found: %d", requestID)
		}
		return nil, err
	}

	if action == "delete" {
		switch req.PostType {
		case "discussion_post":
			deleteQuery := `
				DELETE FROM fieldkit.discussion_post
				WHERE id = $1
			`
			_, err := r.db.ExecContext(ctx, deleteQuery, req.PostID)
			if err != nil {
				return nil, fmt.Errorf("failed to delete discussion post: %w", err)
			}

		case "data_event":
			deleteQuery := `
				UPDATE fieldkit.data_event
				SET note = NULL, modified_by = $1, modified = NOW()
				WHERE id = $2
			`
			_, err := r.db.ExecContext(ctx, deleteQuery, userID, req.PostID)
			if err != nil {
				return nil, fmt.Errorf("failed to delete data event note: %w", err)
			}
		default:
			return nil, fmt.Errorf("unsupported post type for deletion: %s", req.PostType)
		}
	}

	updateQuery := `
		UPDATE fieldkit.moderation_request
		SET acknowledged_by = $1,
			acknowledged_at = NOW()
		WHERE id = $2
	`

	_, err = r.db.ExecContext(ctx, updateQuery, userID, requestID)
	if err != nil {
		return nil, err
	}

	detailQuery := `
		SELECT 
			mr.id,
			mr.post_id,
			mr.post_type,
			mr.reported_by,
			reporter.name as reported_by_name,
			mr.reported_at,
			mr.acknowledged_by,
			acknowledger.name as acknowledged_by_name,
			mr.acknowledged_at
		FROM fieldkit.moderation_request mr
		LEFT JOIN fieldkit.user reporter ON reporter.id = mr.reported_by
		LEFT JOIN fieldkit.user acknowledger ON acknowledger.id = mr.acknowledged_by
		WHERE mr.id = $1
	`

	var detail data.ModerationRequestDetail
	err = r.db.GetContext(ctx, &detail, detailQuery, requestID)
	if err != nil {
		return nil, err
	}

	return &detail, nil
}

func (r *ModerationRepository) GetContent(ctx context.Context, postType data.PostTypeEnum, postID int32) (string, error) {
	var query string
	switch postType {
	case data.ModerationDiscussionPost:
		query = `
			SELECT body
			FROM fieldkit.discussion_post
			WHERE id = $1
		`
	case data.ModerationDataEvent:
		query = `
			SELECT note
			FROM fieldkit.data_event
			WHERE id = $1
		`
	default:
		return "", fmt.Errorf("unsupported post type: %s", postType)
	}

	var content string
	err := r.db.GetContext(ctx, &content, query, postID)
	if err != nil {
		if err == sql.ErrNoRows {
			return "", nil
		}
		return "", err
	}

	return content, nil
}
