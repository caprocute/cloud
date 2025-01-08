package data

import "time"

type ModerationRequest struct {
    ID            int       `json:"id" db:"id"`
    TargetID      int       `json:"target_id" db:"target_id"`
    TargetType    string    `json:"target_type" db:"target_type"`
    ReportedBy    int       `json:"reported_by" db:"reported_by"`
    AcknowledgedBy *int     `json:"acknowledged_by,omitempty" db:"acknowledged_by"`
    IsAcknowledged bool     `json:"is_acknowledged" db:"is_acknowledged"`
    ReportedAt    time.Time `json:"reported_at" db:"reported_at"`
    AcknowledgedAt *time.Time `json:"acknowledged_at,omitempty" db:"acknowledged_at"`
}