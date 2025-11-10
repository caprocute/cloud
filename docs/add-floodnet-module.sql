-- ============================================================
-- Script thêm module wh.floodnet và sensors vào các stations (1-10)
-- Dựa trên pattern của sample-data-insert.sql để tránh conflict
-- ============================================================

DO $$
DECLARE
    i INTEGER;
    station_id_val INTEGER;
    config_id_val INTEGER;
    provision_id_val INTEGER;
    floodnet_module_id_val INTEGER;
    hardware_id_bytes BYTEA;
    device_id_bytes BYTEA;
BEGIN
    FOR i IN 1..10 LOOP
        -- Lấy station_id
        SELECT id INTO station_id_val FROM fieldkit.station WHERE id = i;
        
        IF station_id_val IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Lấy device_id từ station
        SELECT device_id INTO device_id_bytes FROM fieldkit.station WHERE id = i;
        
        IF device_id_bytes IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Lấy provision_id từ station (theo pattern của sample-data-insert.sql)
        -- Provision có id = i trong sample-data-insert.sql
        SELECT id INTO provision_id_val FROM fieldkit.provision WHERE id = i;
        
        -- Nếu không có, tìm theo device_id
        IF provision_id_val IS NULL THEN
            SELECT p.id INTO provision_id_val
            FROM fieldkit.provision p
            JOIN fieldkit.station s ON s.device_id = p.device_id
            WHERE s.id = i
            ORDER BY p.created DESC
            LIMIT 1;
        END IF;
        
        -- Nếu vẫn không có, tạo mới (theo pattern của sample-data-insert.sql)
        IF provision_id_val IS NULL THEN
            INSERT INTO fieldkit.provision (id, created, updated, generation, device_id)
            VALUES (i, NOW(), NOW(), decode(lpad(to_hex(i * 100), 16, '0'), 'hex'), device_id_bytes)
            ON CONFLICT (device_id, generation) DO NOTHING
            RETURNING id INTO provision_id_val;
            
            -- Nếu conflict, lấy id hiện có
            IF provision_id_val IS NULL THEN
                SELECT id INTO provision_id_val FROM fieldkit.provision 
                WHERE device_id = device_id_bytes;
            END IF;
        END IF;
        
        -- Lấy configuration_id (theo pattern của sample-data-insert.sql)
        -- Configuration có id = i trong sample-data-insert.sql
        SELECT id INTO config_id_val FROM fieldkit.station_configuration WHERE id = i;
        
        -- Nếu không có, tìm theo provision_id
        IF config_id_val IS NULL THEN
            SELECT id INTO config_id_val
            FROM fieldkit.station_configuration
            WHERE provision_id = provision_id_val
            ORDER BY updated_at DESC
            LIMIT 1;
        END IF;
        
        -- Nếu vẫn không có, tạo mới (theo pattern của sample-data-insert.sql)
        IF config_id_val IS NULL THEN
            INSERT INTO fieldkit.station_configuration (id, provision_id, meta_record_id, source_id, updated_at)
            VALUES (i, provision_id_val, NULL, NULL, NOW())
            ON CONFLICT (id) DO NOTHING
            RETURNING id INTO config_id_val;
            
            -- Nếu conflict, lấy id hiện có
            IF config_id_val IS NULL THEN
                SELECT id INTO config_id_val FROM fieldkit.station_configuration WHERE id = i;
            END IF;
        END IF;
        
        -- Tạo hardware_id cho floodnet module (theo pattern của sample-data-insert.sql)
        -- Module 1: i * 1000, Module 2: i * 2000, Module 3 (floodnet): i * 3000
        hardware_id_bytes := decode(lpad(to_hex(i * 3000), 16, '0'), 'hex');
        
        -- 1. Tạo Station Module: wh.floodnet
        -- ID pattern: Module 1 = i * 10 + 1, Module 2 = i * 10 + 2, Module 3 = i * 10 + 3
        INSERT INTO fieldkit.station_module (id, hardware_id, flags, manufacturer, kind, version, name, label)
        VALUES (i * 10 + 3, hardware_id_bytes, 0, 0, 0, 1, 'wh.floodnet', 'FloodNet')
        ON CONFLICT (id) DO NOTHING
        RETURNING id INTO floodnet_module_id_val;
        
        -- Nếu conflict, lấy id hiện có
        IF floodnet_module_id_val IS NULL THEN
            SELECT id INTO floodnet_module_id_val FROM fieldkit.station_module WHERE id = i * 10 + 3;
        END IF;
        
        -- 2. Thêm vào Configuration Module
        -- Position: Module 1 = 0, Module 2 = 1, Module 3 = 2
        INSERT INTO fieldkit.configuration_module (configuration_id, module_id, position, module_index, label)
        VALUES (config_id_val, floodnet_module_id_val, 2, 2, 'FloodNet')
        ON CONFLICT (configuration_id, module_id) DO NOTHING;
        
        -- 3. Thêm các Module Sensors cho wh.floodnet
        -- ID pattern: Sensor của Module 1 = i * 10 + 1, Module 2 = i * 10 + 2
        -- Sensor của Module 3 (floodnet): i * 1000 + 30 đến i * 1000 + 39
        -- Sensor 0: depth
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 30,
            floodnet_module_id_val,
            0,
            'inches',
            'depth',
            8.5 + (random() * 2),  -- Giá trị mẫu: 8.5-10.5 inches
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 1: depthUnfiltered
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 31,
            floodnet_module_id_val,
            1,
            'inches',
            'depthUnfiltered',
            8.3 + (random() * 2.4),  -- Giá trị mẫu: 8.3-10.7 inches
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 2: distance
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 32,
            floodnet_module_id_val,
            2,
            'mm',
            'distance',
            2000 + (random() * 1000),  -- Giá trị mẫu: 2000-3000 mm
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 3: battery
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 33,
            floodnet_module_id_val,
            3,
            '%',
            'battery',
            75 + (random() * 20),  -- Giá trị mẫu: 75-95%
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 4: tideFeet
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 34,
            floodnet_module_id_val,
            4,
            'inches',
            'tideFeet',
            9.0 + (random() * 1.5),  -- Giá trị mẫu: 9.0-10.5 inches
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 5: humidity
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 35,
            floodnet_module_id_val,
            5,
            '%',
            'humidity',
            60 + (random() * 30),  -- Giá trị mẫu: 60-90%
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 6: pressure
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 36,
            floodnet_module_id_val,
            6,
            'kPa',
            'pressure',
            101.3 + (random() * 2),  -- Giá trị mẫu: 101.3-103.3 kPa
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 7: altitude
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 37,
            floodnet_module_id_val,
            7,
            'm',
            'altitude',
            10 + (random() * 50),  -- Giá trị mẫu: 10-60 m
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 8: temperature
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 38,
            floodnet_module_id_val,
            8,
            '°C',
            'temperature',
            25 + (random() * 10),  -- Giá trị mẫu: 25-35°C
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
        -- Sensor 9: sdError
        INSERT INTO fieldkit.module_sensor (id, module_id, sensor_index, unit_of_measure, name, reading_last, reading_time)
        VALUES (
            i * 1000 + 39,
            floodnet_module_id_val,
            9,
            '',
            'sdError',
            0 + (random() * 5),  -- Giá trị mẫu: 0-5
            NOW() - INTERVAL '1 hour' * (10 - i)
        )
        ON CONFLICT (module_id, sensor_index) DO UPDATE SET
            reading_last = COALESCE(EXCLUDED.reading_last, module_sensor.reading_last),
            reading_time = COALESCE(EXCLUDED.reading_time, module_sensor.reading_time);
        
    END LOOP;
END $$;

-- ============================================================
-- Đảm bảo aggregated_sensor có các keys (nếu chưa có)
-- ============================================================

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.depth', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.depth');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.depthUnfiltered', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.depthUnfiltered');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.distance', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.distance');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.battery', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.battery');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.tideFeet', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.tideFeet');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.humidity', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.humidity');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.pressure', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.pressure');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.altitude', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.altitude');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.temperature', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.temperature');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.sdError', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.sdError');

INSERT INTO fieldkit.aggregated_sensor (key, interestingness_priority)
SELECT 'wh.floodnet.maxPrecipLast5MinMmPerMin', NULL
WHERE NOT EXISTS (SELECT 1 FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.maxPrecipLast5MinMmPerMin');

-- ============================================================
-- Thêm một số sensor_data mẫu cho sensor depth (sensor chính)
-- ============================================================

DO $$
DECLARE
    i INTEGER;
    module_id_val INTEGER;
    sensor_id_val INTEGER;
BEGIN
    FOR i IN 1..10 LOOP
        -- Lấy module_id (i * 10 + 3)
        SELECT id INTO module_id_val FROM fieldkit.station_module WHERE id = i * 10 + 3;
        
        IF module_id_val IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Lấy sensor_id từ aggregated_sensor
        SELECT id INTO sensor_id_val FROM fieldkit.aggregated_sensor WHERE key = 'wh.floodnet.depth' LIMIT 1;
        
        IF sensor_id_val IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Thêm 5 records sensor_data mẫu
        INSERT INTO fieldkit.sensor_data (time, station_id, module_id, sensor_id, value)
        SELECT
            NOW() - (INTERVAL '1 hour' * (i - 1 + j)) as time,
            i as station_id,
            module_id_val as module_id,
            sensor_id_val as sensor_id,
            8.0 + (random() * 3) as value  -- Giá trị mẫu: 8.0-11.0 inches
        FROM generate_series(1, 5) j
        ON CONFLICT (time, station_id, module_id, sensor_id) DO UPDATE SET value = EXCLUDED.value;
        
    END LOOP;
END $$;

-- ============================================================
-- Verification Queries
-- ============================================================

-- Kiểm tra floodnet modules đã được thêm
SELECT 
    s.id AS station_id,
    s.name AS station_name,
    sm.id AS module_id,
    sm.name AS module_name,
    sm.label AS module_label,
    COUNT(ms.id) AS sensor_count
FROM fieldkit.station s
JOIN fieldkit.visible_configuration vc ON vc.station_id = s.id
JOIN fieldkit.station_configuration sc ON sc.id = vc.configuration_id
JOIN fieldkit.configuration_module cm ON cm.configuration_id = sc.id
JOIN fieldkit.station_module sm ON sm.id = cm.module_id
LEFT JOIN fieldkit.module_sensor ms ON ms.module_id = sm.id
WHERE s.id BETWEEN 1 AND 10
AND sm.name = 'wh.floodnet'
GROUP BY s.id, s.name, sm.id, sm.name, sm.label
ORDER BY s.id;

-- Kiểm tra sensors của floodnet module
SELECT 
    s.id AS station_id,
    sm.name AS module_name,
    ms.sensor_index,
    ms.name AS sensor_name,
    ms.unit_of_measure,
    ms.reading_last,
    ms.reading_time
FROM fieldkit.station s
JOIN fieldkit.visible_configuration vc ON vc.station_id = s.id
JOIN fieldkit.station_configuration sc ON sc.id = vc.configuration_id
JOIN fieldkit.configuration_module cm ON cm.configuration_id = sc.id
JOIN fieldkit.station_module sm ON sm.id = cm.module_id
JOIN fieldkit.module_sensor ms ON ms.module_id = sm.id
WHERE s.id BETWEEN 1 AND 10
AND sm.name = 'wh.floodnet'
ORDER BY s.id, ms.sensor_index
LIMIT 50;

-- Kiểm tra sensor_data của floodnet
SELECT 
    sd.station_id,
    s.name AS station_name,
    sm.name AS module_name,
    agg.key AS sensor_key,
    COUNT(*) AS data_count,
    MIN(sd.time) AS earliest_time,
    MAX(sd.time) AS latest_time
FROM fieldkit.sensor_data sd
JOIN fieldkit.station s ON s.id = sd.station_id
JOIN fieldkit.station_module sm ON sm.id = sd.module_id
JOIN fieldkit.aggregated_sensor agg ON agg.id = sd.sensor_id
WHERE sd.station_id BETWEEN 1 AND 10
AND sm.name = 'wh.floodnet'
GROUP BY sd.station_id, s.name, sm.name, agg.key
ORDER BY sd.station_id, agg.key;
