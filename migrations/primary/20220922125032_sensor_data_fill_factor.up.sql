-- Chỉ alter table nếu nó tồn tại
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'fieldkit' AND tablename = 'sensor_data') THEN
        ALTER TABLE fieldkit.sensor_data SET (fillfactor = 90);
    END IF;
END
$$;
