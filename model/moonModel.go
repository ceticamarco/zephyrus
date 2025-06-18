package model

import (
	"encoding/json"
	"math"
	"net/http"
	"net/url"
	"strconv"

	"github.com/ceticamarco/zephyr/types"
)

func getMoonPhase(moonValue float64) (string, string) {
	// 0 and 1 are 'new moon',
	// 0.25 is 'first quarter moon',
	// 0.5 is 'full moon' and 0.75 is 'last quarter moon'.
	// The periods in between are called 'waxing crescent',
	// 'waxing gibbous', 'waning gibbous' and 'waning crescent', respectively.
	switch {
	case moonValue == 0, moonValue == 1:
		return "🌑", "New Moon"
	case moonValue > 0 && moonValue < 0.25:
		return "🌒", "Waxing Crescent"
	case moonValue == 0.25:
		return "🌓", "First Quarter"
	case moonValue > 0.25 && moonValue < 0.5:
		return "🌔", "Waxing Gibbous"
	case moonValue == 0.5:
		return "🌕", "Full Moon"
	case moonValue > 0.5 && moonValue < 0.75:
		return "🌖", "Waning Gibbous"
	case moonValue == 0.75:
		return "🌗", "Last Quarter"
	case moonValue > 0.75 && moonValue < 1:
		return "🌘", "Waning Crescent"
	}

	return "❓", "Unknown moon phase"
}

func GetMoon(apiKey string) (types.Moon, error) {
	url, err := url.Parse(WTR_URL)
	if err != nil {
		return types.Moon{}, err
	}

	params := url.Query()
	params.Set("lat", "41.8933203") // Rome latitude
	params.Set("lon", "12.4829321") // Rome longitude
	params.Set("appid", apiKey)
	params.Set("units", "metric")
	params.Set("exclude", "current,hourly,alerts")

	url.RawQuery = params.Encode()

	res, err := http.Get(url.String())
	if err != nil {
		return types.Moon{}, err
	}
	defer res.Body.Close()

	// Structure representing the JSON response
	type MoonRes struct {
		Daily []struct {
			Value float64 `json:"moon_phase"`
		} `json:"daily"`
	}

	var moonRes MoonRes
	if err := json.NewDecoder(res.Body).Decode(&moonRes); err != nil {
		return types.Moon{}, err
	}

	// Retrieve moon icon and moon phase(description) from moon phase(value)
	icon, phase := getMoonPhase(moonRes.Daily[0].Value)

	getMoonPercentage := func(moonVal float64) int {
		// Approximate moon illumination percentage using moon phase
		// by computing \sin(\pi * moonValue)^2
		res := math.Pow(math.Sin(math.Pi*moonVal), 2)

		return int(math.Round(res * 100))
	}

	return types.Moon{
		Icon:       icon,
		Phase:      phase,
		Percentage: strconv.Itoa(getMoonPercentage(moonRes.Daily[0].Value)),
	}, nil
}
