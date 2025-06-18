package types

// The WeatherAnomaly data type, representing
// skewed meteorological events
type WeatherAnomaly struct {
	Date ZephyrDate `json:"date"`
	Temp float64    `json:"temperature"`
}

// The StatResult data type, representing weather statistics
// of past meteorological events
type StatResult struct {
	Min     float64        `json:"min"`
	Max     float64        `json:"max"`
	Count   int            `json:"count"`
	Mean    float64        `json:"mean"`
	StdDev  float64        `json:"stdDev"`
	Median  float64        `json:"median"`
	Mode    float64        `json:"mode"`
	Anomaly WeatherAnomaly `json:"anomaly"`
}
