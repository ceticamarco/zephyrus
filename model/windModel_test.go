package model

import (
	"testing"
)

type TestEntry struct {
	Name     string
	Input    float64
	Expected string
}

func TestGetCardinalDir(t *testing.T) {
	tests := []TestEntry{
		{"Bounded value", 65.4, "ENE"},
		{"Out of bound value", 450.3, "E"},
	}

	for _, test := range tests {
		t.Run(test.Name, func(t *testing.T) {
			got, _ := GetCardinalDir(test.Input)

			if got != test.Expected {
				t.Errorf("Got %s, wanted %s", got, test.Expected)
			}
		})
	}
}
