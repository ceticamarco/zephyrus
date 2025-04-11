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
import Data.Text (Text, pack, unpack)
import Text.Printf (printf)
import Data.Maybe (fromMaybe)
import Servant (throwError)
import Text.Read (readMaybe)

import Model (getCityCoords, getCityWeather, getCityMetrics, getCityWind, getCityForecast, getMoon, getCityStatistics)
import Statistics (insertStatistic)
import Types (AppM, State(..), Weather(..), ZCache, StatDB, CacheElement(..), Metrics(..), Wind(..), Forecast(..), Moon(..), StatResult(..), City)
import Error (jsonError)

isCacheExpired :: UTCTime -> Int -> UTCTime -> Bool
isCacheExpired currentTime ttl timestamp =
    diffUTCTime currentTime timestamp > fromIntegral (ttl * 3600)

handleCityResult :: Either Text City -> AppM City
handleCityResult (Left err) = throwError $ jsonError 404 err
handleCityResult (Right city) = pure city

handleResult :: Either Text a -> AppM a
handleResult (Left err) = throwError $ jsonError 500 err
handleResult (Right result) = pure result

fmtTemperature :: Text -> Bool -> Text
fmtTemperature temp isCelsius =
    if isCelsius
        then pack (unpack temp) <> "°C"
        else pack (unpack temp) <> "°F"

fmtWindSpeed :: Text -> Bool -> Text
fmtWindSpeed speed isMetric =
    if isMetric
        then pack (unpack speed) <> " km/h"
        else pack (unpack speed) <> " mph"

fmtHumidity :: Text -> Text
fmtHumidity val = pack $ printf "%s%%" val

fmtPressure :: Text -> Text
fmtPressure val = pack $ printf "%s hPa" val

fmtVisibility :: Text -> Text
fmtVisibility val = pack $ printf "%skm" val

getWeather :: Text -> AppM Weather
getWeather city = do
    -- Read from cache
    State{zCache = tCache} <- ask
    State{statDB = tDB} <- ask
    weatherCache <- liftIO $ readTVarIO tCache

    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (city <> "_weather") weatherCache of
        Just (WeatherCache weather, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- Format temperature
                let fmtWeather = weather { fahrenheitTemp = fmtTemperature (fahrenheitTemp weather) False
                                         , celsiusTemp = fmtTemperature (celsiusTemp weather) True
                                         }
                pure fmtWeather
        _ -> fetchWeather city tCache tDB
    where
        fetchWeather :: Text -> TVar ZCache -> TVar StatDB -> AppM Weather
        fetchWeather city' cache' db = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCityResult coordRes

            -- Get Weather
            weatherRes <- liftIO $ getCityWeather coords apiKey
            weather <- handleResult weatherRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (city' <> "_weather")
                    (WeatherCache weather, currTime))

            -- Insert statistics into the statistics database
            insertStatistic db city' weather

            -- Format temperature
            let fmtWeather = weather { fahrenheitTemp = fmtTemperature (fahrenheitTemp weather) False
                                     , celsiusTemp = fmtTemperature (celsiusTemp weather) True
                                     }
            -- Return the weather
            pure fmtWeather

getMetrics :: Text -> AppM Metrics
getMetrics city = do
    -- Read from cache
    State{zCache = tCache} <- ask
    metricsCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (city <> "_metrics") metricsCache of
        Just (MetricsCache metrics, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- Format metrics
                let fmtMetrics = metrics { humidity = fmtHumidity (humidity metrics)
                                         , pressure = fmtPressure (pressure metrics) 
                                         , celsiusDewPoint = fmtTemperature (celsiusDewPoint metrics) True
                                         , fahrenheitDewPoint = fmtTemperature (fahrenheitDewPoint metrics) False
                                         -- UV index left unchanged
                                         , visibility = fmtVisibility (visibility metrics)
                                         }
                pure fmtMetrics
        _ -> fetchMetrics city tCache
    where
        fetchMetrics :: Text -> TVar ZCache -> AppM Metrics
        fetchMetrics city' cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCityResult coordRes

            -- Get Metrics
            metricsRes <- liftIO $ getCityMetrics coords apiKey
            metrics <- handleResult metricsRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (city' <> "_metrics")
                    (MetricsCache metrics, currTime))

            -- Format metrics
            let fmtMetrics = metrics { humidity = fmtHumidity (humidity metrics)
                                     , pressure = fmtPressure (pressure metrics) 
                                     , celsiusDewPoint = fmtTemperature (celsiusDewPoint metrics) True
                                     , fahrenheitDewPoint = fmtTemperature (fahrenheitDewPoint metrics) False 
                                     -- UV index left unchanged
                                     , visibility = fmtVisibility (visibility metrics)
                                     }
            pure fmtMetrics

getWind :: Text -> AppM Wind
getWind city = do
    -- Read from cache
    State{zCache = tCache} <- ask
    windCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (city <> "_wind") windCache of
        Just (WindCache wind, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- format wind
                let fmtWind = wind { metricSpeed = fmtWindSpeed (metricSpeed wind) True
                                   , imperialSpeed = fmtWindSpeed (imperialSpeed wind) False
                                   }
                pure fmtWind
        _ -> fetchWind city tCache
    where
        fetchWind :: Text -> TVar ZCache -> AppM Wind
        fetchWind city' cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCityResult coordRes

            -- Get Wind
            windRes <- liftIO $ getCityWind coords apiKey
            wind <- handleResult windRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (city' <> "_wind")
                    (WindCache wind, currTime))

            -- format wind
            let fmtWind = wind { metricSpeed = fmtWindSpeed (metricSpeed wind) True
                               , imperialSpeed = fmtWindSpeed (imperialSpeed wind) False
                               }
            pure fmtWind

getForecast :: Text -> AppM Forecast
getForecast city = do
    -- Read from cache
    State{zCache = tCache} <- ask
    forecastCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (city <> "_forecast") forecastCache of
        Just (ForecastCache fc, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- Format forecast
                let fmtForecast = fc { forecast = map (\weather -> 
                    weather { fahrenheitTemp = fmtTemperature (fahrenheitTemp weather) False
                            , celsiusTemp = fmtTemperature (celsiusTemp weather) True}
                            ) (forecast fc) }
                pure fmtForecast
        _ -> fetchForecast city tCache
    where
        fetchForecast :: Text -> TVar ZCache -> AppM Forecast
        fetchForecast city' cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city' apiKey
            coords <- handleCityResult coordRes

            -- Get Forecast
            forecastRes <- liftIO $ getCityForecast coords apiKey
            fc <- handleResult forecastRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (city' <> "_forecast")
                    (ForecastCache fc, currTime))

            -- Format forecast
            let fmtForecast = fc { forecast = map (\weather ->
                    weather { fahrenheitTemp = fmtTemperature (fahrenheitTemp weather) False
                            , celsiusTemp = fmtTemperature (celsiusTemp weather) True}
                            ) (forecast fc) }

            pure fmtForecast
            
getMoonPhase :: AppM Moon
getMoonPhase = do
    -- Read from cache
    State{zCache = tCache} <- ask
    moonCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYRUS_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup "default_moonphase" moonCache of
        Just (MoonCache moon, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> pure moon
        _ -> fetchMoonPhase tCache
    where
        fetchMoonPhase :: TVar ZCache -> AppM Moon
        fetchMoonPhase cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYRUS_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Moon Phase
            moonPhaseRes <- liftIO $ getMoon apiKey
            moon <- handleResult moonPhaseRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    "default_moonphase"
                    (MoonCache moon, currTime))
            pure moon

getStatistics :: Text -> AppM StatResult
getStatistics city = do
    -- Read from cache
    State{statDB = tDB} <- ask
    db <- liftIO $ readTVarIO tDB

    -- Get city statistics
    cityStatsRes <- liftIO $ getCityStatistics city db
    
    handleResult cityStatsRes