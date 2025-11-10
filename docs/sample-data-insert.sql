-- ============================================================
-- Sample Data Insert Script
-- Tạo dữ liệu mẫu cho 1 project, 10 stations, mỗi station có 2 modules, mỗi module có 1 sensor
-- ============================================================

-- 1. User (Owner)
-- Giả sử user với id = 1 đã tồn tại, nếu chưa thì uncomment dòng dưới:
-- INSERT INTO fieldkit.user (id, name, username, email, password, valid, bio) 
-- VALUES (1, 'Test Owner', 'testowner', 'test@example.com', '\x00', true, 'Test user');

-- 2. Station Model (giả sử model_id = 1 đã tồn tại, nếu chưa thì uncomment dòng dưới)
-- INSERT INTO fieldkit.station_model (id, name, ttn_schema_id) 
-- VALUES (1, 'FieldKit Station', NULL)
-- ON CONFLICT (id) DO NOTHING;

-- 3. Project (id = 1)
-- Lưu ý: slug đã bị drop, private đã đổi thành privacy
INSERT INTO fieldkit.project (
    id, 
    name, 
    description, 
    goal, 
    location, 
    tags, 
    start_time, 
    end_time, 
    privacy,
    media_url,
    media_content_type,
    bounds,
    show_stations,
    community_ranking
)
VALUES (
    1, 
    'Test Project', 
    'Test project with 10 stations', 
    'Testing', 
    'Test Location', 
    'test', 
    NOW(), 
    NULL, 
    0,  -- privacy: 0 = public
    NULL,  -- media_url
    NULL,  -- media_content_type
    NULL,  -- bounds (JSON)
    true,  -- show_stations
    0  -- community_ranking
)
ON CONFLICT (id) DO NOTHING;

-- 4. Project User (liên kết project với user)
INSERT INTO fieldkit.project_user (project_id, user_id, role)
VALUES (1, 1, 0)
ON CONFLICT (project_id, user_id) DO NOTHING;

-- ============================================================
-- Tạo 10 Stations với đầy đủ relationships
-- ============================================================

DO $$
DECLARE
    station_id_val INTEGER;
    provision_id_val INTEGER;
    config_id_val INTEGER;
    module1_id_val INTEGER;
    module2_id_val INTEGER;
    sensor1_id_val INTEGER;
    sensor2_id_val INTEGER;
    i INTEGER;
    device_id_bytes BYTEA;
    generation_bytes BYTEA;
    hardware_id1_bytes BYTEA;
    hardware_id2_bytes BYTEA;
BEGIN
    FOR i IN 1..10 LOOP
        -- Generate unique device_id and generation
        device_id_bytes := decode(lpad(to_hex(i), 16, '0'), 'hex');
        generation_bytes := decode(lpad(to_hex(i * 100), 16, '0'), 'hex');
        hardware_id1_bytes := decode(lpad(to_hex(i * 1000), 16, '0'), 'hex');
        hardware_id2_bytes := decode(lpad(to_hex(i * 2000), 16, '0'), 'hex');

        -- 5. Provision (cho mỗi station)
        INSERT INTO fieldkit.provision (id, created, updated, generation, device_id)
        VALUES (i, NOW(), NOW(), generation_bytes, device_id_bytes)
        ON CONFLICT (device_id, generation) DO NOTHING
        RETURNING id INTO provision_id_val;
        
        -- Nếu conflict, lấy id hiện có
        IF provision_id_val IS NULL THEN
            SELECT id INTO provision_id_val FROM fieldkit.provision 
            WHERE device_id = device_id_bytes AND generation = generation_bytes;
        END IF;

        -- 6. Station (giả sử model_id = 1 đã tồn tại)
        INSERT INTO fieldkit.station (id, owner_id, device_id, created_at, name, model_id, updated_at, hidden, status, description)
        VALUES (i, 1, device_id_bytes, NOW(), 'Test Station ' || i, 1, NOW(), false, NULL, NULL)
        ON CONFLICT (id) DO NOTHING
        RETURNING id INTO station_id_val;
        
        IF station_id_val IS NULL THEN
            SELECT id INTO station_id_val FROM fieldkit.station WHERE id = i;
        END IF;

        -- 7. Project Station (liên kết station với project)
        INSERT INTO fieldkit.project_station (station_id, project_id)
        VALUES (station_id_val, 1)
        ON CONFLICT (station_id, project_id) DO NOTHING;

        -- 8. Station Configuration
        INSERT INTO fieldkit.station_configuration (id, provision_id, meta_record_id, source_id, updated_at)
        VALUES (i, provision_id_val, NULL, NULL, NOW())
        ON CONFLICT (id) DO NOTHING
        RETURNING id INTO config_id_val;
        
        IF config_id_val IS NULL THEN
            SELECT id INTO config_id_val FROM fieldkit.station_configuration WHERE id = i;
        END IF;

        -- 9. Visible Configuration (liên kết station với configuration)
        INSERT INTO fieldkit.visible_configuration (station_id, configuration_id)
        VALUES (station_id_val, config_id_val)
        ON CONFLICT (station_id) DO UPDATE SET configuration_id = config_id_val;

        -- 10. Station Module 1: fk.water.temp (temperature sensor)
        INSERT INTO fieldkit.station_module (id, hardware_id, flags, manufacturer, kind, version, name, label)
        VALUES (i * 10 + 1, hardware_id1_bytes, 0, 1, 18, 1, 'fk.water.temp', 'Water Temperature')
        ON CONFLICT (id) DO NOTHING
        RETURNING id INTO module1_id_val;
        
        IF module1_id_val IS NULL THEN
            SELECT id INTO module1_id_val FROM fieldkit.station_module WHERE id = i * 10 + 1;
        END IF;

        -- 11. Station Module 2: fk.weather (weather module)
        INSERT INTO fieldkit.station_module (id, hardware_id, flags, manufacturer, kind, version, name, label)
        VALUES (i * 10 + 2, hardware_id2_bytes, 0, 1, 1, 1, 'fk.weather', 'Weather')
        ON CONFLICT (id) DO NOTHING
        RETURNING id INTO module2_id_val;
        
        IF module2_id_val IS NULL THEN
            SELECT id INTO module2_id_val FROM fieldkit.station_module WHERE id = i * 10 + 2;
        END IF;

        -- 12. Configuration Module (liên kết configuration với modules)
        INSERT INTO fieldkit.configuration_module (configuration_id, module_id, position, module_index, label)
        VALUES 
            (config_id_val, module1_id_val, 0, 0, 'Water Temperature'),
            (config_id_val, module2_id_val, 1, 1, 'Weather')
        ON CONFLICT (configuration_id, module_id) DO NOTHING;

        -- 13. Module Sensor 1: temp sensor trong module fk.water.temp
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (i * 10 + 1, module1_id_val, 0, '°C', 'temp', 25.5 + (i * 0.1), NOW())
        ON CONFLICT (module_id, sensor_index) DO NOTHING
        RETURNING id INTO sensor1_id_val;
        
        IF sensor1_id_val IS NULL THEN
            SELECT id INTO sensor1_id_val FROM fieldkit.module_sensor 
            WHERE module_id = module1_id_val AND sensor_index = 0;
        END IF;

        -- 14. Module Sensor 2: humidity sensor trong module fk.weather
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (i * 10 + 2, module2_id_val, 0, '%', 'humidity', 60.0 + (i * 0.5), NOW())
        ON CONFLICT (module_id, sensor_index) DO NOTHING
        RETURNING id INTO sensor2_id_val;
        
        IF sensor2_id_val IS NULL THEN
            SELECT id INTO sensor2_id_val FROM fieldkit.module_sensor 
            WHERE module_id = module2_id_val AND sensor_index = 0;
        END IF;

    END LOOP;
END $$;

-- ============================================================
-- Tạo Aggregated Sensors (nếu chưa tồn tại)
-- ============================================================

-- Sensor 1: fk.water.temp.temp
INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'fk.water.temp.temp', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'fk.water.temp.temp');

-- Sensor 2: fk.weather.humidity
INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'fk.weather.humidity', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'fk.weather.humidity');

-- ============================================================
-- Tạo Module Meta và Sensor Meta (nếu chưa tồn tại)
-- ============================================================

-- Module Meta 1: fk.water.temp
INSERT INTO fieldkit.module_meta (id, key, manufacturer, kinds, version, internal, ordering)
VALUES (1001, 'fk.water.temp', 1, '{18}', '{1}', false, 0)
ON CONFLICT (id) DO NOTHING;

-- Module Meta 2: fk.weather
INSERT INTO fieldkit.module_meta (id, key, manufacturer, kinds, version, internal, ordering)
VALUES (1002, 'fk.weather', 1, '{1}', '{1}', false, 0)
ON CONFLICT (id) DO NOTHING;

-- Sensor Meta 1: fk.water.temp.temp
INSERT INTO fieldkit.sensor_meta (id, module_id, ordering, sensor_key, firmware_key, full_key, internal, uom, strings, viz, ranges, aliases, aggregation_function)
VALUES (
    1001, 
    1001, 
    0, 
    'temp', 
    'temp', 
    'fk.water.temp.temp', 
    false, 
    '°C', 
    '{"en-us":{"label":"Temperature"}}'::json, 
    '[]'::json, 
    '[{"minimum":-126,"maximum":1254}]'::json,
    ARRAY[]::text[],  -- aliases là text[] không phải json
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- Sensor Meta 2: fk.weather.humidity
INSERT INTO fieldkit.sensor_meta (id, module_id, ordering, sensor_key, firmware_key, full_key, internal, uom, strings, viz, ranges, aliases, aggregation_function)
VALUES (
    1002, 
    1002, 
    0, 
    'humidity', 
    'humidity', 
    'fk.weather.humidity', 
    false, 
    '%', 
    '{"en-us":{"label":"Humidity"}}'::json, 
    '[]'::json, 
    '[{"minimum":0,"maximum":100}]'::json,
    ARRAY[]::text[],  -- aliases là text[] không phải json
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Tạo một số Sensor Data mẫu (time-series data)
-- ============================================================

-- Insert sensor data cho station 1 (ví dụ)
-- Lấy sensor_id từ aggregated_sensor
INSERT INTO fieldkit.sensor_data (time, station_id, module_id, sensor_id, value)
SELECT 
    NOW() - (interval '1 hour' * (i - 1)) as time,
    1 as station_id,
    11 as module_id,  -- Module 1 của station 1
    (SELECT id FROM fieldkit.aggregated_sensor WHERE key = 'fk.water.temp.temp' LIMIT 1) as sensor_id,
    25.0 + (random() * 5) as value
FROM generate_series(1, 10) i
WHERE EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'fk.water.temp.temp')
ON CONFLICT (time, station_id, module_id, sensor_id) DO UPDATE SET value = EXCLUDED.value;

INSERT INTO fieldkit.sensor_data (time, station_id, module_id, sensor_id, value)
SELECT 
    NOW() - (interval '1 hour' * (i - 1)) as time,
    1 as station_id,
    12 as module_id,  -- Module 2 của station 1
    (SELECT id FROM fieldkit.aggregated_sensor WHERE key = 'fk.weather.humidity' LIMIT 1) as sensor_id,
    60.0 + (random() * 10) as value
FROM generate_series(1, 10) i
WHERE EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'fk.weather.humidity')
ON CONFLICT (time, station_id, module_id, sensor_id) DO UPDATE SET value = EXCLUDED.value;

-- ============================================================
-- Verification Queries
-- ============================================================

-- Kiểm tra số lượng stations
SELECT COUNT(*) as total_stations FROM fieldkit.station WHERE id BETWEEN 1 AND 10;

-- Kiểm tra số lượng modules
SELECT COUNT(*) as total_modules FROM fieldkit.station_module WHERE id BETWEEN 11 AND 120;

-- Kiểm tra số lượng sensors
SELECT COUNT(*) as total_sensors FROM fieldkit.module_sensor WHERE id BETWEEN 11 AND 120;

-- Kiểm tra mối quan hệ station -> module -> sensor
SELECT 
    s.id as station_id,
    s.name as station_name,
    sm.id as module_id,
    sm.name as module_key,
    ms.id as sensor_id,
    ms.name as sensor_name,
    sm.name || '.' || ms.name as full_sensor_key
FROM fieldkit.station s
LEFT JOIN fieldkit.visible_configuration vc ON (vc.station_id = s.id)
LEFT JOIN fieldkit.station_configuration sc ON (sc.id = vc.configuration_id)
LEFT JOIN fieldkit.configuration_module cm ON (cm.configuration_id = sc.id)
LEFT JOIN fieldkit.station_module sm ON (sm.id = cm.module_id)
LEFT JOIN fieldkit.module_sensor ms ON (ms.module_id = sm.id)
WHERE s.id BETWEEN 1 AND 10
ORDER BY s.id, sm.id;

-- Kiểm tra project stations
SELECT 
    p.id as project_id,
    p.name as project_name,
    COUNT(ps.station_id) as station_count
FROM fieldkit.project p
LEFT JOIN fieldkit.project_station ps ON (ps.project_id = p.id)
WHERE p.id = 1
GROUP BY p.id, p.name;

