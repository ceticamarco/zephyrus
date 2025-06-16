package types

import (
	"time"
)

// CacheType, representing the abstract value of a CacheEntity
type CacheType interface {
	Weather | Metrics
}

// CacheEntity, representing the value of the cache
type CacheEntity[T CacheType] struct {
	Element   T
	Timestamp time.Time
}

// Cache, representing a mapping between a key(str) and a CacheEntity
type Cache[T CacheType] struct {
	Data map[string]CacheEntity[T]
}

// Caches, representing a grouping of the various caches
type Caches struct {
	WeatherCache Cache[Weather]
	MetricsCache Cache[Metrics]
}

func InitCache() *Caches {
	return &Caches{
		WeatherCache: Cache[Weather]{Data: make(map[string]CacheEntity[Weather])},
		MetricsCache: Cache[Metrics]{Data: make(map[string]CacheEntity[Metrics])},
	}
}

func (cache *Cache[T]) GetCache(key string, ttl int8) (T, bool) {
	val, isPresent := cache.Data[key+"_weather"]

	// If key is not present, return a zero value
	if !isPresent {
		return val.Element, false
	}

	// Otherwise check whether cache element is expired
	currentTime := time.Now()
	expired := currentTime.Sub(val.Timestamp) > (time.Duration(ttl) * time.Hour)
	if expired {
		return val.Element, false
	}

	return val.Element, true
}

func (cache *Cache[T]) AddEntry(entry T, cityName string) {
	currentTime := time.Now()

	switch any(entry).(type) {
	case Weather:
		{
			cache.Data[cityName+"_weather"] = CacheEntity[T]{
				Element:   entry,
				Timestamp: currentTime,
			}
		}
	}
}
