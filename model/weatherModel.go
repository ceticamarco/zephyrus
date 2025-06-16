package model

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/ceticamarco/zephyr/types"
)

const (
	GEO_URL = "https://api.openweathermap.org/geo/1.0/direct"
	WTR_URL = "https://api.openweathermap.org/data/3.0/onecall"
)

func getEmoji(condition string, isNight bool) string {
	switch condition {
	case "Thunderstorm":
		return "⛈️"
	case "Drizzle":
		return "🌦️"
	case "Rain":
		return "🌧️"
	case "Snow":
		return "☃️"
	case "Mist", "Smoke", "Haze", "Dust", "Fog", "Sand", "Ash", "Squall":
		return "🌫️"
	case "Tornado":
		return "🌪️"
	case "Clear":
		{
			if isNight {
				return "🌙"
			} else {
				return "☀️"
			}
		}
	case "Clouds":
		return "☁️"
	case "SunWithCloud":
		return "🌤️"
	case "CloudWithSun":
		return "🌥️"
	}

	return "❓"
}

func GetCoordinates(cityName string, apiKey string) (types.City, error) {
	url, err := url.Parse(GEO_URL)
	if err != nil {
		return types.City{}, err
	}

	params := url.Query()
	params.Set("q", cityName)
	params.Set("limit", "1")
	params.Set("appid", apiKey)

	url.RawQuery = params.Encode()

	res, err := http.Get(url.String())
	if err != nil {
		return types.City{}, err
	}

	var geoArr []types.City
	if err := json.NewDecoder(res.Body).Decode(&geoArr); err != nil {
		return types.City{}, err
	}

	if len(geoArr) == 0 {
		return types.City{}, errors.New("Cannot find this city")
	}

	return types.City{
		Name: geoArr[0].Name,
		Lat:  geoArr[0].Lat,
		Lon:  geoArr[0].Lon,
	}, nil
}

func GetWeather(city *types.City, apiKey string) (types.Weather, error) {
	url, err := url.Parse(WTR_URL)
	if err != nil {
		return types.Weather{}, err
	}

	params := url.Query()
	params.Set("lat", strconv.FormatFloat(city.Lat, 'E', -1, 64))
	params.Set("lon", strconv.FormatFloat(city.Lon, 'E', -1, 64))
	params.Set("appid", apiKey)
	params.Set("units", "metric")
	params.Set("exclude", "minutely,hourly,daily,alerts")

	url.RawQuery = params.Encode()

	res, err := http.Get(url.String())
	if err != nil {
		return types.Weather{}, err
	}

	// Structures representing the JSON response
	type InfoRes struct {
		Title       string `json:"main"`
		Description string `json:"description"`
		Icon        string `json:"icon"`
	}
	type CurrentRes struct {
		FeelsLike   float64   `json:"feels_like"`
		Temperature float64   `json:"temp"`
		Timestamp   int64     `json:"dt"`
		Weather     []InfoRes `json:"weather"`
	}
	type WeatherRes struct {
		Current CurrentRes `json:"current"`
	}

	var weather WeatherRes
	if err := json.NewDecoder(res.Body).Decode(&weather); err != nil {
		return types.Weather{}, err
	}

	// Format UNIX timestamp as 'YYYY-MM-DD'
	// unixTs, _ := strconv.Atoi(weather.Current.Timestamp)
	utcTime := time.Unix(int64(weather.Current.Timestamp), 0)
	weatherDate := utcTime.UTC()

	// Set condition accordingly to weather description
	var condition string
	switch weather.Current.Weather[0].Description {
	case "few clouds":
		condition = "SunWithCloud"
	case "broken clouds":
		condition = "CloudWithSun"
	default:
		condition = weather.Current.Weather[0].Title
	}

	// Get emoji from weather condition
	isNight := strings.HasSuffix(weather.Current.Weather[0].Icon, "n")
	emoji := getEmoji(condition, isNight)

	return types.Weather{
		Date:        weatherDate,
		Temperature: strconv.FormatFloat(weather.Current.Temperature, 'E', -1, 64),
		FeelsLike:   strconv.FormatFloat(weather.Current.FeelsLike, 'E', -1, 64),
		Condition:   weather.Current.Weather[0].Title,
		Emoji:       emoji,
	}, nil
}
