-- Chỉ tạo index nếu table tồn tại
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'fieldkit' AND tablename = 'sensor_data') THEN
        CREATE INDEX IF NOT EXISTS sensor_data_module_id_idx ON fieldkit.sensor_data (module_id);
    END IF;
END
$$;
