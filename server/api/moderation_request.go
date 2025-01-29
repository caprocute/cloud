package api

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/data"
)

type ModerationService struct {
	options *ControllerOptions
}

func NewModerationService(ctx context.Context, options *ControllerOptions) *ModerationService {
	return &ModerationService{
		options: options,
	}
}

func (s *ModerationService) Add(ctx context.Context, payload *data.ModerationAddPayload) (response *data.ModerationRequest, err error) {
	tx, err := s.options.Database.Begin(ctx)
	if err != nil {
		return nil, err
	}

	response, err = s.add(tx, payload)
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	err = tx.Commit()
	return response, err
}

func (s *ModerationService) add(tx *sqlx.Tx, payload *data.ModerationAddPayload) (response *data.ModerationRequest, err error) {
	log := Logger(context.Background()).Sugar()

	p, err := NewPermissions(context.Background(), s.options).Unwrap()
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

	created, err := mr.AddModerationRequest(context.Background(), newRequest)
	if err != nil {
		return nil, err
	}

	modRepo := repositories.NewModerationRepository(s.options.Database)
	moderators, err := modRepo.GetAllModerators(context.Background())
	if err != nil {
		return nil, err
	}

	// Assuming you have a method or repo to get user info by user_id
	userRepo := repositories.NewUserRepository(s.options.Database)

	for _, moderator := range moderators {
		// Fetch user details to get the email
		user, err := userRepo.QueryByID(context.Background(), moderator.UserID)
		if err != nil {
			log.Errorw("error retrieving user details", "moderator_id", moderator.UserID, "error", err)
			continue
		}

		// Simulate email sending (replace with real implementation later)
		err = sendMockEmail(user.Email, "New Moderation Request", createEmailBody(payload))
		if err != nil {
			log.Errorw("error sending email notification", "moderator_id", moderator.UserID, "error", err)
		} else {
			log.Infow("email notification sent", "moderator_id", moderator.UserID)
		}
	}

	response = &data.ModerationRequest{
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

func createEmailBody(payload *data.ModerationAddPayload) string {
	return fmt.Sprintf("A new moderation request has been created for post ID %d and post type %s.", payload.PostID, payload.PostType)
}

func sendMockEmail(to string, subject string, body string) error {
	fmt.Printf("Mock sending email to: %s\nSubject: %s\nBody: %s\n", to, subject, body)
	return nil
}

func (s *ModerationService) Acknowledge(ctx context.Context, payload *data.AcknowledgePayload) (response *data.ModerationRequest, err error) {
	mrRepo := repositories.NewModerationRepository(s.options.Database)

	moderationRequest, err := mrRepo.GetModerationRequest(ctx, payload.ID)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	moderationRequest.AcknowledgedAt = &now

	err = mrRepo.UpdateModerationRequest(ctx, moderationRequest)
	if err != nil {
		return nil, err
	}

	response = &data.ModerationRequest{
		ID:             moderationRequest.ID,
		PostID:         moderationRequest.PostID,
		PostType:       moderationRequest.PostType,
		ReportedBy:     moderationRequest.ReportedBy,
		ReportedAt:     moderationRequest.ReportedAt,
		AcknowledgedBy: payload.AcknowledgedBy,
		AcknowledgedAt: moderationRequest.AcknowledgedAt,
	}

	return response, nil
}
