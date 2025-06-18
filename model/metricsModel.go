package model

import (
	"encoding/json"
	"math"
	"net/http"
	"net/url"
	"strconv"

	"github.com/ceticamarco/zephyr/types"
)

func GetMetrics(city *types.City, apiKey string) (types.Metrics, error) {
	url, err := url.Parse(WTR_URL)
	if err != nil {
		return types.Metrics{}, err
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
		return types.Metrics{}, err
	}
	defer res.Body.Close()

	// Structure representing the JSON response
	type MetricsRes struct {
		Current struct {
			Humidity   int     `json:"humidity"`
			Pressure   int     `json:"pressure"`
			DewPoint   float64 `json:"dew_point"`
			UvIndex    float64 `json:"uvi"`
			Visibility float64 `json:"visibility"`
		} `json:"current"`
	}

	var metricRes MetricsRes
	if err := json.NewDecoder(res.Body).Decode(&metricRes); err != nil {
		return types.Metrics{}, err
	}

	return types.Metrics{
		Humidity:   strconv.Itoa(metricRes.Current.Humidity),
		Pressure:   strconv.Itoa(metricRes.Current.Pressure),
		DewPoint:   strconv.FormatFloat(metricRes.Current.DewPoint, 'f', -1, 64),
		UvIndex:    strconv.FormatFloat(math.Round(metricRes.Current.UvIndex), 'f', -1, 64),
		Visibility: strconv.FormatFloat((metricRes.Current.Visibility / 1000), 'f', -1, 64),
	}, nil
}
