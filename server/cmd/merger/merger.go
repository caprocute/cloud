package main

import (
	"context"
	"encoding/hex"
	"flag"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	"github.com/kelseyhightower/envconfig"

	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/storage"
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

func (s *StationMerger) MergeSensorData(ctx context.Context, tx *sqlx.Tx, keepingModuleID int64, emptyingModuleID int64) error {
	log := logging.Logger(ctx).Sugar()

	row := tx.QueryRowContext(ctx, `SELECT MAX(time) AS max_time FROM fieldkit.sensor_data WHERE module_id = $1`, keepingModuleID)

	if err := row.Err(); err != nil {
		return err
	}

	before := time.Time{}
	if err := row.Scan(&before); err != nil {
		return err
	}

	log.Infow("original:max", "time", before, "keeping_module_id", keepingModuleID, "emptying_module_id", emptyingModuleID)

	if _, err := tx.ExecContext(ctx, `
		DELETE FROM fieldkit.sensor_data WHERE module_id = $1 AND time <=
			(SELECT MAX(time) FROM fieldkit.sensor_data WHERE module_id = $2)
		`,
		emptyingModuleID, keepingModuleID); err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE fieldkit.sensor_data d SET module_id = $1 WHERE d.module_id = $2
		`,
		keepingModuleID, emptyingModuleID); err != nil {
		return err
	}

	return nil
}

func (s *StationMerger) processModel(outerCtx context.Context, options *Options, modelID int32) error {
	log := logging.Logger(outerCtx).Sugar()

	stations, err := s.queryStations.QueryAllStationsByModelID(outerCtx, modelID)
	if err != nil {
		return err
	}

	modules, err := s.queryStations.QueryAllStationModules(outerCtx)
	if err != nil {
		return err
	}

	log.Infow("modules", "total_modules", len(modules))

	byHardwareId := make(map[string][]int64)
	deletingModules := make(map[int64]int64)
	for _, module := range modules {
		id := hex.EncodeToString(module.HardwareID)
		if byHardwareId[id] == nil {
			byHardwareId[id] = make([]int64, 0)
		}
		byHardwareId[id] = append(byHardwareId[id], module.ID)
		if len(byHardwareId[id]) > 1 {
			deletingModules[module.ID] = byHardwareId[id][0]
		}
	}

	log.Infow("modules", "unique_modules", len(byHardwareId), "deleting", len(deletingModules))

	moduleStations := make(map[int64][]int32)

	for _, station := range stations {
		log.Infow("station", "station_id", station.ID, "station_name", station.Name)

		err := s.primaryDb.WithNewOwnedTransaction(outerCtx, func(ctx context.Context, tx *sqlx.Tx) error {
			full, err := s.queryStations.QueryStationFull(ctx, station.ID)
			if err != nil {
				return err
			}

			if len(full.Configurations) == 1 {
				config := full.Configurations[0]
				configID := config.ID

				for _, module := range full.Modules {
					moduleID := module.ID
					if keeping, ok := deletingModules[module.ID]; ok {
						moduleID = keeping
					}

					moduleConfig := data.ConfigurationModule{
						ConfigurationID: configID,
						ModuleID:        moduleID,
						Index:           module.Index,
						Position:        module.Position,
					}

					log.Infow("config:module", "configuration_id", config.ID, "module_id", module.ID, "merged_module_id", moduleConfig.ModuleID)

					_, err := s.queryStations.InsertConfigurationModule(ctx, &moduleConfig)
					if err != nil {
						return err
					}

					if moduleStations[module.ID] != nil {
						return fmt.Errorf("module seen before, unexpectedly")
					}
					moduleStations[module.ID] = []int32{station.ID}
				}
			} else if len(full.Configurations) > 1 {
				for _, config := range full.Configurations {
					empty := true

					for _, module := range full.Modules {
						if module.ConfigurationID == config.ID {
							moduleID := module.ID
							if keeping, ok := deletingModules[module.ID]; ok {
								moduleID = keeping
							}

							moduleConfig := data.ConfigurationModule{
								ConfigurationID: config.ID,
								ModuleID:        moduleID,
								Index:           module.Index,
								Position:        module.Position,
							}

							log.Infow("config:module", "configuration_id", config.ID, "module_id", module.ID, "merged_module_id", moduleConfig.ModuleID)

							_, err := s.queryStations.InsertConfigurationModule(ctx, &moduleConfig)
							if err != nil {
								return err
							}

							if moduleStations[moduleID] == nil {
								moduleStations[moduleID] = make([]int32, 0)
							}
							moduleStations[moduleID] = append(moduleStations[moduleID], station.ID)

							empty = false
						}
					}

					if empty {
						log.Infow("config:empty, deleting", "configuration_id", config.ID)

						/*
							_, err = tx.ExecContext(ctx, "DELETE FROM visible_configuration WHERE configuration_id = $1", config.ID)
							if err != nil {
								return err
							}
						*/

						_, err := tx.ExecContext(ctx, "DELETE FROM station_configuration WHERE id = $1", config.ID)
						if err != nil {
							return err
						}
					}
				}
			}

			if options.Commit {
				return tx.Commit()
			} else {
				return tx.Rollback()
			}
		})
		if err != nil {
			return err
		}

		/*
			primaryTx, err := s.primaryDb.Begin(ctx)
			if err != nil {
				return err
			}

			tsTx, err := s.tsDb.Begin(ctx)
			if err != nil {
				return err
			}

			modulesUpdate, err := tx.ExecContext(txCtx, "UPDATE station_module SET station_id = $1 WHERE configuration_id = $2", station.ID, configID)
			if err != nil {
				return err
			}

			numberModules, err := modulesUpdate.RowsAffected()
			if err != nil {
				return err
			}

			sensorsUpdate, err := tx.ExecContext(txCtx, "UPDATE module_sensor SET station_id = $1 WHERE configuration_id = $2", station.ID, configID)
			if err != nil {
				return err
			}

			numberSensors, err := sensorsUpdate.RowsAffected()
			if err != nil {
				return err
			}

			log.Infow("config:solo", "modules", numberModules, "sensors", numberSensors)

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
		*/
	}

	err = s.primaryDb.WithNewOwnedTransaction(outerCtx, func(ctx context.Context, tx *sqlx.Tx) error {
		for deletingID, keepingID := range deletingModules {
			log.Infow("deleting", "module_id", deletingID)

			if err := s.queryStations.DeleteStationModule(ctx, deletingID); err != nil {
				return err
			}

			_ = keepingID
		}

		if options.Commit {
			return tx.Commit()
		} else {
			return tx.Rollback()
		}
	})
	if err != nil {
		return err
	}

	_ = log

	return nil
}

func (s *StationMerger) ProcessAllStations(ctx context.Context, options *Options) error {
	models, err := s.queryStations.QueryStationModels(ctx)
	if err != nil {
		return err
	}

	for _, model := range models {
		if model.ID == 1 {
			if err := s.processModel(ctx, options, model.ID); err != nil {
				return err
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

	if err := merger.ProcessAllStations(ctx, options); err != nil {
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
