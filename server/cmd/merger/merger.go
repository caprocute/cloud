package main

import (
	"context"
	"flag"
	"fmt"
	"strings"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/kelseyhightower/envconfig"

	"github.com/fieldkit/cloud/server/backend/repositories"
	"github.com/fieldkit/cloud/server/common/logging"
	"github.com/fieldkit/cloud/server/common/sqlxcache"
	"github.com/fieldkit/cloud/server/data"
	"github.com/fieldkit/cloud/server/storage"
)

type Options struct {
	PostgresURL  string `split_words:"true"`
	TimeScaleURL string `split_words:"true"`
	Commit       bool
}

func (options *Options) timeScaleConfig() *storage.TimeScaleDBConfig {
	if options.TimeScaleURL == "" {
		return nil
	}

	return &storage.TimeScaleDBConfig{Url: options.TimeScaleURL}
}

func (options *Options) refreshViews(ctx context.Context) error {
	tsConfig := options.timeScaleConfig()

	if tsConfig == nil {
		return fmt.Errorf("refresh-views missing tsdb configuration")
	}

	return tsConfig.RefreshViews(ctx)
}

type StationMerger struct {
	primaryDb     *sqlxcache.DB
	tsDb          *sqlxcache.DB
	queryStations *repositories.StationRepository
}

func NewStationMerger(primaryDb *sqlxcache.DB, tsDb *sqlxcache.DB) *StationMerger {
	return &StationMerger{
		primaryDb:     primaryDb,
		tsDb:          tsDb,
		queryStations: repositories.NewStationRepository(primaryDb),
	}
}

func (s *StationMerger) ProcessModel(ctx context.Context, options *Options, modelID int32) error {
	log := logging.Logger(ctx).Sugar()

	stations, err := s.queryStations.QueryAllStationsByModelID(ctx, modelID)
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

			originalDeviceId := normalized
			stationIDs := make([]int32, 0)
			for _, station := range stations {
				stationIDs = append(stationIDs, station.ID)

				deviceID := string(station.DeviceID)
				normalized := strings.ReplaceAll(deviceID, "-", "_")

				if normalized == deviceID {
					badID = station.ID
				} else {
					originalID = station.ID
					originalDeviceId = deviceID
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

			sensors, err := s.queryStations.QueryStationSensors(ctx, stationIDs)
			if err != nil {
				return err
			}

			originalSensors := sensors[originalID]
			badSensors := sensors[badID]

			keyed := make(map[string][]*repositories.StationSensor)

			for _, sensor := range originalSensors {
				sensors := make([]*repositories.StationSensor, 0)
				keyed[*sensor.SensorKey] = append(sensors, sensor)
			}

			for _, sensor := range badSensors {
				// Key should already be there or something is wrong.
				keyed[*sensor.SensorKey] = append(keyed[*sensor.SensorKey], sensor)
			}

			primaryTx, err := s.primaryDb.Begin(ctx)
			if err != nil {
				return err
			}

			tsTx, err := s.tsDb.Begin(ctx)
			if err != nil {
				return err
			}

			modulesDone := make(map[int64]bool)

			for _, sensors := range keyed {
				if len(sensors) != 2 {
					spew.Dump(keyed)
					panic("len(sensors) != 2")
				}

				original := sensors[0]
				bad := sensors[1]

				if _, ok := modulesDone[*bad.ModulePrimaryID]; ok {
					continue
				}

				if _, err := primaryTx.ExecContext(ctx, "UPDATE fieldkit.station SET device_id = $1 WHERE id = $2", fmt.Sprintf("%v-DELETE", normalized), badID); err != nil {
					return err
				}

				if _, err := primaryTx.ExecContext(ctx, "UPDATE fieldkit.station SET device_id = $1 WHERE id = $2", normalized, originalID); err != nil {
					return err
				}

				if _, err := primaryTx.ExecContext(ctx, "UPDATE fieldkit.provision SET device_id = $1 WHERE device_id = $2", fmt.Sprintf("%v-DELETE", normalized), normalized); err != nil {
					return err
				}

				if _, err := primaryTx.ExecContext(ctx, "UPDATE fieldkit.provision SET device_id = $1 WHERE device_id = $2", normalized, originalDeviceId); err != nil {
					return err
				}

				row := tsTx.QueryRowContext(ctx, `SELECT MAX(time) AS max_time FROM fieldkit.sensor_data WHERE station_id = $1 AND module_id = $2`, original.StationID, original.ModulePrimaryID)

				if err := row.Err(); err != nil {
					return err
				}

				before := time.Time{}
				if err := row.Scan(&before); err != nil {
					return err
				}

				log.Infow("original:max", "time", before, "station_id", original.StationID, "module_id", original.ModulePrimaryID)

				if _, err := tsTx.ExecContext(ctx, `
					DELETE FROM fieldkit.sensor_data WHERE station_id = $1 AND module_id = $2 AND time <=
						(SELECT MAX(time) FROM fieldkit.sensor_data WHERE station_id = $3 AND module_id = $4)
					`,
					bad.StationID, bad.ModulePrimaryID, original.StationID, original.ModulePrimaryID); err != nil {
					return err
				}

				if _, err := tsTx.ExecContext(ctx, `
					UPDATE fieldkit.sensor_data d SET (station_id, module_id) = ($1, $2) WHERE d.station_id = $3 AND d.module_id = $4
					`,
					original.StationID, original.ModulePrimaryID, bad.StationID, bad.ModulePrimaryID); err != nil {
					return err
				}

				modulesDone[*bad.ModulePrimaryID] = true
			}

			if options.Commit {
				if err := primaryTx.Commit(); err != nil {
					return err
				}
				if err := tsTx.Commit(); err != nil {
					return err
				}
			} else {
				if err := primaryTx.Rollback(); err != nil {
					return err
				}
				if err := tsTx.Rollback(); err != nil {
					return err
				}
			}
		} else {
			for _, station := range stations {
				_, err := s.queryStations.QueryStationSensors(ctx, []int32{227})
				if err != nil {
					return err
				}

				_ = station
			}
		}
	}

	return nil
}

func process(ctx context.Context, options *Options) error {
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

	merger := NewStationMerger(primaryDb, tsDb)

	if err := merger.ProcessModel(ctx, options, 8); err != nil {
		return err
	}

	if err := merger.ProcessModel(ctx, options, 7); err != nil {
		return err
	}

	if options.Commit {
		if err := options.refreshViews(ctx); err != nil {
			return err
		}
	}

	return nil
}

func main() {
	ctx := context.Background()
	options := &Options{}

	flag.BoolVar(&options.Commit, "commit", false, "Commit, otherwise changes will be rolled back.")

	flag.Parse()

	logging.Configure(false, "merger")

	if err := process(ctx, options); err != nil {
		log := logging.Logger(ctx).Sugar()
		log.Errorw("error", "err", err)
	}
}
