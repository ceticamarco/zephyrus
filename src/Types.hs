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
data Weather = Weather { fahrenheitTemp :: Double
                       , celsiusTemp :: Double
                       , emoji :: Text
                       } deriving (Show, Eq, Generic)
instance ToJSON Weather
instance FromJSON Weather

-- The weather cache data type, representing a mapping between a city and its weather
type WCache = Map Text (Weather, UTCTime)

-- The state of the weather cache between multiple requests
newtype State = State { cache :: TVar WCache}

-- The Reader monad for the state
type AppM = ReaderT State Handler