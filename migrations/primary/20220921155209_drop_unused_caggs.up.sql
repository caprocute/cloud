-- Chỉ drop views nếu chúng tồn tại và extension có sẵn
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        DROP MATERIALIZED VIEW IF EXISTS fieldkit.sensor_data_365d;
        DROP MATERIALIZED VIEW IF EXISTS fieldkit.sensor_data_7d;
    END IF;
END
$$;