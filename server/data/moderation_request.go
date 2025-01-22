package data

import "time"

type PostTypeEnum string

const (
	ModerationDiscussionPost PostTypeEnum = "discussion_post"
	ModerationDataEvent      PostTypeEnum = "data_event"
)

type Moderator struct {
	ID        int       `json:"id"`
	UserID    int32     `json:"user_id"`
	CreatedAt time.Time `json:"created_at"`
}

type ModerationAddPayload struct {
	PostID   int32        `json:"post_id"`
	PostType PostTypeEnum `json:"post_type"`
}

type ModerationRequest struct {
	ID             int32        `json:"id"`
	PostID         int32        `json:"post_id"`
	PostType       PostTypeEnum `json:"post_type"`
	ReportedBy     int32        `json:"reported_by"`
	ReportedAt     time.Time    `json:"reported_at"`
	AcknowledgedBy *int32       `json:"acknowledged_by,omitempty"`
	AcknowledgedAt *time.Time   `json:"acknowledged_at,omitempty"`
}
