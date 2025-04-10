{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Server where

import Data.Text (Text)
import Servant ( Proxy(..), Capture, JSON, type (:>), (:<|>)(..), Get, HasServer(ServerT) )
import Controller (getWeather, getMetrics, getWind, getForecast, getMoonPhase, getStatistics)

import Types (Weather(..), Metrics(..), Wind(..), Forecast(..), Moon(..), StatResult(..), AppM)

-- Servant API definition
type WeatherAPI =
    "weather"  :> Capture "city" Text :> Get '[JSON] Weather   :<|> -- GET /weather/:city
    "metrics"  :> Capture "city" Text :> Get '[JSON] Metrics   :<|> -- GET /metrics/:city
    "wind"     :> Capture "city" Text :> Get '[JSON] Wind      :<|> -- GET /wind/:city
    "forecast" :> Capture "city" Text :> Get '[JSON] Forecast  :<|> -- GET /forecast/:city
    "moon"     :>                        Get '[JSON] Moon      :<|> -- GET /moon
    "stats"    :> Capture "city" Text :> Get '[JSON] StatResult     -- GET /stats/:city

api :: Proxy WeatherAPI
api = Proxy

server :: ServerT WeatherAPI AppM
server = getWeather   :<|>
         getMetrics   :<|>
         getWind      :<|>
         getForecast  :<|>
         getMoonPhase :<|>
         getStatistics