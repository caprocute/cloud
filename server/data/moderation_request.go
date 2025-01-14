package data

import "time"

type PostTypeEnum string

const (
	ModerationDiscussionPost PostTypeEnum = "discussion_post"
	ModerationDataEvent      PostTypeEnum = "data_event"
)

type ModerationAddPayload struct {
	PostID   int               `json:"post_id"`
	PostType PostTypeEnum      `json:"post_type"`
}

type ModerationRequestResponse struct {
	ID             int         `json:"id"`
	PostID         int         `json:"post_id"`
	PostType       PostTypeEnum `json:"post_type"`
	ReportedBy     int         `json:"reported_by"`
	ReportedAt     time.Time   `json:"reported_at"`
	AcknowledgedBy *int        `json:"acknowledged_by,omitempty"`
	AcknowledgedAt *time.Time  `json:"acknowledged_at,omitempty"`
}
