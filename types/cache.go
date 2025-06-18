package types

import (
	"time"
)

// cacheType, representing the abstract value of a CacheEntity
type cacheType interface {
	Weather | Metrics | Wind | Forecast | Moon
}

// CacheEntity, representing the value of the cache
type CacheEntity[T cacheType] struct {
	element   T
	timestamp time.Time
}

// Cache, representing a mapping between a key(str) and a CacheEntity
type Cache[T cacheType] struct {
	Data map[string]CacheEntity[T]
}

// Caches, representing a grouping of the various caches
type Caches struct {
	WeatherCache  Cache[Weather]
	MetricsCache  Cache[Metrics]
	WindCache     Cache[Wind]
	ForecastCache Cache[Forecast]
	MoonCache     CacheEntity[Moon]
}

func InitCache() *Caches {
	return &Caches{
		WeatherCache:  Cache[Weather]{Data: make(map[string]CacheEntity[Weather])},
		MetricsCache:  Cache[Metrics]{Data: make(map[string]CacheEntity[Metrics])},
		WindCache:     Cache[Wind]{Data: make(map[string]CacheEntity[Wind])},
		ForecastCache: Cache[Forecast]{Data: make(map[string]CacheEntity[Forecast])},
		MoonCache:     CacheEntity[Moon]{element: Moon{}, timestamp: time.Time{}},
	}
}

func (cache *Cache[T]) GetEntry(key string, ttl int8) (T, bool) {
	val, isPresent := cache.Data[key]

	// If key is not present, return a zero value
	if !isPresent {
		return val.element, false
	}

	// Otherwise check whether cache element is expired
	currentTime := time.Now()
	expired := currentTime.Sub(val.timestamp) > (time.Duration(ttl) * time.Hour)
	if expired {
		return val.element, false
	}

	return val.element, true
}

func (cache *Cache[T]) AddEntry(entry T, cityName string) {
	currentTime := time.Now()

	cache.Data[cityName] = CacheEntity[T]{
		element:   entry,
		timestamp: currentTime,
	}

}

func (moon *CacheEntity[Moon]) GetEntry(ttl int8) (Moon, bool) {
	var zeroMoon Moon

	// If moon data is not present, return a zero value
	if moon == nil {
		return zeroMoon, false
	}

	// Otherwise check whether the element is expired
	currentTime := time.Now()
	expired := currentTime.Sub(moon.timestamp) > (time.Duration(ttl) * time.Hour)
	if expired {
		return zeroMoon, false
	}

	return moon.element, true
}

func (cache *CacheEntity[Moon]) AddEntry(entry Moon) {
	currentTime := time.Now()

	cache.element = entry
	cache.timestamp = currentTime
}
