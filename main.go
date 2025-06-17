package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/ceticamarco/zephyr/controller"
	"github.com/ceticamarco/zephyr/types"
)

func main() {
	// Retrieve listening port, API token and cache time-to-live from environment variables
	var (
		port   = os.Getenv("ZEPHYR_PORT")
		token  = os.Getenv("ZEPHYR_TOKEN")
		ttl, _ = strconv.ParseInt(os.Getenv("ZEPHYR_CACHE_TTL"), 10, 8)
	)

	if port == "" || token == "" || ttl == 0 {
		log.Fatalf("Environment variables not set")
	}

	// Initialize cache and vars
	cache := types.InitCache()
	vars := types.Variables{
		Token:      token,
		TimeToLive: int8(ttl),
	}

	// API endpoints
	http.HandleFunc("/weather/", func(res http.ResponseWriter, req *http.Request) {
		controller.GetWeather(res, req, &cache.WeatherCache, &vars)
	})

	http.HandleFunc("/metrics/", func(res http.ResponseWriter, req *http.Request) {
		controller.GetMetrics(res, req, &cache.MetricsCache, &vars)
	})

	listenAddr := fmt.Sprintf(":%s", port)
	log.Printf("Server listening on %s", listenAddr)
	http.ListenAndServe(listenAddr, nil)
}
