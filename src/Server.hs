{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Server where

import Data.Text (Text)
import Servant ( Proxy(..), Capture, JSON, type (:>), Get, HasServer(ServerT) )
import Controller (getWeather)

import Types (Weather(..), AppM)

-- Servant API definition
type WeatherAPI =
    "zephyrus" :> Capture "city" Text :> Get '[JSON] Weather -- GET /zephyrus/:city

api :: Proxy WeatherAPI
api = Proxy

server ::  ServerT WeatherAPI AppM
server = getWeather