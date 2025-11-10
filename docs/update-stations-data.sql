-- ============================================================
-- Update Stations Data Script
-- Cập nhật đầy đủ thông tin cho 10 stations với địa điểm ở Việt Nam
-- ============================================================

-- Cập nhật thông tin đầy đủ cho 10 stations
UPDATE fieldkit.station SET
    -- Thông tin cơ bản
    name = CASE id
        WHEN 1 THEN 'Hà Nội - Trạm Giám Sát 1'
        WHEN 2 THEN 'Hồ Chí Minh - Trạm Giám Sát 2'
        WHEN 3 THEN 'Đà Nẵng - Trạm Giám Sát 3'
        WHEN 4 THEN 'Hải Phòng - Trạm Giám Sát 4'
        WHEN 5 THEN 'Cần Thơ - Trạm Giám Sát 5'
        WHEN 6 THEN 'Nha Trang - Trạm Giám Sát 6'
        WHEN 7 THEN 'Huế - Trạm Giám Sát 7'
        WHEN 8 THEN 'Vũng Tàu - Trạm Giám Sát 8'
        WHEN 9 THEN 'Đà Lạt - Trạm Giám Sát 9'
        WHEN 10 THEN 'Quy Nhon - Trạm Giám Sát 10'
    END,
    
    -- Mô tả
    description = CASE id
        WHEN 1 THEN 'Trạm giám sát môi trường tại Hà Nội - Khu vực trung tâm thành phố'
        WHEN 2 THEN 'Trạm giám sát môi trường tại TP. Hồ Chí Minh - Khu vực quận 1'
        WHEN 3 THEN 'Trạm giám sát môi trường tại Đà Nẵng - Khu vực ven biển'
        WHEN 4 THEN 'Trạm giám sát môi trường tại Hải Phòng - Khu vực cảng biển'
        WHEN 5 THEN 'Trạm giám sát môi trường tại Cần Thơ - Khu vực đồng bằng sông Cửu Long'
        WHEN 6 THEN 'Trạm giám sát môi trường tại Nha Trang - Khu vực du lịch biển'
        WHEN 7 THEN 'Trạm giám sát môi trường tại Huế - Khu vực di sản văn hóa'
        WHEN 8 THEN 'Trạm giám sát môi trường tại Vũng Tàu - Khu vực dầu khí'
        WHEN 9 THEN 'Trạm giám sát môi trường tại Đà Lạt - Khu vực cao nguyên'
        WHEN 10 THEN 'Trạm giám sát môi trường tại Quy Nhơn - Khu vực ven biển miền Trung'
    END,
    
    -- Vị trí địa lý (tọa độ Việt Nam)
    -- Lưu ý: ST_MakePoint(longitude, latitude) - thứ tự đúng
    -- SRID 4326 = WGS84 (World Geodetic System 1984)
    location = CASE id
        WHEN 1 THEN ST_SetSRID(ST_MakePoint(105.8342, 21.0285), 4326)::geometry  -- Hà Nội
        WHEN 2 THEN ST_SetSRID(ST_MakePoint(106.6297, 10.8231), 4326)::geometry  -- TP. Hồ Chí Minh
        WHEN 3 THEN ST_SetSRID(ST_MakePoint(108.2208, 16.0544), 4326)::geometry  -- Đà Nẵng
        WHEN 4 THEN ST_SetSRID(ST_MakePoint(106.6881, 20.8449), 4326)::geometry  -- Hải Phòng
        WHEN 5 THEN ST_SetSRID(ST_MakePoint(105.7871, 10.0452), 4326)::geometry  -- Cần Thơ
        WHEN 6 THEN ST_SetSRID(ST_MakePoint(109.1967, 12.2388), 4326)::geometry  -- Nha Trang
        WHEN 7 THEN ST_SetSRID(ST_MakePoint(107.5909, 16.4637), 4326)::geometry  -- Huế
        WHEN 8 THEN ST_SetSRID(ST_MakePoint(107.2426, 10.3460), 4326)::geometry  -- Vũng Tàu
        WHEN 9 THEN ST_SetSRID(ST_MakePoint(108.4419, 11.9404), 4326)::geometry  -- Đà Lạt
        WHEN 10 THEN ST_SetSRID(ST_MakePoint(109.2197, 13.7696), 4326)::geometry  -- Quy Nhơn
    END,
    
    -- Tên địa điểm
    location_name = CASE id
        WHEN 1 THEN 'Hà Nội, Việt Nam'
        WHEN 2 THEN 'Thành phố Hồ Chí Minh, Việt Nam'
        WHEN 3 THEN 'Đà Nẵng, Việt Nam'
        WHEN 4 THEN 'Hải Phòng, Việt Nam'
        WHEN 5 THEN 'Cần Thơ, Việt Nam'
        WHEN 6 THEN 'Nha Trang, Khánh Hòa, Việt Nam'
        WHEN 7 THEN 'Huế, Thừa Thiên Huế, Việt Nam'
        WHEN 8 THEN 'Vũng Tàu, Bà Rịa - Vũng Tàu, Việt Nam'
        WHEN 9 THEN 'Đà Lạt, Lâm Đồng, Việt Nam'
        WHEN 10 THEN 'Quy Nhơn, Bình Định, Việt Nam'
    END,
    
    -- Địa danh
    place_other = CASE id
        WHEN 1 THEN 'Hà Nội'
        WHEN 2 THEN 'Sài Gòn'
        WHEN 3 THEN 'Đà Nẵng'
        WHEN 4 THEN 'Hải Phòng'
        WHEN 5 THEN 'Cần Thơ'
        WHEN 6 THEN 'Nha Trang'
        WHEN 7 THEN 'Huế'
        WHEN 8 THEN 'Vũng Tàu'
        WHEN 9 THEN 'Đà Lạt'
        WHEN 10 THEN 'Quy Nhơn'
    END,
    
    place_native = CASE id
        WHEN 1 THEN 'Hà Nội'
        WHEN 2 THEN 'Thành phố Hồ Chí Minh'
        WHEN 3 THEN 'Đà Nẵng'
        WHEN 4 THEN 'Hải Phòng'
        WHEN 5 THEN 'Cần Thơ'
        WHEN 6 THEN 'Nha Trang'
        WHEN 7 THEN 'Huế'
        WHEN 8 THEN 'Vũng Tàu'
        WHEN 9 THEN 'Đà Lạt'
        WHEN 10 THEN 'Quy Nhơn'
    END,
    
    -- Thông tin pin
    battery = CASE id
        WHEN 1 THEN 85.5
        WHEN 2 THEN 92.3
        WHEN 3 THEN 78.9
        WHEN 4 THEN 88.2
        WHEN 5 THEN 75.6
        WHEN 6 THEN 90.1
        WHEN 7 THEN 82.4
        WHEN 8 THEN 86.7
        WHEN 9 THEN 79.3
        WHEN 10 THEN 91.8
    END,
    
    -- Thời gian bắt đầu ghi
    recording_started_at = CASE id
        WHEN 1 THEN NOW() - INTERVAL '30 days'
        WHEN 2 THEN NOW() - INTERVAL '25 days'
        WHEN 3 THEN NOW() - INTERVAL '20 days'
        WHEN 4 THEN NOW() - INTERVAL '28 days'
        WHEN 5 THEN NOW() - INTERVAL '22 days'
        WHEN 6 THEN NOW() - INTERVAL '18 days'
        WHEN 7 THEN NOW() - INTERVAL '15 days'
        WHEN 8 THEN NOW() - INTERVAL '12 days'
        WHEN 9 THEN NOW() - INTERVAL '10 days'
        WHEN 10 THEN NOW() - INTERVAL '8 days'
    END,
    
    -- Thông tin bộ nhớ
    memory_used = CASE id
        WHEN 1 THEN 1024000  -- 1GB
        WHEN 2 THEN 2048000  -- 2GB
        WHEN 3 THEN 1536000  -- 1.5GB
        WHEN 4 THEN 1280000  -- 1.25GB
        WHEN 5 THEN 1024000  -- 1GB
        WHEN 6 THEN 1792000  -- 1.75GB
        WHEN 7 THEN 1152000  -- 1.125GB
        WHEN 8 THEN 2048000  -- 2GB
        WHEN 9 THEN 1024000  -- 1GB
        WHEN 10 THEN 1920000  -- 1.875GB
    END,
    
    memory_available = CASE id
        WHEN 1 THEN 2048000  -- 2GB
        WHEN 2 THEN 4096000  -- 4GB
        WHEN 3 THEN 3072000  -- 3GB
        WHEN 4 THEN 2560000  -- 2.5GB
        WHEN 5 THEN 2048000  -- 2GB
        WHEN 6 THEN 3584000  -- 3.5GB
        WHEN 7 THEN 2304000  -- 2.25GB
        WHEN 8 THEN 4096000  -- 4GB
        WHEN 9 THEN 2048000  -- 2GB
        WHEN 10 THEN 3840000  -- 3.75GB
    END,
    
    -- Thông tin firmware
    firmware_number = CASE id
        WHEN 1 THEN 20240101
        WHEN 2 THEN 20240115
        WHEN 3 THEN 20240201
        WHEN 4 THEN 20240120
        WHEN 5 THEN 20240210
        WHEN 6 THEN 20240220
        WHEN 7 THEN 20240301
        WHEN 8 THEN 20240310
        WHEN 9 THEN 20240320
        WHEN 10 THEN 20240401
    END,
    
    firmware_time = CASE id
        WHEN 1 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '30 days'))::bigint
        WHEN 2 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '25 days'))::bigint
        WHEN 3 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '20 days'))::bigint
        WHEN 4 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '28 days'))::bigint
        WHEN 5 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '22 days'))::bigint
        WHEN 6 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '18 days'))::bigint
        WHEN 7 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '15 days'))::bigint
        WHEN 8 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '12 days'))::bigint
        WHEN 9 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '10 days'))::bigint
        WHEN 10 THEN EXTRACT(EPOCH FROM (NOW() - INTERVAL '8 days'))::bigint
    END,
    
    -- Trạng thái (up = online, down = offline)
    status = CASE id
        WHEN 1 THEN 'up'
        WHEN 2 THEN 'up'
        WHEN 3 THEN 'up'
        WHEN 4 THEN 'up'
        WHEN 5 THEN 'up'
        WHEN 6 THEN 'up'
        WHEN 7 THEN 'up'
        WHEN 8 THEN 'up'
        WHEN 9 THEN 'up'
        WHEN 10 THEN 'up'
    END,
    
    -- Ẩn/hiện
    hidden = false,
    
    -- Thời gian đồng bộ
    synced_at = CASE id
        WHEN 1 THEN NOW() - INTERVAL '1 hour'
        WHEN 2 THEN NOW() - INTERVAL '30 minutes'
        WHEN 3 THEN NOW() - INTERVAL '2 hours'
        WHEN 4 THEN NOW() - INTERVAL '45 minutes'
        WHEN 5 THEN NOW() - INTERVAL '1.5 hours'
        WHEN 6 THEN NOW() - INTERVAL '20 minutes'
        WHEN 7 THEN NOW() - INTERVAL '3 hours'
        WHEN 8 THEN NOW() - INTERVAL '15 minutes'
        WHEN 9 THEN NOW() - INTERVAL '2.5 hours'
        WHEN 10 THEN NOW() - INTERVAL '10 minutes'
    END,
    
    -- Thời gian ingestion
    ingestion_at = CASE id
        WHEN 1 THEN NOW() - INTERVAL '2 hours'
        WHEN 2 THEN NOW() - INTERVAL '1 hour'
        WHEN 3 THEN NOW() - INTERVAL '3 hours'
        WHEN 4 THEN NOW() - INTERVAL '1.5 hours'
        WHEN 5 THEN NOW() - INTERVAL '2.5 hours'
        WHEN 6 THEN NOW() - INTERVAL '30 minutes'
        WHEN 7 THEN NOW() - INTERVAL '4 hours'
        WHEN 8 THEN NOW() - INTERVAL '20 minutes'
        WHEN 9 THEN NOW() - INTERVAL '3.5 hours'
        WHEN 10 THEN NOW() - INTERVAL '15 minutes'
    END,
    
    -- Cập nhật thời gian
    updated_at = NOW()
    
WHERE id BETWEEN 1 AND 10;

-- ============================================================
-- Cập nhật module_sensor.reading_time để có lastReadingAt
-- ============================================================

-- Cập nhật reading_time cho các sensors của stations để có lastReadingAt
UPDATE fieldkit.module_sensor
SET reading_time = NOW() - INTERVAL '1 hour' * (10 - (module_id % 10))
WHERE module_id IN (
    SELECT sm.id
    FROM fieldkit.station_module sm
    JOIN fieldkit.configuration_module cm ON cm.module_id = sm.id
    JOIN fieldkit.station_configuration sc ON sc.id = cm.configuration_id
    JOIN fieldkit.visible_configuration vc ON vc.configuration_id = sc.id
    WHERE vc.station_id BETWEEN 1 AND 10
)
AND reading_time IS NULL;

-- ============================================================
-- Đảm bảo stations có trong project_station table
-- ============================================================

-- Thêm stations vào project nếu chưa có
INSERT INTO fieldkit.project_station (project_id, station_id)
SELECT 1, id
FROM fieldkit.station
WHERE id BETWEEN 1 AND 10
AND id NOT IN (SELECT station_id FROM fieldkit.project_station WHERE project_id = 1)
ON CONFLICT (project_id, station_id) DO NOTHING;

-- ============================================================
-- Đảm bảo project có privacy = 0 (public) để location.precise được trả về
-- ============================================================

-- Cập nhật project privacy = 0 (public) để location.precise được trả về
UPDATE fieldkit.project
SET privacy = 0  -- 0 = public
WHERE id = 1;

-- ============================================================
-- Verification Queries
-- ============================================================

-- Kiểm tra thông tin stations đã được cập nhật
SELECT 
    id,
    name,
    location_name,
    ST_Y(location) AS latitude,
    ST_X(location) AS longitude,
    battery,
    status,
    recording_started_at,
    memory_used,
    memory_available,
    firmware_number,
    synced_at
FROM fieldkit.station
WHERE id BETWEEN 1 AND 10
ORDER BY id;

-- Kiểm tra tọa độ địa lý và format
SELECT 
    id,
    name,
    location_name,
    ST_AsText(location) AS coordinates,
    ST_GeometryType(location) AS geometry_type,
    ST_SRID(location) AS srid,
    ST_X(location) AS longitude,
    ST_Y(location) AS latitude,
    CASE 
        WHEN location IS NULL THEN 'ERROR: NULL'
        WHEN ST_X(location) = 0 AND ST_Y(location) = 0 THEN 'ERROR: (0,0)'
        WHEN ST_SRID(location) != 4326 THEN 'ERROR: SRID != 4326'
        WHEN ST_GeometryType(location) != 'ST_Point' THEN 'ERROR: Not POINT'
        ELSE 'OK'
    END AS validation_status,
    place_other,
    place_native
FROM fieldkit.station
WHERE id BETWEEN 1 AND 10
ORDER BY id;

-- Kiểm tra stations có trong project không
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

-- Kiểm tra project privacy
SELECT id, name, privacy FROM fieldkit.project WHERE id = 1;

-- Kiểm tra module_sensor.reading_time
SELECT 
    ms.id,
    ms.module_id,
    ms.name,
    ms.reading_time,
    sm.name AS module_name,
    vc.station_id
FROM fieldkit.module_sensor ms
JOIN fieldkit.station_module sm ON sm.id = ms.module_id
JOIN fieldkit.configuration_module cm ON cm.module_id = sm.id
JOIN fieldkit.visible_configuration vc ON vc.configuration_id = cm.configuration_id
WHERE vc.station_id BETWEEN 1 AND 10
ORDER BY vc.station_id, ms.module_id, ms.sensor_index
LIMIT 20;

