package api

import (
	"context"
	"errors"
	"fmt"
	"time"

	"goa.design/goa/v3/security"

	"gitlab.com/fieldkit/cloud/server/api/gen/moderation"
	moderationService "gitlab.com/fieldkit/cloud/server/api/gen/moderation"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common"
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

func (s *ModerationService) Add(ctx context.Context, payload *moderation.ModerationAddPayload) (*moderation.ModerationRequest, error) {
	tx, err := s.options.Database.Begin(ctx)
	if err != nil {
		return nil, err
	}

	response, err := s.add(ctx, payload)
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	err = tx.Commit()
	return response, err
}

func (s *ModerationService) add(ctx context.Context, payload *moderation.ModerationAddPayload) (*moderation.ModerationRequest, error) {
	log := Logger(context.Background()).Sugar()

	p, err := NewPermissions(context.Background(), s.options).Unwrap()
	if err != nil {
		return nil, err
	}

	if payload.PostType != string(data.ModerationDiscussionPost) && payload.PostType != string(data.ModerationDataEvent) {
		return nil, fmt.Errorf("invalid post type")
	}

	log.Infow("adding moderation request", "post_id", payload.PostID, "post_type", payload.PostType)

	mrRepo := repositories.NewModerationRepository(s.options.Database)
	mr := &data.ModerationRequest{
		PostID:     payload.PostID,
		PostType:   data.PostTypeEnum(payload.PostType),
		ReportedBy: p.UserID(),
		ReportedAt: time.Now().UTC(),
	}

	created, err := mrRepo.AddModerationRequest(ctx, mr)
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

	response := &moderation.ModerationRequest{
		ID:         created.ID,
		PostID:     created.PostID,
		PostType:   string(created.PostType),
		ReportedBy: created.ReportedBy,
		ReportedAt: created.ReportedAt.Format(time.RFC3339),
	}

	return response, nil
}

func createEmailBody(payload *moderation.ModerationAddPayload) string {
	return fmt.Sprintf("A new moderation request has been created for post ID %d and post type %s.", payload.PostID, payload.PostType)
}

func sendMockEmail(to string, subject string, body string) error {
	fmt.Printf("Mock sending email to: %s\nSubject: %s\nBody: %s\n", to, subject, body)
	return nil
}

func (s *ModerationService) Acknowledge(ctx context.Context, payload *moderation.AcknowledgePayload) (*moderation.ModerationRequest, error) {
	mrRepo := repositories.NewModerationRepository(s.options.Database)

	moderationRequest, err := mrRepo.GetModerationRequest(ctx, int(payload.ID))
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	moderationRequest.AcknowledgedAt = &now

	err = mrRepo.UpdateModerationRequest(ctx, moderationRequest)
	if err != nil {
		return nil, err
	}

	var acknowledgedAtStr *string
	if moderationRequest.AcknowledgedAt != nil {
		str := moderationRequest.AcknowledgedAt.Format(time.RFC3339)
		acknowledgedAtStr = &str
	}

	response := &moderation.ModerationRequest{
		ID:             moderationRequest.ID,
		PostID:         moderationRequest.PostID,
		PostType:       string(moderationRequest.PostType),
		ReportedBy:     moderationRequest.ReportedBy,
		ReportedAt:     moderationRequest.ReportedAt.Format(time.RFC3339),
		AcknowledgedBy: &payload.AcknowledgedBy,
		AcknowledgedAt: acknowledgedAtStr,
	}

	return response, nil
}

func (s *ModerationService) JWTAuth(ctx context.Context, token string, scheme *security.JWTScheme) (context.Context, error) {
	return Authenticate(ctx, common.AuthAttempt{
		Token:        token,
		Scheme:       scheme,
		Key:          s.options.JWTHMACKey,
		NotFound:     func(m string) error { return moderationService.MakeNotFound(errors.New(m)) },
		Unauthorized: func(m string) error { return moderationService.MakeUnauthorized(errors.New(m)) },
		Forbidden:    func(m string) error { return moderationService.MakeForbidden(errors.New(m)) },
	})
}
