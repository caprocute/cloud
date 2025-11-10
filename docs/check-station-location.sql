-- ============================================================
-- Script kiểm tra và sửa lỗi location của stations
-- ============================================================

-- 1. Kiểm tra location của các stations
SELECT 
    id,
    name,
    location IS NULL AS location_is_null,
    CASE 
        WHEN location IS NULL THEN 'NULL'
        WHEN ST_X(location) = 0 AND ST_Y(location) = 0 THEN 'ZERO (0,0) - INVALID'
        ELSE 'VALID'
    END AS location_status,
    ST_X(location) AS longitude,
    ST_Y(location) AS latitude,
    ST_AsText(location) AS location_wkt,
    ST_SRID(location) AS srid
FROM fieldkit.station
WHERE id BETWEEN 1 AND 10
ORDER BY id;

-- 2. Kiểm tra project privacy
SELECT 
    id,
    name,
    privacy,
    CASE 
        WHEN privacy = 0 THEN 'PUBLIC - location.precise sẽ được trả về'
        ELSE 'PRIVATE - location.precise sẽ KHÔNG được trả về'
    END AS privacy_status
FROM fieldkit.project
WHERE id = 1;

-- 3. Kiểm tra stations có trong project không
SELECT 
    ps.project_id,
    p.name AS project_name,
    p.privacy,
    ps.station_id,
    s.name AS station_name,
    s.location IS NOT NULL AS has_location,
    ST_X(s.location) AS longitude,
    ST_Y(s.location) AS latitude
FROM fieldkit.project_station ps
JOIN fieldkit.project p ON p.id = ps.project_id
JOIN fieldkit.station s ON s.id = ps.station_id
WHERE ps.project_id = 1
ORDER BY ps.station_id;

-- 4. Kiểm tra location format (phải là POINT với SRID 4326)
SELECT 
    id,
    name,
    ST_GeometryType(location) AS geometry_type,
    ST_SRID(location) AS srid,
    ST_X(location) AS longitude,
    ST_Y(location) AS latitude,
    CASE 
        WHEN ST_SRID(location) != 4326 THEN 'ERROR: SRID phải là 4326'
        WHEN ST_GeometryType(location) != 'ST_Point' THEN 'ERROR: Phải là POINT'
        WHEN ST_X(location) = 0 AND ST_Y(location) = 0 THEN 'ERROR: Không được là (0,0)'
        WHEN ST_X(location) < -180 OR ST_X(location) > 180 THEN 'ERROR: Longitude ngoài phạm vi'
        WHEN ST_Y(location) < -90 OR ST_Y(location) > 90 THEN 'ERROR: Latitude ngoài phạm vi'
        ELSE 'OK'
    END AS validation_status
FROM fieldkit.station
WHERE id BETWEEN 1 AND 10
ORDER BY id;

-- 5. Sửa lỗi nếu location là NULL hoặc (0,0)
-- (Chỉ chạy nếu cần thiết)
/*
UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(105.8342, 21.0285), 4326)  -- Hà Nội
WHERE id = 1 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(106.6297, 10.8231), 4326)  -- TP. Hồ Chí Minh
WHERE id = 2 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(108.2208, 16.0544), 4326)  -- Đà Nẵng
WHERE id = 3 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(106.6881, 20.8449), 4326)  -- Hải Phòng
WHERE id = 4 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(105.7871, 10.0452), 4326)  -- Cần Thơ
WHERE id = 5 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(109.1967, 12.2388), 4326)  -- Nha Trang
WHERE id = 6 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(107.5909, 16.4637), 4326)  -- Huế
WHERE id = 7 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(107.2426, 10.3460), 4326)  -- Vũng Tàu
WHERE id = 8 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(108.4419, 11.9404), 4326)  -- Đà Lạt
WHERE id = 9 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));

UPDATE fieldkit.station
SET location = ST_SetSRID(ST_MakePoint(109.2197, 13.7696), 4326)  -- Quy Nhơn
WHERE id = 10 AND (location IS NULL OR (ST_X(location) = 0 AND ST_Y(location) = 0));
*/

-- 6. Đảm bảo project privacy = 0
UPDATE fieldkit.project
SET privacy = 0
WHERE id = 1 AND privacy != 0;

-- 7. Kiểm tra lại sau khi sửa
SELECT 
    'Project Privacy' AS check_type,
    id,
    name,
    privacy,
    CASE WHEN privacy = 0 THEN 'OK' ELSE 'ERROR' END AS status
FROM fieldkit.project
WHERE id = 1

UNION ALL

SELECT 
    'Station Location' AS check_type,
    id,
    name,
    NULL::int AS privacy,
    CASE 
        WHEN location IS NULL THEN 'ERROR: NULL'
        WHEN ST_X(location) = 0 AND ST_Y(location) = 0 THEN 'ERROR: (0,0)'
        WHEN ST_SRID(location) != 4326 THEN 'ERROR: SRID != 4326'
        ELSE 'OK'
    END AS status
FROM fieldkit.station
WHERE id BETWEEN 1 AND 10
ORDER BY check_type, id;

