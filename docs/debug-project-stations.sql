-- ============================================================
-- Script debug: Kiểm tra tại sao markers không hiển thị
-- ============================================================

-- 1. Kiểm tra stations có trong project_station table không
SELECT 
    ps.project_id,
    p.name AS project_name,
    p.privacy,
    ps.station_id,
    s.name AS station_name,
    s.location IS NOT NULL AS has_location,
    CASE 
        WHEN s.location IS NULL THEN 'NULL'
        WHEN ST_X(s.location) = 0 AND ST_Y(s.location) = 0 THEN '(0,0) - INVALID'
        ELSE 'VALID'
    END AS location_status,
    ST_X(s.location) AS longitude,
    ST_Y(s.location) AS latitude,
    s.status,
    s.hidden
FROM fieldkit.project_station ps
JOIN fieldkit.project p ON p.id = ps.project_id
JOIN fieldkit.station s ON s.id = ps.station_id
WHERE ps.project_id = 1
ORDER BY ps.station_id;

-- 2. Kiểm tra project privacy
SELECT 
    id,
    name,
    privacy,
    CASE 
        WHEN privacy = 0 THEN 'PUBLIC - location.precise sẽ được trả về'
        ELSE 'PRIVATE - location.precise sẽ KHÔNG được trả về (trừ khi user có quyền)'
    END AS privacy_status
FROM fieldkit.project
WHERE id = 1;

-- 3. Kiểm tra tất cả stations (kể cả không trong project)
SELECT 
    s.id,
    s.name,
    s.location IS NOT NULL AS has_location,
    CASE 
        WHEN s.location IS NULL THEN 'NULL'
        WHEN ST_X(s.location) = 0 AND ST_Y(s.location) = 0 THEN '(0,0) - INVALID'
        WHEN ST_SRID(s.location) != 4326 THEN 'SRID != 4326'
        ELSE 'VALID'
    END AS location_status,
    ST_X(s.location) AS longitude,
    ST_Y(s.location) AS latitude,
    ST_SRID(s.location) AS srid,
    s.status,
    s.hidden,
    CASE 
        WHEN EXISTS (SELECT 1 FROM fieldkit.project_station ps WHERE ps.station_id = s.id AND ps.project_id = 1) 
        THEN 'IN PROJECT'
        ELSE 'NOT IN PROJECT'
    END AS in_project
FROM fieldkit.station s
WHERE s.id BETWEEN 1 AND 10
ORDER BY s.id;

-- 4. Kiểm tra xem stations có location hợp lệ không (theo Location.Valid() logic)
SELECT 
    s.id,
    s.name,
    s.location IS NOT NULL AS has_location,
    ST_X(s.location) AS longitude,
    ST_Y(s.location) AS latitude,
    CASE 
        WHEN s.location IS NULL THEN 'INVALID: NULL'
        WHEN ST_X(s.location) = 0 AND ST_Y(s.location) = 0 THEN 'INVALID: (0,0) - bị filter bởi Location.Valid()'
        WHEN ST_Y(s.location) > 90 OR ST_Y(s.location) < -90 THEN 'INVALID: Latitude ngoài phạm vi'
        WHEN ST_X(s.location) > 180 OR ST_X(s.location) < -180 THEN 'INVALID: Longitude ngoài phạm vi'
        ELSE 'VALID'
    END AS validation_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM fieldkit.project_station ps WHERE ps.station_id = s.id AND ps.project_id = 1) 
        THEN 'IN PROJECT'
        ELSE 'NOT IN PROJECT'
    END AS in_project
FROM fieldkit.station s
WHERE s.id BETWEEN 1 AND 10
ORDER BY s.id;

-- 5. Sửa lỗi: Thêm stations vào project nếu chưa có
-- (Chỉ chạy nếu cần thiết)
INSERT INTO fieldkit.project_station (project_id, station_id)
SELECT 1, id
FROM fieldkit.station
WHERE id BETWEEN 1 AND 10
AND id NOT IN (SELECT station_id FROM fieldkit.project_station WHERE project_id = 1)
ON CONFLICT (project_id, station_id) DO NOTHING;

-- 6. Đảm bảo project privacy = 0
UPDATE fieldkit.project
SET privacy = 0
WHERE id = 1 AND privacy != 0;

-- 7. Kiểm tra lại sau khi sửa
SELECT 
    'Summary' AS check_type,
    COUNT(*) AS total_stations,
    COUNT(CASE WHEN s.location IS NOT NULL AND ST_X(s.location) != 0 AND ST_Y(s.location) != 0 THEN 1 END) AS valid_locations,
    COUNT(CASE WHEN EXISTS (SELECT 1 FROM fieldkit.project_station ps WHERE ps.station_id = s.id AND ps.project_id = 1) THEN 1 END) AS in_project,
    MAX(p.privacy) AS project_privacy
FROM fieldkit.station s
CROSS JOIN fieldkit.project p
WHERE s.id BETWEEN 1 AND 10
AND p.id = 1;

