package statistics

import (
	"math"
	"testing"
)

type TestEntry struct {
	Name     string
	Input    []float64
	Expected float64
}

func cmpVal(x, y float64) bool {
	const epsilon = 1e-9

	return math.Abs(x-y) < epsilon
}

func TestMean(t *testing.T) {
	tests := []TestEntry{
		{"Empty list", []float64{}, 0},
		{"Single element", []float64{5.0}, 5.0},
		{"Multiple elements", []float64{2.3, 6.4, -2.2, 8.4}, 3.725},
	}

	for _, test := range tests {
		t.Run(test.Name, func(t *testing.T) {
			got := Mean(test.Input)
			if !cmpVal(got, test.Expected) {
				t.Errorf("Got %v, wanted %v", got, test.Expected)
			}
		})
	}
}

func TestStdDev(t *testing.T) {
	tests := []TestEntry{
		{"Empty list", []float64{}, 0},
		{"Single element", []float64{5.0}, 0},
		{"Multiple elements", []float64{5.0, -4.2, 3.4, 7.2}, 4.288064831599448},
	}

	for _, test := range tests {
		t.Run(test.Name, func(t *testing.T) {
			got := StdDev(test.Input)
			if !cmpVal(got, test.Expected) {
				t.Errorf("Got %v, wanted %v", got, test.Expected)
			}
		})
	}
}

func TestMedian(t *testing.T) {
	tests := []TestEntry{
		{"Empty list", []float64{}, 0},
		{"Single element", []float64{5.0}, 5.0},
		{"Multiple elements (even)", []float64{5.0, -4.2, 3.4, 7.2}, 4.2},
		{"Multiple elements (odd)", []float64{5.0, -4.2, 1.4, 3.4, 7.2}, 3.4},
	}

	for _, test := range tests {
		t.Run(test.Name, func(t *testing.T) {
			got := Median(test.Input)
			if !cmpVal(got, test.Expected) {
				t.Errorf("Got %v, wanted %v", got, test.Expected)
			}
		})
	}
}

func TestMode(t *testing.T) {
	tests := []TestEntry{
		{"Empty list", []float64{}, 0},
		{"Single element", []float64{5.0}, 5.0},
		{"Unique modes", []float64{1.0, 2.0, 2.0, 3.0}, 2.0},
		{"Multi-modal", []float64{1.0, 1.0, 2.0, 3.0, 3.0}, 3.0},
	}

	for _, test := range tests {
		t.Run(test.Name, func(t *testing.T) {
			got := Mode(test.Input)
			if !cmpVal(got, test.Expected) {
				t.Errorf("Got %v, wanted %v", got, test.Expected)
			}
		})
	}
}

func TestRobustZScore(t *testing.T) {
	// Gaussian distributed dataset representing "normal"
	// temperatures; that is, without anomalies
	normalTemps := []float64{
		18.0, 19.0, 19.0, 20.0, 20.0,
		20.0, 21.0, 21.0, 21.0, 21.0,
		22.0, 22.0, 22.0, 22.0, 22.0,
		23.0, 23.0, 23.0, 24.0, 24.0,
	}

	tests := []TestEntry{
		{"Empty list", []float64{}, 0},
		{"Single element", []float64{20.0}, 0},
		{"Temperatures without anomalies", normalTemps, 0},
		{"High anomaly", append(normalTemps, 30.0), 30.0},
		{"Low anomaly", append(normalTemps, 5.0), 5.0},
	}

	for _, test := range tests {
		t.Run(test.Name, func(t *testing.T) {
			got := RobustZScore(test.Input)

			if len(got) != 0 {
				if !cmpVal(got[0].Value, test.Expected) {
					t.Errorf("Got %v, wanted %v", got, test.Expected)
				}
			} else {
				if test.Expected != 0 {
					t.Errorf("Got [], wanted %v", test.Expected)
				}
			}
		})
	}
}
