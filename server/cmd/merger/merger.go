package main

import (
	"context"
	"flag"
	"fmt"
	"strings"

	"github.com/kelseyhightower/envconfig"

	"github.com/fieldkit/cloud/server/backend/repositories"
	"github.com/fieldkit/cloud/server/common/logging"
	"github.com/fieldkit/cloud/server/common/sqlxcache"
	"github.com/fieldkit/cloud/server/data"
)

type Options struct {
	PostgresURL  string `split_words:"true"`
	TimeScaleURL string `split_words:"true"`
}

func process(ctx context.Context, options *Options) error {
	log := logging.Logger(ctx).Sugar()

	if err := envconfig.Process("FIELDKIT", options); err != nil {
		panic(err)
	}

	primaryDb, err := sqlxcache.Open(ctx, "postgres", options.PostgresURL)
	if err != nil {
		return err
	}

	tsDb, err := sqlxcache.Open(ctx, "postgres", options.TimeScaleURL)
	if err != nil {
		return err
	}

	log.Infow("querying stations")

	queryStations := repositories.NewStationRepository(primaryDb)

	stations, err := queryStations.QueryAllStationsByModelID(ctx, 7)
	if err != nil {
		return err
	}

	normalizedDeviceIds := make(map[string][]*data.Station)

	for _, station := range stations {
		normalized := strings.ReplaceAll(string(station.DeviceID), "-", "_")

		log.Infow("station", "station_id", station.ID, "device_id", string(station.DeviceID))

		if stations, ok := normalizedDeviceIds[normalized]; !ok {
			stations := make([]*data.Station, 0)
			stations = append(stations, station)
			normalizedDeviceIds[normalized] = stations
		} else {
			normalizedDeviceIds[normalized] = append(stations, station)
		}
	}

	for normalized, stations := range normalizedDeviceIds {
		if len(stations) == 2 {
			originalID := int32(0)
			badID := int32(0)

			stationIDs := make([]int32, 0)
			for _, station := range stations {
				stationIDs = append(stationIDs, station.ID)

				deviceID := string(station.DeviceID)
				normalized := strings.ReplaceAll(deviceID, "-", "_")

				if normalized == deviceID {
					badID = station.ID
				} else {
					originalID = station.ID
				}
			}

			if originalID == 0 {
				panic("originalID == 0")
			}
			if badID == 0 {
				panic("badID == 0")
			}
			if originalID == badID {
				panic("originalID == badID")
			}

			log.Infow("merging", "device_id", normalized, "original_id", originalID, "bad_id", badID)

			sensors, err := queryStations.QueryStationSensors(ctx, stationIDs)
			if err != nil {
				return err
			}

			originalSensors := sensors[originalID]
			badSensors := sensors[badID]

			if len(originalSensors) != len(badSensors) || len(originalSensors) != 1 || len(badSensors) != 1 {
				panic("len(originalSensors) != len(badSensors)")
			}

			if false {
				for _, s := range originalSensors {
					fmt.Printf("O %v\n", s)
				}
				for _, s := range badSensors {
					fmt.Printf("B %v\n", s)
				}
			}

			original := originalSensors[0]
			bad := badSensors[0]

			tx, err := primaryDb.Begin(ctx)
			if err != nil {
				return err
			}

			if _, err := tx.ExecContext(ctx, "UPDATE fieldkit.station SET device_id = $1 WHERE id = $2", fmt.Sprintf("%v-DELETE", normalized), badID); err != nil {
				return err
			}

			if _, err := tx.ExecContext(ctx, "UPDATE fieldkit.station SET device_id = $1 WHERE id = $2", normalized, originalID); err != nil {
				return err
			}

			if err := tx.Rollback(); err != nil {
				return err
			}

			tx, err = tsDb.Begin(ctx)
			if err != nil {
				return err
			}

			if _, err := tx.ExecContext(ctx, `
				DELETE FROM fieldkit.sensor_data WHERE station_id = $1 AND module_id = $2 AND time <=
					(SELECT MAX(time) FROM fieldkit.sensor_data WHERE station_id = $3 AND module_id = $4)
				`,
				bad.StationID, bad.ModulePrimaryID, original.StationID, original.ModulePrimaryID); err != nil {
				return err
			}

			if _, err := tx.ExecContext(ctx, `
				UPDATE fieldkit.sensor_data d SET (station_id, module_id) = ($1, $2) WHERE d.station_id = $3 AND d.module_id = $4
				`,
				original.StationID, original.ModulePrimaryID, bad.StationID, bad.ModulePrimaryID); err != nil {
				return err
			}

			if err := tx.Rollback(); err != nil {
				return err
			}
		}
	}

	return nil
}

func main() {
	ctx := context.Background()
	options := &Options{}

	flag.Parse()

	logging.Configure(false, "merger")

	if err := process(ctx, options); err != nil {
		log := logging.Logger(ctx).Sugar()
		log.Errorw("error", "err", err)
	}
}
