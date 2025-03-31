<div align="center">
<h1>Zephyrus 🌲</h1>
    
<h6><i>HTTP weather forecast service</i></h6>

[![](https://github.com/ceticamarco/zephyrus/actions/workflows/docker.yml/badge.svg)](https://github.com/ceticamarco/zephyrus/actions/workflows/docker.yml)
[![](https://github.com/ceticamarco/zephyrus/actions/workflows/linter.yml/badge.svg)](https://github.com/ceticamarco/zephyrus/actions/workflows/linter.yml)

</div>

**Zephyrus** is a lightweight HTTP weather service designed to provide a simple way to
gather meteorological data. It's written in Haskell using [Servant](https://www.servant.dev/)
and [OpenWeatherMap](https://home.openweathermap.org).

I've built this service out of frustration with existing
weather platforms cluttered with ads, paywalls, clickbait contents and unnecessary features.
Zephyrus only gets you the essential information about the meteorological conditions of a given location without any additional nonsense. 

This service communicates through a JSON API, making
it suitable for use in any kind of project or device. I already use it on my phone,
on my terminal, on the tmux's status bar and on a couple of smart bedside alarm clocks I've built.

## Usage
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
  "celsiusTemp": "+21°C",
  "condEmoji": "☀️",
  "condition": "Clear",
  "date": "2025-03-31",
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
  "celsiusDewPoint": "+13°C",
  "fahrenheitDewPoint": "+55°F",
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
$  curl -s 'http://127.0.0.1:3000/forecast/paris' | jq
```

will yield

```json
{
  "forecast": [
    {
      "celsiusTemp": "+13°C",
      "condEmoji": "☀️",
      "condition": "Clear",
      "date": "2025-03-31",
      "fahrenheitTemp": "+55°F"
    },
    {
      "celsiusTemp": "+13°C",
      "condEmoji": "☀️",
      "condition": "Clear",
      "date": "2025-04-01",
      "fahrenheitTemp": "+55°F"
    },
    // ...
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
  "moonEmoji": "🌒",
  "moonPhase": "Waxing Crescent"
}
```

## Embedded Cache System
In order to minimize the amount of calls made to the OpenWeatherMap servers, Zephyrus
provides a built-in, in-memory cache data structure to store fetched meteorological data. 
Each time a client requests any kind of meteorological data of a given location, Zephyrus
tries to search it first on the cache system; if it is found, the cached value is returned
otherwise a new API call is made and the retrieved values is added to the cache before
being returned to the client. The expiration date, expressed in hours, is controlled via
the `ZEPHYRUS_CACHE_TTL` environment variable. Once a cached value expires, Zephyrus retrieves
fresh data from OpenWeatherMap servers.

This caching system significantly improves Zephyrus performance by decreasing latency. Additionally,
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


## License
This software is released under the GPLv3 license. You can find a copy of the license with this repository or by visiting the [following page](https://choosealicense.com/licenses/gpl-3.0/).