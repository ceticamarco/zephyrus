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

import Model (getCityCoords, getCityWeather, getCityMetrics, getCityWind)
import Types (AppM, State(..), Weather(..), ZCache, CacheElement(..), Metrics(..), Wind(..), Coordinates)
import Error (jsonError)

isCacheExpired :: UTCTime -> Int -> UTCTime -> Bool
isCacheExpired currentTime ttl timestamp =
    diffUTCTime currentTime timestamp > fromIntegral (ttl * 3600)

handleCoordsResult :: Either Text Coordinates -> AppM Coordinates
handleCoordsResult (Left err) = throwError $ jsonError 404 err
handleCoordsResult (Right coords) = pure coords

handleResult :: Either Text a -> AppM a
handleResult (Left err) = throwError $ jsonError 500 err
handleResult (Right result) = pure result

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
        Just (CacheWeather weather, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> pure weather
        _ -> fetchWeather city tCache
    where
        fetchWeather :: Text -> TVar ZCache -> AppM Weather
        fetchWeather city' cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCoordsResult coordRes
            weatherRes <- liftIO $ getCityWeather coords apiKey
            weather <- handleResult weatherRes
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (city' <> "_weather")
                    (CacheWeather weather, currTime))
            pure weather

getMetrics :: Text -> AppM Metrics
getMetrics city = do
    -- Read from cache
    State{cache = tCache} <- ask
    metricsCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (city <> "_metrics") metricsCache of
        Just (CacheMetrics metrics, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> pure metrics
        _ -> fetchMetrics city tCache
    where
        fetchMetrics :: Text -> TVar ZCache -> AppM Metrics
        fetchMetrics city' cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCoordsResult coordRes
            metricsRes <- liftIO $ getCityMetrics coords apiKey
            metrics <- handleResult metricsRes
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (city' <> "_metrics")
                    (CacheMetrics metrics, currTime))
            pure metrics

getWind :: Text -> AppM Wind
getWind city = do
    -- Read from cache
    State{cache = tCache} <- ask
    windCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (city <> "_wind") windCache of
        Just (CacheWind wind, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> pure wind
        _ -> fetchWind city tCache
    where
        fetchWind :: Text -> TVar ZCache -> AppM Wind
        fetchWind city' cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCoordsResult coordRes
            windRes <- liftIO $ getCityWind coords apiKey
            wind <- handleResult windRes
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (city' <> "_wind")
                    (CacheWind wind, currTime))
            pure wind