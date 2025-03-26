{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Controller where

import Data.Time.Clock (UTCTime, getCurrentTime, diffUTCTime)
import GHC.Conc (atomically)
import Control.Concurrent.STM.TVar (TVar, readTVarIO, modifyTVar')
import Control.Monad.Trans.Reader (ask)
import Control.Monad.IO.Class (liftIO)
import qualified Data.Map as Map
import System.Environment (lookupEnv)
import Data.Text (Text, pack)
import Data.Maybe (fromMaybe)
import Servant (throwError)
import Text.Read (readMaybe)

import Model (getCityCoords, getCityWeather)
import Types (AppM, State(..), Weather(..), WCache)
import Error (jsonError)

getWeather :: Text -> AppM Weather
getWeather city = do
    -- Read from cache
    State{cache = tCache} <- ask
    weatherCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (city <> "_weather") weatherCache of
        Just (weather, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> pure weather
        _ -> fetchWeather city tCache
    where
        fetchWeather :: Text -> TVar WCache -> AppM Weather
        fetchWeather city' cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCoordsResult coordRes
            weatherRes <- liftIO $ getCityWeather coords apiKey
            weather <- handleWeatherResult weatherRes
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache' (Map.insert (city' <> "_weather") (weather, currTime))
            pure weather

        handleCoordsResult :: Either Text (Double, Double) -> AppM (Double, Double)
        handleCoordsResult (Left err) = throwError $ jsonError 404 err
        handleCoordsResult (Right coords) = pure coords

        handleWeatherResult :: Either Text Weather -> AppM Weather
        handleWeatherResult (Left err) = throwError $ jsonError 500 err
        handleWeatherResult (Right weather) = pure weather

        isCacheExpired :: UTCTime -> Int -> UTCTime -> Bool
        isCacheExpired currentTime ttl timestamp =
            diffUTCTime currentTime timestamp > fromIntegral (ttl * 3600)