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

	weather, found := cache.GetCache(cityName, vars.TimeToLive)
	if found {
		// Format weather values and then return it
		weather.Temperature = fmtTemperature(weather.Temperature, isImperial)
		weather.FeelsLike = fmtTemperature(weather.FeelsLike, isImperial)

		jsonValue(res, weather)
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

		// Format weather values and then return it
		weather.Temperature = fmtTemperature(weather.Temperature, isImperial)
		weather.FeelsLike = fmtTemperature(weather.FeelsLike, isImperial)

		jsonValue(res, weather)
	}
}
