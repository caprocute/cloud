-- Chỉ tạo index nếu table tồn tại
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'fieldkit' AND tablename = 'sensor_data') THEN
        CREATE UNIQUE INDEX IF NOT EXISTS sensor_index_idx ON fieldkit.sensor_data (time, station_id, module_id, sensor_id);
    END IF;
END
$$;