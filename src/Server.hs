{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Server where

import Data.Text (Text)
import Servant ( Proxy(..), Capture, JSON, type (:>), (:<|>)(..), Get, HasServer(ServerT) )
import Controller (getWeather, getEnvMetrics)

import Types (Weather(..), AppM, EnvMetrics(..))

-- Servant API definition
type WeatherAPI =
    "weather" :> Capture "city" Text :> Get '[JSON] Weather :<|> -- GET /weather/:city
    "metrics" :> Capture "city" Text :> Get '[JSON] EnvMetrics   -- GET /metrics/:city

api :: Proxy WeatherAPI
api = Proxy

server ::  ServerT WeatherAPI AppM
server = getWeather :<|> getEnvMetrics