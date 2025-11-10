# Debug Frontend Location Issues

## Các điểm kiểm tra trong Frontend Code:

### 1. Location Parsing (stations.ts:352-357)
```typescript
if (station.location) {
    if (station.location.precise) {
        this.location = new Location(station.location.precise[1], station.location.precise[0]);
    }
    this.regions = station.location.regions;
}
```
**Vấn đề có thể xảy ra:**
- `station.location` có thể là `null` nếu API không trả về
- `station.location.precise` có thể là `null` nếu project privacy != 0 hoặc user không có quyền
- Format: `precise[1]` = latitude, `precise[0]` = longitude (đúng)

### 2. MappedStations.make() (stations.ts:433-440)
```typescript
const located = stations.filter((station) => station.location != null);
const features = _.flatten(located.map((ds) => MapFeature.makeFeatures(ds)));
```
**Vấn đề có thể xảy ra:**
- Nếu không có stations nào có `location != null`, `features` sẽ rỗng
- Nếu `features` rỗng, `bounds` sẽ là empty BoundingRectangle

### 3. MapFeature.makeFeatures() (stations.ts:416-419)
```typescript
if (station.location) {
    const precise = station.location.lngLat();
    return [new MapFeature(station, "Point", precise, [precise])];
}
```
**Vấn đề có thể xảy ra:**
- Nếu `station.location` là `null`, sẽ throw error "unmappable"
- `lngLat()` trả về `[longitude, latitude]` - đúng format cho Mapbox

### 4. StationsMap Template (StationsMap.vue:1)
```vue
<template v-if="mapped.valid && ready">
```
**Vấn đề có thể xảy ra:**
- Nếu `mapped.valid` = false, toàn bộ map sẽ không render
- `valid` = `this.bounds != null` (stations.ts:462-463)

### 5. updateMap() Check (StationsMap.vue:198-200)
```typescript
if (!this.mapped || !this.mapped.valid || !this.ready) {
    console.log("map: update-skip.2", this.mapped?.valid, this.ready);
    return;
}
```
**Vấn đề có thể xảy ra:**
- Nếu `mapped.valid` = false, updateMap sẽ bỏ qua
- Cần kiểm tra console log để xem có skip không

### 6. isSingleType Check (StationsMap.vue:242)
```typescript
if (!this.mapped.isSingleType) {
    map.addLayer({
        id: "station-markers",
        ...
    });
}
```
**Vấn đề có thể xảy ra:**
- Nếu `isSingleType = true`, layer "station-markers" sẽ KHÔNG được thêm
- Nhưng custom markers vẫn được tạo ở dòng 301-320
- `isSingleType` kiểm tra xem tất cả stations có cùng module type không

### 7. Custom Markers Creation (StationsMap.vue:301-320)
```typescript
for (const feature of sorted) {
    if (feature.geometry != null && feature.properties != null) {
        const marker = new mapboxgl.Marker(instance.$el).setLngLat(feature.geometry.coordinates).addTo(map);
        markers.push({ marker: marker, instance: instance });
    }
}
```
**Vấn đề có thể xảy ra:**
- Nếu `feature.geometry` là `null`, marker sẽ không được tạo
- Nếu `feature.geometry.coordinates` không đúng format, marker sẽ không hiển thị

## Checklist Debug:

1. ✅ **API Response có location.precise không?**
   - Kiểm tra Network tab trong DevTools
   - Endpoint: `/projects/{id}/stations`
   - Response phải có `location.precise: [longitude, latitude]`

2. ✅ **Stations có location trong DisplayStation không?**
   - Console log: `this.$getters.projectsById[1].stations`
   - Mỗi station phải có `location: Location` object

3. ✅ **MappedStations có features không?**
   - Console log: `this.$getters.projectsById[1].mapped.features`
   - Phải có ít nhất 1 feature với `geometry.coordinates`

4. ✅ **MappedStations.valid = true không?**
   - Console log: `this.$getters.projectsById[1].mapped.valid`
   - Phải là `true`

5. ✅ **Map có ready không?**
   - Console log: `this.ready` trong StationsMap component
   - Phải là `true`

6. ✅ **Features có geometry.coordinates không?**
   - Console log: `this.mapped.features[0].geometry.coordinates`
   - Phải là `[longitude, latitude]` array

7. ✅ **isSingleType = false không?**
   - Console log: `this.mapped.isSingleType`
   - Nếu `true`, layer "station-markers" sẽ không được thêm (nhưng custom markers vẫn hoạt động)

## Cách Debug:

1. Mở DevTools Console
2. Kiểm tra các console.log:
   - `"map: mapped changed"` - Khi mapped thay đổi
   - `"map: update-skip.2"` - Nếu updateMap bị skip
   - `"map: updating"` - Khi đang update map
   - `"map: keeping"` - Khi giữ nguyên map

3. Kiểm tra Network tab:
   - Request: `GET /projects/1/stations`
   - Response phải có `location.precise` cho mỗi station

4. Kiểm tra Vue DevTools:
   - Component: `ProjectStations`
   - Computed: `mappedProject`
   - Kiểm tra `mappedProject.features` và `mappedProject.valid`

