package model

import (
	"errors"

	"github.com/ceticamarco/zephyr/types"
)

func GetStatistics(cityName string, statDB *types.StatDB) (types.StatResult, error) {
	// Check whether there are sufficient and updated records for the given location
	if statDB.IsKeyInvalid(cityName) {
		return types.StatResult{}, errors.New("Insufficient or outdated data to perform statistical analysis")
	}
	// TODO: we have enough data, do the math!

	return types.StatResult{}, nil
}
