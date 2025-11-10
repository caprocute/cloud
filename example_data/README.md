# Example Data Files

Thư mục này chứa các file dữ liệu mẫu định dạng `.fkpb` (FieldKit Protocol Buffer) để test việc upload dữ liệu lên cho station.

## Các file có sẵn

- **station1-small.fkpb**: File nhỏ với 10 data records
- **station2-medium.fkpb**: File trung bình với 50 data records  
- **station3-large.fkpb**: File lớn với 100 data records

## Cách tạo file mới

Để tạo các file `.fkpb` mới, chạy:

```bash
cd example_data
go run generate_fkpb.go
```

Script sẽ tạo 3 file mẫu với dữ liệu từ FloodNet station bao gồm các sensors:
- distance (khoảng cách, cm)
- battery (pin, V)
- temperature (nhiệt độ, C)
- altitude (độ cao, m)
- humidity (độ ẩm, %)

## Cách sử dụng file để upload

### Sử dụng tool `fkdata`:

```bash
# Build tool fkdata
cd ../server/cmd/fkdata
go build -o ../../../build/fkdata

# Set thông tin đăng nhập
export FIELDKIT_EMAIL="your-email@example.com"
export FIELDKIT_PASSWORD="your-password"

# Upload file
cd ../../../example_data
../../build/fkdata -file station1-small.fkpb -portal https://your-portal-url.com
```

### Sử dụng curl (tự động generate):

```bash
# Generate lệnh curl từ file
./generate_curl.sh station1-small.fkpb https://api.fieldkit.org

# Hoặc với token có sẵn
./generate_curl.sh station1-small.fkpb https://api.fieldkit.org "Bearer your-token"
```

### Sử dụng curl (thủ công):

```bash
# 1. Đăng nhập để lấy token
TOKEN=$(curl -X POST https://your-portal-url.com/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your-email@example.com","password":"your-password"}' \
  -i | grep -i authorization | cut -d' ' -f2)

# 2. Upload file
curl -X POST https://your-portal-url.com/ingestion \
  -H "Content-Type: application/octet-stream" \
  -H "Authorization: $TOKEN" \
  -H "Fk-DeviceId: 0123456789abcdef0123456789abcdef" \
  -H "Fk-Generation: f64c34338a1a0b6629617ae73c24fb1f9f2d5808" \
  -H "Fk-DeviceName: My Test Station" \
  -H "Fk-Blocks: 0,10" \
  -H "Fk-Type: data" \
  --data-binary @station1-small.fkpb
```

### Kiểm tra metadata của file:

```bash
cd ../server/cmd/fkdata
go build -o ../../../build/fkdata

cd ../../../example_data
../../build/fkdata -file station1-small.fkpb
```

## Cấu trúc file .fkpb

File `.fkpb` chứa:
1. **Metadata record** (SignedRecord): Thông tin về device, modules, sensors
2. **Data records**: Các readings từ sensors theo thời gian

Mỗi record được encode theo format length-prefixed protocol buffer.

## Lưu ý

- Mỗi file có DeviceId và GenerationId riêng
- File phải có ít nhất 1 metadata record và 1 data record
- DeviceId và GenerationId phải khớp với station đã tạo trong hệ thống

