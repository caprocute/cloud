package repositories

import (
	"context"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/common"
)

type ModerationRepository struct {
	db common.DB
}

func NewModerationRepository(db common.DB) *ModerationRepository {
	return &ModerationRepository{db: db}
}

func (repo *ModerationRepository) AddModerationRequest(ctx context.Context, request *data.ModerationRequest) (*data.ModerationRequest, error) {
	query := `INSERT INTO moderation_requests (post_id, post_type, reported_by, reported_at)
			  VALUES (?, ?, ?, ?) RETURNING id`
	
	var newID int
	err := repo.db.QueryRowContext(ctx, query, request.PostID, request.PostType, request.ReportedBy, request.ReportedAt).
		Scan(&newID)
	if err != nil {
		return nil, err
	}

	request.ID = newID
	return request, nil
}

func (repo *ModerationRepository) GetAllModerationRequests(ctx context.Context) ([]data.ModerationRequest, error) {
	query := `SELECT id, post_id, post_type, reported_by, reported_at, acknowledged_by, acknowledged_at
			  FROM moderation_requests`
	
	rows, err := repo.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []data.ModerationRequest
	for rows.Next() {
		var request data.ModerationRequest
		err := rows.Scan(
			&request.ID,
			&request.PostID,
			&request.PostType,
			&request.ReportedBy,
			&request.ReportedAt,
			&request.AcknowledgedBy,
			&request.AcknowledgedAt,
		)
		if err != nil {
			return nil, err
		}
		requests = append(requests, request)
	}
	return requests, nil
}

func (repo *ModerationRepository) UpdateModerationRequest(ctx context.Context, request *data.ModerationRequest) error {
	query := `UPDATE moderation_requests 
			  SET acknowledged_by = ?, acknowledged_at = ?
			  WHERE id = ?`

	_, err := repo.db.ExecContext(ctx, query, request.AcknowledgedBy, request.AcknowledgedAt, request.ID)
	return err
}
