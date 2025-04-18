<div align="center">
<h1>Zephyrus 🌲</h1>
    
<h6><i>Web service for weather statistics</i></h6>

[![](https://github.com/ceticamarco/zephyrus/actions/workflows/docker.yml/badge.svg)](https://github.com/ceticamarco/zephyrus/actions/workflows/docker.yml)
[![](https://github.com/ceticamarco/zephyrus/actions/workflows/linter.yml/badge.svg)](https://github.com/ceticamarco/zephyrus/actions/workflows/linter.yml)

</div>

**Zephyrus** is a lightweight HTTP weather service designed to provide a simple way to
gather meteorological data and apply statistical analysis to past weather conditions. It's written in 
Haskell using [Servant](https://www.servant.dev/) and [OpenWeatherMap](https://openweathermap.org).

I've built this service out of frustration with existing
weather platforms cluttered with ads, paywalls, clickbait contents and unnecessary features.
Zephyrus only gets you the essential information about the weather conditions of a given location without any additional nonsense.

This service communicates through a JSON API, making
it suitable for use in any kind of project or device. I already use it on my phone,
on my terminal, on the tmux's status bar and on a couple of smart bedside alarm clocks I've built.

## Basic Usage
As stated before, Zephyrus communicates via HTTP using the JSON format; therefore, you can
query it through any kind of HTTP client such as cURL. Below you can find some examples of use.

### Weather
The `/weather/:city` route allows you to retrieve generic weather conditions-such as the temperature,
the condition icon(represented by an emoji) and a textual description. For example:

```sh
$ curl -s 'http://127.0.0.1:3000/weather/milan' | jq
```
will yield the following:

```json
{
  "celsiusTemp": "21°C",
  "condEmoji": "☀️",
  "condition": "Clear",
  "date": "Mon, 31/03/2025",
  "fahrenheitTemp": "+69°F"
}
```

### Metrics

The `/metrics/:city` route allows you to retrieve environmental metrics about a certain location,
for example:


```sh
$ curl -s 'http://127.0.0.1:3000/metrics/taipei' | jq
```

will yield:

```json
{
  "celsiusDewPoint": "13°C",
  "fahrenheitDewPoint": "55°F",
  "humidity": "94%",
  "pressure": "1020 hPa",
  "uvIndex": 0,
  "visibility": "5km"
}
```

### Wind
The `/wind/:city` route allows you to retrieve wind related data(such as speed and the direction)
of a specific location. For example,

```sh
$ curl -s 'http://127.0.0.1:3000/wind/bolzano' | jq
```

will yield

```json
{
  "arrow": "↙",
  "direction": "NNE",
  "imperialSpeed": "13.80 mph",
  "metricSpeed": "22.21 km/h"
}
```

### Forecast
The `/forecast/:city` route allows you to request the weather forecast
of the next five days(that is, an array containing five weather objects). For example,

```sh
$  curl -s 'http://127.0.0.1:3000/forecast/Yakutsk' | jq
```

will yield

```json
{
  "forecast": [
    {
      "celsiusTemp": "-1°C",
      "condEmoji": "☃️",
      "condition": "Snow",
      "date": "Fri, 11/04/2025",
      "fahrenheitTemp": "30°F"
    },
    {
      "celsiusTemp": "-7°C",
      "condEmoji": "☁️",
      "condition": "Clouds",
      "date": "Sat, 12/04/2025",
      "fahrenheitTemp": "19°F"
    },
  ]
}
```

### Moon
The `/moon` route provides the current moon phase along with an icon representing it.
For example,

```sh
$ curl -s 'http://127.0.0.1:3000/moon' | jq  
```

will yield

```json
{
  "icon": "🌔",
  "percentage": "Waxing Gibbous",
  "phase": "89%"
}
```

To convert OpenWeatherMap's moon phase value to the illumination percentage, 
I've used the following formula:

$$
  \sin(\pi \theta)^2 \times 100
$$

where $\theta$ represent the moon phase value.

## Statistical analysis
In addition to the previous routes, Zephyrus provides another endpoint, called `/stats/:city`,
which can be used to retrieve additional statistics about the weather of the
previous days. This includes the arithmetical mean of the temperatures, 
the maximum and the minimum values, the median, the mode and the standard deviation.

This endpoint becomes available only after the system has gathered sufficient
_updated_ data; that if and only if there are **at least** two weather
records for a given location, and they are **within the previous 48 hours**. If these
two conditions aren't met, Zephyrus will refuse to provide a statistical report.

After enough data has been recorded in the in-memory database, you will be able
to retrieve the statistics, for example:

```sh
$ curl -s 'http://127.0.0.1:3000/stats/berlin'
```

will yield(not real data):

```json
{                                                                                 
  "anomaly": null,                      
  "count": 12,
  "maximum": 30,
  "mean": 13.9167,                       
  "median": 15.25,                       
  "minimum": -15,
  "mode": 16,
  "standardDev": 9.6562
}
```

After enough data has been recorded, Zephyrus can also detect and report
temperature anomalies using a built-in statistical model(more about that below).

For instance, two temperature spikes(high and low) of `+30°C` and `-15°C` will
be flagged as anomalous and included in
the statistical report(again, the data is made up):

```json
{                                                                                 
  "anomaly": [                                                                    
    {                                                                             
      "anomalyDate": "2025-04-06",                                                
      "anomalyTemp": 30                    
    },                
    {
      "anomalyDate": "2025-04-07",         
      "anomalyTemp": -15                   
    }                                    
  ],                                     
  "count": 12,
  "maximum": 30,
  "mean": 13.9167,                       
  "median": 15.25,                       
  "minimum": -15,
  "mode": 16,
  "standardDev": 9.6562
}  
```

### Anomaly Detection
The anomaly detection model is based on a modified version
of the [Z-Score](https://en.wikipedia.org/wiki/Standard_score) algorithm
that uses the [Median Absolute Deviation](https://en.wikipedia.org/wiki/Median_absolute_deviation) to measure variability in a given sample of quantitative
data. The entire procedure can be summarized as follows(let $X$ be the dataset):

Compute the median

$$
    \tilde{x} = \text{median}({X})
$$

Compute The median absolute deviation

$$
  \text{MAD} = \text{median}\{ |x_i - \tilde{x}| : \forall i = 0, \dots, n-1 \}
$$

Compute the (modified)Z-score

$$
  z_i = \frac{0.6745 (x_i - \tilde{x})}{\text{MAD}}
  \quad \forall i = 0, \dots, n-1
$$

Flag $x_i$ as an outlier if $|z_i| > 3.5$

Here, $\Phi^{-1}(3/4) = \Phi^{-1}(0.75) \approx 0.6745$ reflects the fact
that 75% of values lie within $\approx 0.6745$ standard deviation and 3.5 represent a fixed
threshold value.

> [!IMPORTANT]
> The anomaly detection system works under the assumption that the weather
> data is normally distributed(at least roughly), this might not always be the case
> on datasets sampled over a short time window. For accurate result, collect at least
> two weeks of weather data.

The in-memory statistics database is updated each time the `/weather/:city` route
is consumed and is reset at each restart. At the time being, there is no plan
to make data gathering non-volatile.

## Embedded Cache System
In order to minimize the amount of calls made to the OpenWeatherMap servers, Zephyrus
provides a built-in, in-memory cache data structure to store fetched weather data.
Each time a client requests any kind of weather data of a given location, Zephyrus
tries to search it first on the cache system; if it is found, the cached value is returned
otherwise a new API call is made and the retrieved values is added to the cache before
being returned to the client. The expiration date, expressed in hours, is controlled via
the `ZEPHYRUS_CACHE_TTL` environment variable. Once a cached value expires, Zephyrus retrieves
fresh data from OpenWeatherMap servers.

The caching system significantly improves Zephyrus performance by decreasing latency. Additionally,
it helps minimize the number of API calls made to OpenWeatherMap' servers, an important factor
if you are using the OpenWeatherMap free tier.

## Configuration
Before deploying the service, you need to configure the following environment variables.

| Variable             | Meaning                                |
|----------------------|----------------------------------------|
| `ZEPHYRUS_PORT`      | Listen port                            |
| `ZEPHYRUS_TOKEN`     | OpenWeatherMap API key                 |
| `ZEPHYRUS_CACHE_TTL` | Cache time-to-live(expressed in hours) |

Each value must be set _before_ launching the application. If you plan to deploy Zephyrus
using Docker, you can specify these environment variables by editing the `compose.yml` file.

You will also need an OpenWeatherMap API key, you can get one for free by following
the instructions [listed on their website](https://openweathermap.org/api).

> [!NOTE]
> Zephyrus is designed to work with OpenWeatherMap's free tier. 
> As long as you stay within the daily limit of 1,000 calls, you won’t need to pay.


## Deploy
The easiest way to deploy Zephyrus is by using Docker. In order to launch it, issue the following
command:

```sh
$ docker compose up -d
```

This will build the container image and then launch it. By default the service will be available
at `127.0.0.1:3000` but you can easily change this property by editing the associated environment
variable(see section above).

## Unit tests
The `test/` directory includes unit tests for the statistics module. These tests are executed 
during the container build process, but you can also run them manually by issuing the following command:

```sh
$ cabal test
```

## License
This software is released under the GPLv3 license. You can find a copy of the license with this repository or by visiting the [following page](https://choosealicense.com/licenses/gpl-3.0/).
