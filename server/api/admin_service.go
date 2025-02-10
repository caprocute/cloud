package api

import (
	"context"
	"errors"
	"io"
	"os"

	"gitlab.com/fieldkit/cloud/server/api/gen/admin"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"

	"goa.design/goa/v3/security"

	"gitlab.com/fieldkit/cloud/server/common"
)

type AdminService struct {
	options *ControllerOptions
	db      *sqlxcache.DB
}

func NewAdminService(ctx context.Context, options *ControllerOptions) *AdminService {
	return &AdminService{
		options: options,
		db:      options.Database,
	}
}

func (s *AdminService) HealthEndpoint(ctx context.Context, payload *admin.HealthPayload) (*admin.Health, error) {
	pending := []int64{}
	if err := s.db.SelectContext(ctx, &pending, `SELECT COUNT(*) FROM fieldkit.gue_jobs WHERE queue != 'errors'`); err != nil {
		return nil, err
	}

	errors := []int64{}
	if err := s.db.SelectContext(ctx, &errors, `SELECT COUNT(*) FROM fieldkit.gue_jobs WHERE queue = 'errors'`); err != nil {
		return nil, err
	}

	return &admin.Health{
		Queue: &admin.QueueHealth{
			Pending: pending[0],
			Errors:  errors[0],
		},
	}, nil
}

func (s *AdminService) UploadBackup(ctx context.Context, payload *admin.UploadBackupPayload, body io.ReadCloser) (*admin.BackupCheck, error) {
	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return nil, err
	}

	log := Logger(ctx).Sugar()

	log.Infow("backup", "content_type", payload.ContentType, "content_length", payload.ContentLength, "user_id", p.UserID())

	f, err := os.CreateTemp("", "admin-backup-")
	if err != nil {
		return nil, err
	}

	copied, err := io.Copy(f, body)
	if err != nil {
		return nil, err
	}

	log.Infow("saved", "copied", copied, "file_name", f.Name())

	return nil, nil
}

func (s *AdminService) JWTAuth(ctx context.Context, token string, scheme *security.JWTScheme) (context.Context, error) {
	return Authenticate(ctx, common.AuthAttempt{
		Token:        token,
		Scheme:       scheme,
		Key:          s.options.JWTHMACKey,
		NotFound:     nil,
		Unauthorized: func(m string) error { return admin.MakeUnauthorized(errors.New(m)) },
		Forbidden:    func(m string) error { return admin.MakeForbidden(errors.New(m)) },
	})
}
