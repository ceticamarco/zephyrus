{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DeriveGeneric #-}

module Server where

import Data.Text (Text)
import Servant ( Proxy(..), Capture, JSON, QueryFlag, type (:>), (:-), Get, NamedRoutes )
import Controller (getWeather, getMetrics, getWind, getForecast, getMoonPhase, getStatistics)
import Servant.API.Generic ( Generic )

import Types (Weather(..), Metrics(..), Wind(..), Forecast(..), Moon(..), StatResult(..), AppM)
import Servant.Server.Generic (AsServerT)

-- Servant API definition
type API = NamedRoutes WeatherAPI

data WeatherAPI mode = WeatherAPI
    { weather :: mode
        :- "weather"
        :> Capture "city" Text       -- Capture the city parameter
        :> QueryFlag "i"             -- Capture the imperial flag for conversion
        :> Get '[JSON] Weather       -- GET /weather/:city

    , metrics :: mode
        :- "metrics"
        :> Capture "city" Text       -- Capture the city parameter
        :> QueryFlag "i"             -- Capture the imperial flag for conversion
        :> Get '[JSON] Metrics       -- GET /metrics/:city

    , wind :: mode
        :- "wind"
        :> Capture "city" Text       -- Capture the city parameter
        :> QueryFlag "i"             -- Capture the imperial flag for conversion
        :> Get '[JSON] Wind          -- GET /wind/:city

    , fc :: mode
        :- "forecast"
        :> Capture "city" Text       -- Capture the city parameter
        :> QueryFlag "i"             -- Capture the imperial flag for conversion
        :> Get '[JSON] Forecast      -- GET /forecast/:city

    , moon :: mode
        :- "moon"
        :> Get '[JSON] Moon          -- GET /moon

    , stats :: mode
        :- "stats"
        :> Capture "city" Text       -- Capture the city parameter
        :> Get '[JSON] StatResult    -- GET /stats/:city
    } deriving (Generic)

api :: Proxy (NamedRoutes WeatherAPI)
api = Proxy

server :: WeatherAPI (AsServerT AppM)
server = WeatherAPI
    { weather = getWeather
    , metrics = getMetrics
    , wind = getWind
    , fc = getForecast
    , moon = getMoonPhase
    , stats = getStatistics
    }