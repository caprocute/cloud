package main

import (
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/golang/protobuf/proto"

	pb "gitlab.com/fieldkit/libraries/data-protocol"
)

func hashString(seed string) []byte {
	hasher := sha1.New()
	hasher.Write([]byte(seed))
	return hasher.Sum(nil)
}


func newDataReading(metaRecord, readingNumber uint64, deviceID []byte) *pb.DataRecord {
	now := time.Now()

	return &pb.DataRecord{
		Readings: &pb.Readings{
			Time:    int64(now.Unix()),
			Reading: readingNumber,
			Meta:    metaRecord,
			Flags:   0,
			Location: &pb.DeviceLocation{
				Fix:        1,
				Time:       int64(now.Unix()),
				Longitude:  -118.2709223,
				Latitude:   34.0318047,
				Altitude:   rand.Float32() * 100,
				Satellites: 6,
			},
			SensorGroups: []*pb.SensorGroup{
				{
					Module: 0,
					Readings: []*pb.SensorAndValue{
						{
							Sensor: 0, // distance
							Calibrated: &pb.SensorAndValue_CalibratedValue{
								CalibratedValue: 50.0 + rand.Float32()*200.0, // 50-250 cm
							},
						},
						{
							Sensor: 1, // battery
							Calibrated: &pb.SensorAndValue_CalibratedValue{
								CalibratedValue: 3.0 + rand.Float32()*1.2, // 3.0-4.2V
							},
						},
						{
							Sensor: 2, // temperature
							Calibrated: &pb.SensorAndValue_CalibratedValue{
								CalibratedValue: 20.0 + rand.Float32()*15.0, // 20-35C
							},
						},
						{
							Sensor: 3, // altitude
							Calibrated: &pb.SensorAndValue_CalibratedValue{
								CalibratedValue: 100.0 + rand.Float32()*50.0, // 100-150m
							},
						},
						{
							Sensor: 4, // humidity
							Calibrated: &pb.SensorAndValue_CalibratedValue{
								CalibratedValue: 40.0 + rand.Float32()*40.0, // 40-80%
							},
						},
					},
				},
			},
		},
	}
}

func generateFkpbFile(filename string, deviceID, generationID []byte, deviceName string, numRecords int) error {
	file, err := os.Create(filename)
	if err != nil {
		return fmt.Errorf("error creating file: %w", err)
	}
	defer file.Close()

	// Generate metadata record as DataRecord (not SignedRecord)
	// Metadata record uses Record = 0, data records start from Reading = 1
	metaRecordNumber := uint64(0)
	metaDataRecord := &pb.DataRecord{
		Metadata: &pb.Metadata{
			DeviceId:  deviceID,
			Generation: generationID,
			Record:     metaRecordNumber,
			Firmware:   &pb.Firmware{},
		},
		Identity: &pb.Identity{
			Name: deviceName,
		},
		Modules: []*pb.ModuleInfo{
			{
				Position: 0,
				Name:     "modules.floodnet",
				Id:       hashString(fmt.Sprintf("floodnet-%s", string(deviceID))),
				Header: &pb.ModuleHeader{
					Manufacturer: 1, // Conservify
					Kind:         1,
					Version:      0x1,
				},
				Firmware: &pb.Firmware{},
				Sensors: []*pb.SensorInfo{
					{
						Name:          "distance",
						UnitOfMeasure: "cm",
					},
					{
						Name:          "battery",
						UnitOfMeasure: "V",
					},
					{
						Name:          "temperature",
						UnitOfMeasure: "C",
					},
					{
						Name:          "altitude",
						UnitOfMeasure: "m",
					},
					{
						Name:          "humidity",
						UnitOfMeasure: "%",
					},
				},
			},
		},
	}

	// Write metadata record as DataRecord
	buffer := proto.NewBuffer(make([]byte, 0))
	if err := buffer.EncodeMessage(metaDataRecord); err != nil {
		return fmt.Errorf("error encoding meta: %w", err)
	}
	if _, err := file.Write(buffer.Bytes()); err != nil {
		return fmt.Errorf("error writing meta: %w", err)
	}

	// Generate and write data records
	// Data records reference meta record 0, but have Reading numbers starting from 1
	for i := 1; i <= numRecords; i++ {
		dataRecord := newDataReading(0, uint64(i), deviceID)

		buffer := proto.NewBuffer(make([]byte, 0))
		if err := buffer.EncodeMessage(dataRecord); err != nil {
			return fmt.Errorf("error encoding data record %d: %w", i, err)
		}

		if _, err := file.Write(buffer.Bytes()); err != nil {
			return fmt.Errorf("error writing data record %d: %w", i, err)
		}
	}

	fmt.Printf("Generated %s with %d data records\n", filename, numRecords)
	return nil
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// Parse DeviceId từ hex string
	deviceID, err := hex.DecodeString("0123456789abcdef0123456789abcdef")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing device ID: %v\n", err)
		os.Exit(1)
	}

	// GenerationId có thể là hash của device ID hoặc một giá trị cố định
	generationID := hashString("my-test-station-generation")

	// Station 1: My Test Station với ít dữ liệu
	if err := generateFkpbFile("station1-small.fkpb", deviceID, generationID, "My Test Station", 10); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Station 2: My Test Station với nhiều dữ liệu
	if err := generateFkpbFile("station2-medium.fkpb", deviceID, generationID, "My Test Station", 50); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Station 3: My Test Station với rất nhiều dữ liệu
	if err := generateFkpbFile("station3-large.fkpb", deviceID, generationID, "My Test Station", 100); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("\nTất cả các file .fkpb đã được tạo thành công!")
	fmt.Println("Các file:")
	fmt.Println("  - station1-small.fkpb  (10 records)")
	fmt.Println("  - station2-medium.fkpb (50 records)")
	fmt.Println("  - station3-large.fkpb (100 records)")
	fmt.Printf("\nDeviceId: 0123456789abcdef0123456789abcdef\n")
	fmt.Printf("DeviceName: My Test Station\n")
}

