-- Chỉ tạo views nếu table sensor_data tồn tại và extension timescaledb có sẵn
DO $$
BEGIN
    -- Kiểm tra xem table sensor_data có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'fieldkit' AND tablename = 'sensor_data') THEN
        RAISE NOTICE 'Table fieldkit.sensor_data does not exist, bỏ qua tạo views...';
        RETURN;
    END IF;
    
    -- Kiểm tra xem extension timescaledb có sẵn không
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        RAISE NOTICE 'Extension timescaledb không có sẵn, bỏ qua tạo continuous aggregates...';
        RETURN;
    END IF;
    
    -- Tạo các views nếu cả hai điều kiện đều thỏa mãn
    CREATE MATERIALIZED VIEW IF NOT EXISTS fieldkit.sensor_data_365d
    WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('365 days', "time") AS bucket_time,
        station_id,
        module_id,
        sensor_id,
        COUNT(*) AS bucket_samples,
        MIN(time) AS data_start,
        MAX(time) AS data_end,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        LAST(value, time) AS last_value
    FROM fieldkit.sensor_data
    GROUP BY bucket_time, station_id, module_id, sensor_id
    WITH NO DATA;

    CREATE MATERIALIZED VIEW IF NOT EXISTS fieldkit.sensor_data_7d
    WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('7 days', "time") AS bucket_time,
        station_id,
        module_id,
        sensor_id,
        COUNT(*) AS bucket_samples,
        MIN(time) AS data_start,
        MAX(time) AS data_end,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        LAST(value, time) AS last_value
    FROM fieldkit.sensor_data
    GROUP BY bucket_time, station_id, module_id, sensor_id
    WITH NO DATA;

    CREATE MATERIALIZED VIEW IF NOT EXISTS fieldkit.sensor_data_24h
    WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('1 day', "time") AS bucket_time,
        station_id,
        module_id,
        sensor_id,
        COUNT(*) AS bucket_samples,
        MIN(time) AS data_start,
        MAX(time) AS data_end,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        LAST(value, time) AS last_value
    FROM fieldkit.sensor_data
    GROUP BY bucket_time, station_id, module_id, sensor_id
    WITH NO DATA;

    CREATE MATERIALIZED VIEW IF NOT EXISTS fieldkit.sensor_data_6h
    WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('6 hours', "time") AS bucket_time,
        station_id,
        module_id,
        sensor_id,
        COUNT(*) AS bucket_samples,
        MIN(time) AS data_start,
        MAX(time) AS data_end,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        LAST(value, time) AS last_value
    FROM fieldkit.sensor_data
    GROUP BY bucket_time, station_id, module_id, sensor_id
    WITH NO DATA;

    CREATE MATERIALIZED VIEW IF NOT EXISTS fieldkit.sensor_data_1h
    WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('1 hours', "time") AS bucket_time,
        station_id,
        module_id,
        sensor_id,
        COUNT(*) AS bucket_samples,
        MIN(time) AS data_start,
        MAX(time) AS data_end,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        LAST(value, time) AS last_value
    FROM fieldkit.sensor_data
    GROUP BY bucket_time, station_id, module_id, sensor_id
    WITH NO DATA;

    CREATE MATERIALIZED VIEW IF NOT EXISTS fieldkit.sensor_data_10m
    WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('10 minute', "time") AS bucket_time,
        station_id,
        module_id,
        sensor_id,
        COUNT(*) AS bucket_samples,
        MIN(time) AS data_start,
        MAX(time) AS data_end,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        LAST(value, time) AS last_value
    FROM fieldkit.sensor_data
    GROUP BY bucket_time, station_id, module_id, sensor_id
    WITH NO DATA;
END
$$;
