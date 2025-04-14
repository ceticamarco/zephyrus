{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Types where

import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON(..), (.=), object)
import Data.Time.Clock (UTCTime)
import Data.Time (formatTime, defaultTimeLocale)
import Data.Time.Calendar(Day)
import Control.Concurrent.STM.TVar (TVar)
import Control.Monad.Trans.Reader (ReaderT)
import Data.Map (Map)
import Data.Text (Text, pack)
import Servant ( Handler )

-- The City data type, representing the name, the latitude and the longitude of a location
data City = City { name :: Text
                 , lat :: Double
                 , lon :: Double
                 } deriving (Show, Eq, Generic)

-- The weather data type, representing the weather
data Weather = Weather { date :: Day
                       , fahrenheitTemp :: Text
                       , celsiusTemp :: Text
                       , condition :: Text
                       , condEmoji :: Text
                       } deriving (Show, Eq, Generic)
instance ToJSON Weather where
    toJSON (Weather dt fTemp cTemp cond emoji) =
        object [ "date" .= pack (formatTime defaultTimeLocale "%a, %d/%m/%Y" dt)
               , "fahrenheitTemp" .= fTemp
               , "celsiusTemp" .= cTemp
               , "condition" .= cond
               , "condEmoji" .= emoji
               ]
instance FromJSON Weather

-- The metrics data type, representing the humidity, pressure and dew point
data Metrics = Metrics { humidity :: Text
                       , pressure :: Text
                       , celsiusDewPoint :: Text
                       , fahrenheitDewPoint :: Text
                       , uvIndex :: Int
                       , visibility :: Text
                       } deriving (Show, Eq, Generic)
instance ToJSON Metrics
instance FromJSON Metrics

-- The wind data type, representing the wind speed, the wind direction and the direction icon
data Wind = Wind { metricSpeed :: Text
                 , imperialSpeed :: Text
                 , direction :: Text
                 , arrow :: Text
                 } deriving (Show, Eq, Generic)
instance ToJSON Wind
instance FromJSON Wind

-- The forecast data type, representing the weather forecast of the next 5 days
newtype Forecast = Forecast { forecast :: [Weather] }
              deriving (Show, Eq, Generic)
instance ToJSON Forecast
instance FromJSON Forecast

-- The moon data type, representing the moon phase
data Moon = Moon { moonEmoji :: Text
                 , moonPhase :: Text
                 , moonProgress :: Text
                 } deriving (Show, Eq, Generic)
instance ToJSON Moon where
    toJSON (Moon emoji phase progress) =
        object [ "icon" .= emoji
               , "phase" .= phase
               , "percentage" .= progress
               ]
instance FromJSON Moon

-- Sum type representing the possible values of the cache
data CacheElement = WeatherCache Weather
                  | MetricsCache Metrics
                  | WindCache Wind
                  | ForecastCache Forecast
                  | MoonCache Moon
                  deriving (Show, Eq)

-- The statistical database, representing a mapping between "$city" and its weather
type StatDB = Map Text Weather

data WeatherAnomaly = WeatherAnomaly { anomalyDate :: Day
                                     , anomalyTemp :: Double
                                     } deriving (Show, Eq, Generic)
instance ToJSON WeatherAnomaly
instance FromJSON WeatherAnomaly

data StatResult = StatResult { min :: Double
                             , max :: Double
                             , count :: Int
                             , mean :: Double
                             , stdDev :: Double
                             , median :: Double
                             , mode :: Double
                             , anomaly :: Maybe [WeatherAnomaly]
                             } deriving (Show, Eq, Generic)
instance ToJSON StatResult where
    toJSON (StatResult mnm mxm cnt mn standDev med md an) =
        object [ "minimum" .= mnm
               , "maximum" .= mxm
               , "count" .= cnt
               , "mean" .= mn
               , "standardDev" .= standDev
               , "median" .= med
               , "mode" .= md
               , "anomaly" .= an
               ]
instance FromJSON StatResult

-- The cache data type, representing a mapping between a city and its weather
type ZCache = Map Text (CacheElement, UTCTime)

-- The state of the weather cache between multiple requests
data State = State { zCache :: TVar ZCache
                   , statDB :: TVar StatDB
                   }

-- The Reader monad for the state
type AppM = ReaderT State Handler