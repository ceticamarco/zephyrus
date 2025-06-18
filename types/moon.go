package types

// The Moon data type, representing the moon phase,
// the moon phase icon and the moon progress(%).
type Moon struct {
	Icon       string `json:"icon"`
	Phase      string `json:"phase"`
	Percentage string `json:"percentage"`
}
