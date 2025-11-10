# Mối quan hệ giữa Station và Sensor trong Database

## Tổng quan

Hệ thống FieldKit sử dụng kiến trúc phân cấp để kết nối Station với Sensor thông qua các bảng trung gian. Mối quan hệ này cho phép một station có nhiều configuration, mỗi configuration có nhiều module, và mỗi module có nhiều sensor.

## Sơ đồ mối quan hệ

```
station
  └─> visible_configuration (1:1)
        └─> station_configuration (1:1)
              └─> configuration_module (1:N)
                    └─> station_module (1:1)
                          └─> module_sensor (1:N)
                                └─> aggregated_sensor (qua full_key)
                                      └─> sensor_meta (qua full_key)
                                            └─> module_meta (qua module_id)
```

## Các bảng và mối quan hệ chi tiết

### 1. **fieldkit.station**
Bảng chính chứa thông tin station.

**Các trường chính:**
- `id` (PRIMARY KEY) - ID của station
- `owner_id` - ID của user sở hữu
- `device_id` - Device ID của station
- `name` - Tên station
- `created_at` - Thời gian tạo

**Mối quan hệ:**
- 1 station có 1 visible_configuration (qua `visible_configuration.station_id`)

---

### 2. **fieldkit.visible_configuration**
Bảng liên kết station với configuration đang được hiển thị.

**Các trường:**
- `station_id` (PRIMARY KEY, FOREIGN KEY → `station.id`)
- `configuration_id` (FOREIGN KEY → `station_configuration.id`)

**Mối quan hệ:**
- 1 station có 1 visible_configuration
- 1 visible_configuration thuộc về 1 station_configuration

---

### 3. **fieldkit.station_configuration**
Bảng chứa cấu hình của station (có thể có nhiều version).

**Các trường:**
- `id` (PRIMARY KEY)
- `provision_id` (FOREIGN KEY → `provision.id`)
- `meta_record_id` (FOREIGN KEY → `meta_record.id`)
- `source_id`
- `updated_at`

**Mối quan hệ:**
- 1 station_configuration có nhiều configuration_module (qua `configuration_module.configuration_id`)

---

### 4. **fieldkit.configuration_module**
Bảng liên kết configuration với module (many-to-many).

**Các trường:**
- `configuration_id` (FOREIGN KEY → `station_configuration.id`)
- `module_id` (FOREIGN KEY → `station_module.id`)
- `position` - Vị trí module trong configuration
- `module_index` - Index của module
- `label` - Nhãn hiển thị

**Mối quan hệ:**
- 1 configuration có nhiều configuration_module
- 1 configuration_module thuộc về 1 station_module

---

### 5. **fieldkit.station_module**
Bảng chứa thông tin module vật lý trên station.

**Các trường:**
- `id` (PRIMARY KEY)
- `hardware_id` (BYTEA) - Hardware ID của module
- `manufacturer` - Nhà sản xuất
- `kind` - Loại module
- `version` - Phiên bản
- `name` (VARCHAR) - Tên module (ví dụ: `fk.water.ph`, `fk.weather`)

**Mối quan hệ:**
- 1 station_module có nhiều module_sensor (qua `module_sensor.module_id`)
- 1 station_module có thể thuộc nhiều configuration_module

---

### 6. **fieldkit.module_sensor**
Bảng chứa thông tin sensor trong module.

**Các trường:**
- `id` (PRIMARY KEY)
- `module_id` (FOREIGN KEY → `station_module.id`)
- `sensor_index` - Index của sensor trong module
- `name` (VARCHAR) - Tên sensor (ví dụ: `ph`, `temperature`, `humidity`)
- `unit_of_measure` - Đơn vị đo
- `reading_last` - Giá trị đọc cuối cùng
- `reading_time` - Thời gian đọc cuối cùng

**Mối quan hệ:**
- 1 module_sensor thuộc về 1 station_module
- Tạo `full_key` = `station_module.name + '.' + module_sensor.name` (ví dụ: `fk.water.ph.ph`)

---

### 7. **fieldkit.aggregated_sensor**
Bảng chứa danh sách tất cả các sensor keys đã được aggregate.

**Các trường:**
- `id` (PRIMARY KEY)
- `key` (TEXT) - Full sensor key (ví dụ: `fk.water.ph.ph`, `fk.weather.temperature1`)

**Mối quan hệ:**
- `key` = `full_key` từ module_sensor + station_module
- 1 aggregated_sensor có thể có nhiều sensor_data (qua `sensor_data.sensor_id`)

---

### 8. **fieldkit.sensor_meta**
Bảng chứa metadata về sensor (label, unit, ranges, visualization config).

**Các trường:**
- `id` (PRIMARY KEY)
- `module_id` (FOREIGN KEY → `module_meta.id`)
- `full_key` (TEXT) - Full sensor key (ví dụ: `fk.water.ph.ph`)
- `sensor_key` - Sensor key (ví dụ: `ph`)
- `firmware_key` - Firmware key
- `uom` - Unit of measure
- `strings` (JSON) - Labels đa ngôn ngữ
- `viz` (JSON) - Visualization config
- `ranges` (JSON) - Min/max ranges
- `aliases` - Aliases của sensor
- `aggregation_function` - Hàm aggregation

**Mối quan hệ:**
- `full_key` khớp với `aggregated_sensor.key`
- 1 sensor_meta thuộc về 1 module_meta

---

### 9. **fieldkit.module_meta**
Bảng chứa metadata về module (template).

**Các trường:**
- `id` (PRIMARY KEY)
- `key` (TEXT) - Module key (ví dụ: `fk.water.ph`, `fk.weather`)
- `manufacturer` - Nhà sản xuất
- `kinds` (INTEGER[]) - Các loại module
- `version` (INTEGER[]) - Các phiên bản
- `internal` - Có phải module nội bộ không

**Mối quan hệ:**
- 1 module_meta có nhiều sensor_meta (qua `sensor_meta.module_id`)

---

### 10. **fieldkit.sensor_data**
Bảng chứa dữ liệu time-series của sensor (TimescaleDB hypertable).

**Các trường:**
- `time` (TIMESTAMPTZ) - Thời gian
- `station_id` (INTEGER) - ID của station
- `module_id` (INTEGER) - ID của station_module
- `sensor_id` (INTEGER) - ID của aggregated_sensor
- `value` (FLOAT) - Giá trị sensor

**Mối quan hệ:**
- `station_id` → `station.id`
- `module_id` → `station_module.id`
- `sensor_id` → `aggregated_sensor.id`

---

## Luồng kết nối từ Station đến Sensor

### Cách 1: Qua Configuration (Hiện tại đang dùng)

```sql
-- Tìm tất cả sensors của một station
SELECT 
    s.id AS station_id,
    s.name AS station_name,
    sm.id AS module_id,
    sm.name AS module_key,
    ms.id AS sensor_id,
    ms.name AS sensor_name,
    sm.name || '.' || ms.name AS full_sensor_key,
    agg_sensor.id AS aggregated_sensor_id
FROM fieldkit.station s
LEFT JOIN fieldkit.visible_configuration vc ON (vc.station_id = s.id)
LEFT JOIN fieldkit.station_configuration sc ON (sc.id = vc.configuration_id)
LEFT JOIN fieldkit.configuration_module cm ON (cm.configuration_id = sc.id)
LEFT JOIN fieldkit.station_module sm ON (sm.id = cm.module_id)
LEFT JOIN fieldkit.module_sensor ms ON (ms.module_id = sm.id)
LEFT JOIN fieldkit.aggregated_sensor agg_sensor ON (agg_sensor.key = sm.name || '.' || ms.name)
WHERE s.id = ?
```

### Cách 2: Qua sensor_data (Time-series data)

```sql
-- Tìm sensors có dữ liệu của một station
SELECT DISTINCT
    sd.station_id,
    sd.module_id,
    sd.sensor_id,
    sm.name AS module_key,
    ms.name AS sensor_name,
    agg_sensor.key AS full_sensor_key
FROM fieldkit.sensor_data sd
LEFT JOIN fieldkit.station_module sm ON (sm.id = sd.module_id)
LEFT JOIN fieldkit.aggregated_sensor agg_sensor ON (agg_sensor.id = sd.sensor_id)
LEFT JOIN fieldkit.module_sensor ms ON (
    ms.module_id = sd.module_id 
    AND sm.name || '.' || ms.name = agg_sensor.key
)
WHERE sd.station_id = ?
```

---

## Key Parameters

### 1. **full_key / full_sensor_key**
- **Công thức:** `station_module.name + '.' + module_sensor.name`
- **Ví dụ:** `fk.water.ph.ph`, `fk.weather.temperature1`, `wh.floodnet.depth`
- **Dùng để:**
  - Join với `aggregated_sensor.key`
  - Join với `sensor_meta.full_key`
  - Tìm metadata từ `sensor_meta`

### 2. **module_id trong sensor_data**
- **Nguồn:** `station_module.id`
- **Dùng để:** Xác định module cụ thể tạo ra reading

### 3. **sensor_id trong sensor_data**
- **Nguồn:** `aggregated_sensor.id`
- **Dùng để:** Xác định loại sensor (qua full_key)

---

## Ví dụ thực tế

### Station có module `fk.water.ph` với sensor `ph`:

1. **Station:** `id = 1, name = "Water Station"`
2. **Visible Configuration:** `station_id = 1, configuration_id = 10`
3. **Station Configuration:** `id = 10`
4. **Configuration Module:** `configuration_id = 10, module_id = 100`
5. **Station Module:** `id = 100, name = "fk.water.ph"`
6. **Module Sensor:** `id = 200, module_id = 100, name = "ph"`
7. **Full Key:** `"fk.water.ph.ph"`
8. **Aggregated Sensor:** `id = 5, key = "fk.water.ph.ph"`
9. **Sensor Meta:** `full_key = "fk.water.ph.ph", strings = {"en-us": {"label": "pH"}}`
10. **Sensor Data:** `station_id = 1, module_id = 100, sensor_id = 5, value = 7.2`

---

## Tóm tắt

- **Station** → **Visible Configuration** → **Station Configuration** → **Configuration Module** → **Station Module** → **Module Sensor**
- **Module Sensor** + **Station Module** → **Full Key** → **Aggregated Sensor** → **Sensor Meta**
- **Sensor Data** lưu: `station_id`, `module_id`, `sensor_id` để kết nối với dữ liệu time-series

