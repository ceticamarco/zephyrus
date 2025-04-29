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
data City = City 
    { name :: Text
    , lat :: Double
    , lon :: Double
    } deriving (Show, Eq, Generic)

-- The weather data type, representing the weather
data Weather = Weather 
    { date :: Day
    , temperature :: Text
    , condition :: Text
    , feelsLike :: Text
    , condEmoji :: Text
    } deriving (Show, Eq, Generic)
instance ToJSON Weather where
    toJSON (Weather dt temp cond fl emoji) =
        object [ "date" .= pack (formatTime defaultTimeLocale "%a, %d/%m/%Y" dt)
               , "temperature" .= temp
               , "condition" .= cond
               , "feelsLike" .= fl
               , "condEmoji" .= emoji
               ]
instance FromJSON Weather

-- The metrics data type, representing the humidity, pressure and dew point
data Metrics = Metrics 
    { humidity :: Text
    , pressure :: Text
    , dewPoint :: Text
    , uvIndex :: Int
    , visibility :: Text
    } deriving (Show, Eq, Generic)
instance ToJSON Metrics
instance FromJSON Metrics

-- The wind data type, representing the wind speed, the wind direction and the direction icon
data Wind = Wind 
    { speed :: Text
    , gust :: Text
    , direction :: Text
    , arrow :: Text
    } deriving (Show, Eq, Generic)
instance ToJSON Wind
instance FromJSON Wind

-- The forecast data type of the next 5 days
data ForecastElement = ForecastElement
    { fcDate :: Day
    , fcMin :: Text
    , fcMax :: Text
    , fcCond :: Text
    , fcEmoji :: Text
    , fcFL :: Text
    , fcWindSpeed :: Text
    , fcWindGust :: Text
    , fcWindDir :: Text
    , fcWindArrow :: Text
    } deriving (Show, Eq, Generic)
instance ToJSON ForecastElement where
    toJSON (ForecastElement dt tempMin tempMax cond emoji fl wSpeed wGust wDir wArr) =
        object [ "date" .= dt
               , "temperatureMin" .= tempMin
               , "temperatureMax" .= tempMax
               , "condition" .= cond
               , "condEmoji" .= emoji
               , "feelsLike" .= fl
               , "windSpeed" .= wSpeed
               , "windGust" .= wGust
               , "windDirection" .= wDir
               , "windArrow" .= wArr
               ]
instance FromJSON ForecastElement

newtype Forecast = Forecast { forecast :: [ForecastElement] }
    deriving (Show, Eq, Generic)
instance ToJSON Forecast
instance FromJSON Forecast

-- The moon data type, representing the moon phase
data Moon = Moon 
    { moonEmoji :: Text
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

data WeatherAnomaly = WeatherAnomaly
    { anomalyDate :: Day
    , anomalyTemp :: Double
    } deriving (Show, Eq, Generic)
instance ToJSON WeatherAnomaly
instance FromJSON WeatherAnomaly

data StatResult = StatResult
    { min :: Double
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
data State = State
    { zCache :: TVar ZCache
    , statDB :: TVar StatDB
    }

-- The Reader monad for the state
type AppM = ReaderT State Handler