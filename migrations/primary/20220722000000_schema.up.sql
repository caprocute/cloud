CREATE SCHEMA IF NOT EXISTS fieldkit;

-- Tạo bảng sensor_data (luôn tạo, không phụ thuộc vào timescaledb)
CREATE TABLE IF NOT EXISTS fieldkit.sensor_data (
    time TIMESTAMPTZ NOT NULL,
    station_id INTEGER NOT NULL /* REFERENCES fieldkit.station (id) */,
    module_id INTEGER NOT NULL /* REFERENCES fieldkit.station_module (id) */,
    sensor_id INTEGER NOT NULL /* REFERENCES fieldkit.aggregated_sensor (id) */,
    value FLOAT NOT NULL
);

-- Thử tạo extension và hypertable nếu có thể (chỉ trong TimescaleDB)
DO $$
BEGIN
    -- Thử tạo extension timescaledb
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        CREATE EXTENSION timescaledb;
    END IF;
    
    -- Nếu extension tồn tại, tạo hypertable
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        -- Kiểm tra xem hypertable đã tồn tại chưa
        IF NOT EXISTS (SELECT 1 FROM _timescaledb_catalog.hypertable WHERE hypertable_name = 'sensor_data' AND hypertable_schema = 'fieldkit') THEN
            PERFORM create_hypertable('fieldkit.sensor_data', 'time');
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Extension không có sẵn trong PostgreSQL chính, chỉ có trong TimescaleDB container
        -- Bỏ qua, table vẫn được tạo như bình thường
        NULL;
END
$$;

CREATE INDEX IF NOT EXISTS sensor_data_idx ON fieldkit.sensor_data (station_id, module_id, sensor_id, time DESC);

/*
INSERT INTO fieldkit.sensor_data SELECT time, station_id, module_id, sensor_id, value FROM fieldkit.aggregated_10s;
*/
