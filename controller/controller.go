package controller

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"

	"github.com/ceticamarco/zephyr/model"
	"github.com/ceticamarco/zephyr/types"
)

func jsonError(res http.ResponseWriter, key string, value string, status int) {
	res.Header().Set("Content-Type", "application/json")
	res.WriteHeader(status)
	json.NewEncoder(res).Encode(map[string]string{key: value})
}

func jsonValue(res http.ResponseWriter, val any) {
	res.Header().Set("Content-Type", "application/json")
	res.WriteHeader(http.StatusOK)
	json.NewEncoder(res).Encode(val)
}

func fmtTemperature(temp string, isImperial bool) string {
	parsedTemp, _ := strconv.ParseFloat(temp, 64)

	if isImperial {
		return fmt.Sprintf("%d°F", int(math.Round(parsedTemp*(9/5)+32)))
	}

	return fmt.Sprintf("%d°C", int(math.Round(parsedTemp)))
}

func fmtWind(windSpeed string, isImperial bool) string {
	// Convert wind speed to mph or km/s from m/s
	// 1 m/s = 2.23694 mph
	// 1 m/s = 3.6 km/h
	parsedSpeed, _ := strconv.ParseFloat(windSpeed, 64)

	if isImperial {
		return fmt.Sprintf("%.1f mph", (parsedSpeed * 2.23694))
	}

	return fmt.Sprintf("%.1f km/h", (parsedSpeed * 3.6))
}

func fmtKey(key string) string {
	// Format cache/database keys by replacing whitespaces with '+' token
	// and making them uppercase
	return strings.ToUpper(strings.ReplaceAll(key, " ", "+"))
}

func deepCopyForecast(original types.Forecast) types.Forecast {
	// Copy the outer structure
	fc_copy := original

	// Allocate enough space
	fc_copy.Forecast = make([]types.ForecastEntity, len(original.Forecast))

	// Copy inner structure
	copy(fc_copy.Forecast, original.Forecast)

	return fc_copy
}

func GetWeather(res http.ResponseWriter, req *http.Request, cache *types.Cache[types.Weather], statDB *types.StatDB, vars *types.Variables) {
	if req.Method != http.MethodGet {
		jsonError(res, "error", "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract city name from '/weather/:city'
	path := strings.TrimPrefix(req.URL.Path, "/weather/")
	cityName := strings.Trim(path, "/") // Remove trailing slash if present

	// Check whether the 'i' parameter(imperial mode) is specified
	isImperial := req.URL.Query().Has("i")

	cachedValue, found := cache.GetEntry(fmtKey(cityName), vars.TimeToLive)
	if found {
		// Format weather object and then return it
		cachedValue.Temperature = fmtTemperature(cachedValue.Temperature, isImperial)
		cachedValue.FeelsLike = fmtTemperature(cachedValue.FeelsLike, isImperial)

		jsonValue(res, cachedValue)
	} else {
		// Get city coordinates
		city, err := model.GetCoordinates(cityName, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Get city weather
		weather, err := model.GetWeather(&city, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Add result to cache
		cache.AddEntry(weather, fmtKey(cityName))

		// Insert new statistic entry into the statistics database
		statDB.AddStatistic(fmtKey(cityName), weather)

		// Format weather object and then return it
		weather.Temperature = fmtTemperature(weather.Temperature, isImperial)
		weather.FeelsLike = fmtTemperature(weather.FeelsLike, isImperial)

		jsonValue(res, weather)
	}
}

func GetMetrics(res http.ResponseWriter, req *http.Request, cache *types.Cache[types.Metrics], vars *types.Variables) {
	if req.Method != http.MethodGet {
		jsonError(res, "error", "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract city name from '/metrics/:city'
	path := strings.TrimPrefix(req.URL.Path, "/metrics/")
	cityName := strings.Trim(path, "/") // Remove trailing slash if present

	// Check whether the 'i' parameter(imperial mode) is specified
	isImperial := req.URL.Query().Has("i")

	cachedValue, found := cache.GetEntry(fmtKey(cityName), vars.TimeToLive)
	if found {
		// Format metrics object and then return it
		cachedValue.Humidity = fmt.Sprintf("%s%%", cachedValue.Humidity)
		cachedValue.Pressure = fmt.Sprintf("%s hPa", cachedValue.Pressure)
		cachedValue.DewPoint = fmtTemperature(cachedValue.DewPoint, isImperial)
		cachedValue.Visibility = fmt.Sprintf("%skm", cachedValue.Visibility)

		jsonValue(res, cachedValue)
	} else {
		// Get city coordinates
		city, err := model.GetCoordinates(cityName, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Get city weather
		metrics, err := model.GetMetrics(&city, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Add result to cache
		cache.AddEntry(metrics, fmtKey(cityName))

		// Format metrics object and then return it
		metrics.Humidity = fmt.Sprintf("%s%%", metrics.Humidity)
		metrics.Pressure = fmt.Sprintf("%s hPa", metrics.Pressure)
		metrics.DewPoint = fmtTemperature(metrics.DewPoint, isImperial)
		metrics.Visibility = fmt.Sprintf("%skm", metrics.Visibility)

		jsonValue(res, metrics)
	}
}

func GetWind(res http.ResponseWriter, req *http.Request, cache *types.Cache[types.Wind], vars *types.Variables) {
	if req.Method != http.MethodGet {
		jsonError(res, "error", "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract city name from '/wind/:city'
	path := strings.TrimPrefix(req.URL.Path, "/wind/")
	cityName := strings.Trim(path, "/") // Remove trailing slash if present

	// Check whether the 'i' parameter(imperial mode) is specified
	isImperial := req.URL.Query().Has("i")

	cachedValue, found := cache.GetEntry(fmtKey(cityName), vars.TimeToLive)
	if found {
		// Format wind object and then return it
		cachedValue.Speed = fmtWind(cachedValue.Speed, isImperial)

		jsonValue(res, cachedValue)
	} else {
		// Get city coordinates
		city, err := model.GetCoordinates(cityName, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Get city wind
		wind, err := model.GetWind(&city, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Add result to cache
		cache.AddEntry(wind, fmtKey(cityName))

		// Format wind object and then return it
		wind.Speed = fmtWind(wind.Speed, isImperial)

		jsonValue(res, wind)
	}
}

func GetForecast(res http.ResponseWriter, req *http.Request, cache *types.Cache[types.Forecast], vars *types.Variables) {
	if req.Method != http.MethodGet {
		jsonError(res, "error", "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract city name from '/forecast/:city'
	path := strings.TrimPrefix(req.URL.Path, "/forecast/")
	cityName := strings.Trim(path, "/") // Remove trailing slash if present

	// Check whether the 'i' parameter(imperial mode) is specified
	isImperial := req.URL.Query().Has("i")

	cachedValue, found := cache.GetEntry(fmtKey(cityName), vars.TimeToLive)
	if found {
		forecast := deepCopyForecast(cachedValue)

		// Format forecast object and then return it
		for idx := range forecast.Forecast {
			val := &forecast.Forecast[idx]

			val.Min = fmtTemperature(val.Min, isImperial)
			val.Max = fmtTemperature(val.Max, isImperial)
			val.FeelsLike = fmtTemperature(val.FeelsLike, isImperial)
			val.Wind.Speed = fmtWind(val.Wind.Speed, isImperial)
		}

		jsonValue(res, forecast)
	} else {
		// Get city coordinates
		city, err := model.GetCoordinates(cityName, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Get city forecast
		forecast, err := model.GetForecast(&city, vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Add result to cache
		cache.AddEntry(deepCopyForecast(forecast), fmtKey(cityName))

		// Format forecast object and then return it
		for idx := range forecast.Forecast {
			val := &forecast.Forecast[idx]

			val.Min = fmtTemperature(val.Min, isImperial)
			val.Max = fmtTemperature(val.Max, isImperial)
			val.FeelsLike = fmtTemperature(val.FeelsLike, isImperial)
			val.Wind.Speed = fmtWind(val.Wind.Speed, isImperial)
		}

		jsonValue(res, forecast)
	}
}

func GetMoon(res http.ResponseWriter, req *http.Request, cache *types.CacheEntity[types.Moon], vars *types.Variables) {
	if req.Method != http.MethodGet {
		jsonError(res, "error", "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	cachedValue, found := cache.GetEntry(vars.TimeToLive)
	if found {
		// Format moon object and then return it
		cachedValue.Percentage = fmt.Sprintf("%s%%", cachedValue.Percentage)

		jsonValue(res, cachedValue)
	} else {
		// Get moon data
		moon, err := model.GetMoon(vars.Token)
		if err != nil {
			jsonError(res, "error", err.Error(), http.StatusBadRequest)
			return
		}

		// Add result to cache
		cache.AddEntry(moon)

		// Format moon object and then return it
		moon.Percentage = fmt.Sprintf("%s%%", moon.Percentage)

		jsonValue(res, moon)
	}
}

func GetStatistics(res http.ResponseWriter, req *http.Request, statDB *types.StatDB) {
	if req.Method != http.MethodGet {
		jsonError(res, "error", "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract city name from '/stats/:city'
	path := strings.TrimPrefix(req.URL.Path, "/stats/")
	cityName := strings.Trim(path, "/") // Remove trailing slash if present

	// Get city statistics
	stats, err := model.GetStatistics(fmtKey(cityName), statDB)
	if err != nil {
		jsonError(res, "error", err.Error(), http.StatusBadRequest)
		return
	}

	jsonValue(res, stats)
}
