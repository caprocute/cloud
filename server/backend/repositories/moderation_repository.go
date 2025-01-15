package repositories

import (
	"context"
	"time"

	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
)

type ModerationRepository struct {
	db *sqlxcache.DB
}

func NewModerationRepository(db *sqlxcache.DB) (rr *ModerationRepository) {
	return &ModerationRepository{db: db}
}

func (r *ModerationRepository) GetAllModerators(ctx context.Context) ([]data.Moderator, error) {
	var moderators []data.Moderator
	query := "SELECT id, user_id, created_at FROM fieldkit.moderators"

	err := r.db.SelectContext(ctx, &moderators, query)
	if err != nil {
		return nil, err
	}

	return moderators, nil
}

func (r *ModerationRepository) GetAllModerationRequests(ctx context.Context) ([]*data.ModerationRequest, error) {
	moderations := []*data.ModerationRequest{}
	if err := r.db.SelectContext(ctx, &moderations, `
		SELECT id, post_id, post_type, reported_by, reported_at, acknowledged_by, acknowledged_at
		FROM fieldkit.moderation_requests
		ORDER BY reported_at DESC
		`); err != nil {
		return nil, err
	}

	return moderations, nil
}

func (r *ModerationRepository) AddModerationRequest(ctx context.Context, request *data.ModerationRequest) (*data.ModerationRequest, error) {
	if err := r.db.NamedGetContext(ctx, request, `
		INSERT INTO fieldkit.moderation_requests
		(post_id, post_type, reported_by, reported_at) VALUES
		(:post_id, :post_type, :reported_by, :reported_at)
		RETURNING id
		`, request); err != nil {
		return nil, err
	}
	return request, nil
}

func (r *ModerationRepository) GetModerationRequest(ctx context.Context, requestID int) (*data.ModerationRequest, error) {
	var moderationRequest data.ModerationRequest
	query := "SELECT id, post_id, post_type, reported_by, reported_at, acknowledged_by, acknowledged_at FROM moderation_requests WHERE id = $1"

	err := r.db.GetContext(ctx, &moderationRequest, query, requestID)
	if err != nil {
		return nil, err
	}

	return &moderationRequest, nil
}

func (r *ModerationRepository) AcknowledgeModerationRequest(ctx context.Context, requestID int, acknowledgedBy int, acknowledgedAt time.Time) error {
	if _, err := r.db.ExecContext(ctx, `
		UPDATE fieldkit.moderation_requests
		SET acknowledged_by = $1, acknowledged_at = $2
		WHERE id = $3
		`, acknowledgedBy, acknowledgedAt, requestID); err != nil {
		return err
	}
	return nil
}
