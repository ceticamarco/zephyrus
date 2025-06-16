package types

// The City data type, representing the name, the latitude and the longitude
// of a location
type City struct {
	Name string  `json:"name"`
	Lat  float64 `json:"lat"`
	Lon  float64 `json:"lon"`
}
