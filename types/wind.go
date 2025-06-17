package types

// The Wind data type, representing the wind of a certain location
type Wind struct {
	Arrow     string `json:"arrow"`
	Direction string `json:"direction"`
	Speed     string `json:"speed"`
}
