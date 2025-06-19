package types

// The WeatherAnomaly data type, representing
// skewed meteorological events
type WeatherAnomaly struct {
	Date ZephyrDate `json:"date"`
	Temp string     `json:"temperature"`
}

// The StatResult data type, representing weather statistics
// of past meteorological events
type StatResult struct {
	Min     string            `json:"min"`
	Max     string            `json:"max"`
	Count   int               `json:"count"`
	Mean    string            `json:"mean"`
	StdDev  string            `json:"stdDev"`
	Median  string            `json:"median"`
	Mode    string            `json:"mode"`
	Anomaly *[]WeatherAnomaly `json:"anomaly"`
}
