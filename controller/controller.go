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

func GetWeather(res http.ResponseWriter, req *http.Request, cache *types.Cache[types.Weather], vars *types.Variables) {
	if req.Method != http.MethodGet {
		jsonError(res, "error", "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract city name from '/weather/:city'
	path := strings.TrimPrefix(req.URL.Path, "/weather/")
	cityName := strings.Trim(path, "/") // Remove trailing slash if present

	// Check whether the 'i' parameter(imperial mode) is specified
	isImperial := req.URL.Query().Has("i")

	cachedValue, found := cache.GetEntry(cityName, vars.TimeToLive)
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
		cache.AddEntry(weather, cityName)

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

	cachedValue, found := cache.GetEntry(cityName, vars.TimeToLive)
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
		cache.AddEntry(metrics, cityName)

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

	cachedValue, found := cache.GetEntry(cityName, vars.TimeToLive)
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
		cache.AddEntry(wind, cityName)

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

	cachedValue, found := cache.GetEntry(cityName, vars.TimeToLive)
	if found {
		// Format forecast object and then return it
		for idx := range cachedValue.Forecast {
			cachedValue.Forecast[idx].Min = fmtTemperature(cachedValue.Forecast[idx].Min, isImperial)
			cachedValue.Forecast[idx].Max = fmtTemperature(cachedValue.Forecast[idx].Max, isImperial)
			cachedValue.Forecast[idx].FeelsLike = fmtTemperature(cachedValue.Forecast[idx].FeelsLike, isImperial)
			cachedValue.Forecast[idx].Wind.Speed = fmtWind(cachedValue.Forecast[idx].Wind.Speed, isImperial)
		}

		jsonValue(res, cachedValue)
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
		cache.AddEntry(forecast, cityName)

		// *****************
		// FIXME: formatting 'forecast' alters cached value
		// *****************

		// Format forecast object and then return it
		for idx := range forecast.Forecast {
			forecast.Forecast[idx].Min = fmtTemperature(forecast.Forecast[idx].Min, isImperial)
			forecast.Forecast[idx].Max = fmtTemperature(forecast.Forecast[idx].Max, isImperial)
			forecast.Forecast[idx].FeelsLike = fmtTemperature(forecast.Forecast[idx].FeelsLike, isImperial)
			forecast.Forecast[idx].Wind.Speed = fmtWind(forecast.Forecast[idx].Wind.Speed, isImperial)
		}

		jsonValue(res, forecast)
	}
}
