package api

// import (
//     "database/sql"
//     "time"
//     moderation_request
// )

// type ModerationRequestService struct {
//     DB *sqlxcache.DB
// }

// func (s *ModerationRequestService) CreateModerationRequest(targetID int, targetType string, reportedBy int) error {
//     query := `
//         INSERT INTO moderation_request (target_id, target_type, reported_by, is_acknowledged, reported_at)
//         VALUES ($1, $2, $3, FALSE, NOW())
//     `
//     _, err := s.DB.Exec(query, targetID, targetType, reportedBy)
//     return err
// }

// func (s *ModerationRequestService) AcknowledgeModerationRequest(id int, acknowledgedBy int) error {
//     query := `
//         UPDATE moderation_request
//         SET is_acknowledged = TRUE, acknowledged_by = $1, acknowledged_at = NOW()
//         WHERE id = $2
//     `
//     _, err := s.DB.Exec(query, acknowledgedBy, id)
//     return err
// }

// func (s *ModerationRequestService) ListPendingModerationRequests() ([]models.ModerationRequest, error) {
//     query := `
//         SELECT id, target_id, target_type, reported_by, acknowledged_by, is_acknowledged, reported_at, acknowledged_at
//         FROM moderation_request
//         WHERE is_acknowledged = FALSE
//         ORDER BY reported_at ASC
//     `
//     rows, err := s.DB.Query(query)
//     if err != nil {
//         return nil, err
//     }
//     defer rows.Close()

//     var requests []models.ModerationRequest
//     for rows.Next() {
//         var request models.ModerationRequest
//         err := rows.Scan(&request.ID, &request.TargetID, &request.TargetType, &request.ReportedBy,
//             &request.AcknowledgedBy, &request.IsAcknowledged, &request.ReportedAt, &request.AcknowledgedAt)
//         if err != nil {
//             return nil, err
//         }
//         requests = append(requests, request)
//     }
//     return requests, nil
// }
