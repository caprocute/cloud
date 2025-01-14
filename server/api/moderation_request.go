package api

import (
	"context"
	"errors"
	"time"

	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/messages"
)

type ModerationService struct {
	options *ControllerOptions
}

func NewModerationService(ctx context.Context, options *ControllerOptions) *ModerationService {
	return &ModerationService{
		options: options,
	}
}

func (s *ModerationService) Add(ctx context.Context, payload *ModerationAddPayload) (response *ModerationRequestResponse, err error) {
	tx, err := s.options.Database.Begin(ctx)
	if err != nil {
		return nil, err
	}

	txCtx := context.WithValue(ctx, common.TxContextKey, tx)
	response, err = s.add(txCtx, payload)
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	err = tx.Commit()
	return response, err
}

func (s *ModerationService) add(ctx context.Context, payload *ModerationAddPayload) (response *ModerationRequestResponse, err error) {
	log := Logger(ctx).Sugar()

	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return nil, err
	}

	if payload.PostType != data.ModerationDiscussionPost && payload.PostType != data.ModerationDataEvent {
		return nil, errors.New("invalid post_type")
	}

	log.Infow("adding moderation request", "post_id", payload.PostID, "post_type", payload.PostType)

	mr := repositories.NewModerationRepository(s.options.Database)

	newRequest := &data.ModerationRequest{
		PostID:     payload.PostID,
		PostType:   payload.PostType,
		ReportedBy: p.UserID(),
		ReportedAt: time.Now().UTC(),
	}

	created, err := mr.AddModerationRequest(ctx, newRequest)
	if err != nil {
		return nil, err
	}

	modRepo := repositories.NewModeratorsRepository(s.options.Database)
	moderators, err := modRepo.GetAllModerators(ctx)
	if err != nil {
		return nil, err
	}

	for _, moderator := range moderators {
		if err := s.options.Publisher.Publish(ctx, &messages.ModerationRequestCreated{
			ModeratorID: moderator.UserID,
			PostID:      payload.PostID,
			PostType:    payload.PostType,
		}); err != nil {
			log.Errorw("error sending moderation notification", "moderator_id", moderator.UserID, "error", err)
		}
	}

	response = &ModerationRequestResponse{
		ID:             created.ID,
		PostID:         created.PostID,
		PostType:       created.PostType,
		ReportedBy:     created.ReportedBy,
		ReportedAt:     created.ReportedAt,
		AcknowledgedBy: nil,
		AcknowledgedAt: nil,
	}

	return response, nil
}

func (s *ModerationService) Acknowledge(ctx context.Context, id int, acknowledgedBy int) (response *ModerationRequestResponse, err error) {
	mrRepo := repositories.NewModerationRepository(s.options.Database)

	// Retrieve the moderation request
	moderationRequest, err := mrRepo.GetModerationRequest(ctx, id)
	if err != nil {
		return nil, err
	}

	// Mark as acknowledged
	now := time.Now().UTC()
	moderationRequest.AcknowledgedBy = &acknowledgedBy
	moderationRequest.AcknowledgedAt = &now

	// Save the updated request
	err = mrRepo.UpdateModerationRequest(ctx, moderationRequest)
	if err != nil {
		return nil, err
	}

	// Return the updated response
	response = &ModerationRequestResponse{
		ID:             moderationRequest.ID,
		PostID:         moderationRequest.PostID,
		PostType:       moderationRequest.PostType,
		ReportedBy:     moderationRequest.ReportedBy,
		ReportedAt:     moderationRequest.ReportedAt,
		AcknowledgedBy: moderationRequest.AcknowledgedBy,
		AcknowledgedAt: moderationRequest.AcknowledgedAt,
	}

	return response, nil
}
