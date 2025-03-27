{-# LANGUAGE DeriveGeneric #-}

module Types where

import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)
import Data.Time.Clock (UTCTime)
import Control.Concurrent.STM.TVar (TVar)
import Control.Monad.Trans.Reader (ReaderT)
import Data.Map (Map)
import Data.Text (Text)
import Servant ( Handler )

-- The weather data type, representing the weather
data Weather = Weather { fahrenheitTemp :: Text
                       , celsiusTemp :: Text
                       , condition :: Text
                       , emoji :: Text
                       } deriving (Show, Eq, Generic)
instance ToJSON Weather
instance FromJSON Weather

-- The environmental metrics data type, representing the humidity, pressure and dew point
data EnvMetrics = EnvMetrics { humidity :: Text
                           , pressure :: Text
                           , celsiusDewPoint :: Text
                           , fahrenheitDewPoint :: Text
                           } deriving (Show, Eq, Generic)
instance ToJSON EnvMetrics
instance FromJSON EnvMetrics

-- Sum type representing the possible values of the cache
data CacheElement = CacheWeather Weather
                  | CacheEnvMetrics EnvMetrics
                  deriving (Show, Eq)

-- The cache data type, representing a mapping between a city and its weather
type ZCache = Map Text (CacheElement, UTCTime)

-- The state of the weather cache between multiple requests
newtype State = State { cache :: TVar ZCache}

-- The Reader monad for the state
type AppM = ReaderT State Handler