package model

import (
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/ceticamarco/zephyr/types"
)

// Structure representing the JSON response
type tempRes struct {
	Min float64 `json:"min"`
	Max float64 `json:"max"`
}

type fsRes struct {
	Day float64 `json:"day"`
}

type weatherRes struct {
	Title       string `json:"main"`
	Description string `json:"description"`
	Icon        string `json:"icon"`
}

type dailyRes struct {
	Temp      tempRes      `json:"temp"`
	FeelsLike fsRes        `json:"feels_like"`
	Weather   []weatherRes `json:"weather"`
	WindSpeed float64      `json:"wind_speed"`
	WindDeg   float64      `json:"wind_deg"`
	Timestamp int64        `json:"dt"`
}

type forecastRes struct {
	Daily []dailyRes `json:"daily"`
}

func getForecastEntity(dailyForecast dailyRes) types.ForecastEntity {
	// Format UNIX timestamp as 'YYYY-MM-DD'
	utcTime := time.Unix(int64(dailyForecast.Timestamp), 0)
	weatherDate := &types.ZephyrDate{Time: utcTime.UTC()}

	// Set condition accordingly to weather description
	var condition string
	switch dailyForecast.Weather[0].Description {
	case "few clouds":
		condition = "SunWithCloud"
	case "broken clouds":
		condition = "CloudWithSun"
	default:
		condition = dailyForecast.Weather[0].Title
	}

	// Get emoji from weather condition
	isNight := strings.HasSuffix(dailyForecast.Weather[0].Icon, "n")
	emoji := GetEmoji(condition, isNight)

	// Get cardinal direction and wind arrow
	windDirection, windArrow := GetCardinalDir(dailyForecast.WindDeg)

	return types.ForecastEntity{
		Date:      weatherDate,
		Min:       strconv.FormatFloat(dailyForecast.Temp.Min, 'f', -1, 64),
		Max:       strconv.FormatFloat(dailyForecast.Temp.Max, 'f', -1, 64),
		Condition: dailyForecast.Weather[0].Title,
		Emoji:     emoji,
		FeelsLike: strconv.FormatFloat(dailyForecast.FeelsLike.Day, 'f', -1, 64),
		Wind: types.Wind{
			Arrow:     windArrow,
			Direction: windDirection,
			Speed:     strconv.FormatFloat(dailyForecast.WindSpeed, 'f', 2, 64),
		},
	}

}

func GetForecast(city *types.City, apiKey string) (types.Forecast, error) {
	url, err := url.Parse(WTR_URL)
	if err != nil {
		return types.Forecast{}, err
	}

	params := url.Query()
	params.Set("lat", strconv.FormatFloat(city.Lat, 'f', -1, 64))
	params.Set("lon", strconv.FormatFloat(city.Lon, 'f', -1, 64))
	params.Set("appid", apiKey)
	params.Set("units", "metric")
	params.Set("exclude", "current,minutely,hourly,alerts")

	url.RawQuery = params.Encode()

	res, err := http.Get(url.String())
	if err != nil {
		return types.Forecast{}, err
	}
	defer res.Body.Close()

	var forecastRes forecastRes
	if err := json.NewDecoder(res.Body).Decode(&forecastRes); err != nil {
		return types.Forecast{}, err
	}

	// We skip the first element since it represents the current day
	// We ignore forecasts after the fourth day
	var forecast []types.ForecastEntity
	for _, val := range forecastRes.Daily[1:5] {
		forecast = append(forecast, getForecastEntity(val))
	}

	return types.Forecast{
		Forecast: forecast,
	}, nil
}
