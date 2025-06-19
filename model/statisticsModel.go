package model

import (
	"errors"
	"slices"
	"strconv"

	"github.com/ceticamarco/zephyr/statistics"
	"github.com/ceticamarco/zephyr/types"
)

func GetStatistics(cityName string, statDB *types.StatDB) (types.StatResult, error) {
	// Check whether there are sufficient and updated records for the given location
	if statDB.IsKeyInvalid(cityName) {
		return types.StatResult{}, errors.New("Insufficient or outdated data to perform statistical analysis")
	}

	extractTemps := func(weatherArr []types.Weather) ([]float64, error) {
		temps := make([]float64, 0, len(weatherArr))

		for _, weather := range weatherArr {
			temperature, err := strconv.ParseFloat(weather.Temperature, 64)
			if err != nil {
				return nil, err
			}
			temps = append(temps, temperature)
		}

		return temps, nil
	}

	// Extract records from the database
	stats := statDB.GetCityStatistics(cityName)

	// Extract temperatures from weather statistics
	temps, err := extractTemps(stats)
	if err != nil {
		return types.StatResult{}, err
	}

	// Detect anomalies
	anomalies := statistics.DetectAnomalies(stats)
	if len(anomalies) == 0 {
		anomalies = nil
	}

	// Compute statistics
	return types.StatResult{
		Min:     slices.Min(temps),
		Max:     slices.Max(temps),
		Count:   len(stats),
		Mean:    statistics.Mean(temps),
		StdDev:  statistics.StdDev(temps),
		Median:  statistics.Median(temps),
		Mode:    statistics.Mode(temps),
		Anomaly: &anomalies,
	}, nil
}
