package model

import (
	"encoding/json"
	"math"
	"net/http"
	"net/url"
	"strconv"

	"github.com/ceticamarco/zephyr/types"
)

func GetCardinalDir(windDeg float64) (string, string) {
	// Each cardinal direction represents a segment of 22.5 degrees
	cardinalDirections := [16][2]string{
		{"N", "⬇️"},   // 0/360 DEG
		{"NNE", "↙️"}, // 22.5 DEG
		{"NE", "↙️"},  // 45 DEG
		{"ENE", "↙️"}, // 67.5 DEG
		{"E", "⬅️"},   // 90 DEG
		{"ESE", "↖️"}, // 112.5 DEG
		{"SE", "↖️"},  // 135 DEG
		{"SSE", "↖️"}, // 157.5 DEG
		{"S", "⬆️"},   // 180 DEG
		{"SSW", "↗️"}, // 202.5 DEG
		{"SW", "↗️"},  // 225 DEG
		{"WSW", "↗️"}, // 247.5 DEG
		{"W", "➡️"},   // 270 DEG
		{"WNW", "↘️"}, // 292.5 DEG
		{"NW", "↘️"},  // 315 DEG
		{"NNW", "↘️"}, // 337.5 DEG
	}

	// Computes "idx ≡ round(wind_deg / 22.5) (mod 16)"
	// to ensure that values above 360 degrees or below 0 degrees
	// "stay bounded" to the map
	idx := int(math.Round(windDeg/22.5)) % 16

	return cardinalDirections[idx][0], cardinalDirections[idx][1]

}

func GetWind(city *types.City, apiKey string) (types.Wind, error) {
	url, err := url.Parse(WTR_URL)
	if err != nil {
		return types.Wind{}, err
	}

	params := url.Query()
	params.Set("lat", strconv.FormatFloat(city.Lat, 'f', -1, 64))
	params.Set("lon", strconv.FormatFloat(city.Lon, 'f', -1, 64))
	params.Set("appid", apiKey)
	params.Set("units", "metric")
	params.Set("exclude", "minutely,hourly,daily,alerts")

	url.RawQuery = params.Encode()

	res, err := http.Get(url.String())
	if err != nil {
		return types.Wind{}, err
	}

	defer res.Body.Close()

	// Structure representing the JSON response
	type WindRes struct {
		Current struct {
			Speed   float64 `json:"wind_speed"`
			Degrees float64 `json:"wind_deg"`
		} `json:"current"`
	}

	var windRes WindRes
	if err := json.NewDecoder(res.Body).Decode(&windRes); err != nil {
		return types.Wind{}, err
	}

	// Get cardinal direction and wind arrow
	windDirection, windArrow := GetCardinalDir(windRes.Current.Degrees)

	return types.Wind{
		Arrow:     windArrow,
		Direction: windDirection,
		Speed:     strconv.FormatFloat(windRes.Current.Speed, 'f', 2, 64),
	}, nil
}
