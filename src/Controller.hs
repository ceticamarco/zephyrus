{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Controller where

import Data.Time.Clock (UTCTime, getCurrentTime, diffUTCTime)
import GHC.Conc (atomically)
import Control.Concurrent.STM.TVar (TVar, readTVarIO, modifyTVar')
import Control.Monad.Trans.Reader (ask)
import Control.Monad.IO.Class (liftIO)
import qualified Data.Map as Map
import qualified Data.Text as T
import System.Environment (lookupEnv)
import Data.Text (Text, pack, unpack, toUpper)
import Text.Printf (printf)
import Data.Maybe (fromMaybe)
import Servant (throwError)
import Text.Read (readMaybe)

import Model
    ( getCityCoords,
      getCityWeather,
      getCityMetrics,
      getCityWind,
      getCityForecast,
      getMoon,
      getCityStatistics )
import Statistics (insertStatistic)
import Types
    ( AppM,
      State(State, statDB, zCache),
      ZCache,
      StatResult,
      StatDB,
      CacheElement(MoonCache, WeatherCache, MetricsCache, WindCache,
                   ForecastCache),
      Moon,
      Forecast(forecast),
      ForecastElement(fcMin, fcMax, fcFL, fcWindSpeed),
      Wind(speed),
      Metrics(visibility, humidity, pressure, dewPoint),
      Weather(feelsLike, temperature),
      City )
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
fmtTemperature temp isImperial =
    let parsedTemp = read (unpack temp) :: Double
    in if isImperial
        then pack (printf "%d" (((round parsedTemp :: Int) * 9 `div` 5) + 32)) <> "°F"
        else pack (printf "%d" (round parsedTemp :: Int)) <> "°C"

fmtWindSpeed :: Text -> Bool -> Text
fmtWindSpeed windSpeed isImperial =
    -- Convert wind speed to mph or km/s from m/s
    -- 1 m/s = 2.23694 mph
    -- 1 m/s = 3.6 km/h
    let parsedSpeed = read (unpack windSpeed) :: Double
    in if isImperial
        then pack (printf "%.1f" (parsedSpeed * 2.23694)) <> " mph"
        else pack (printf "%.1f" (parsedSpeed * 3.6)) <> " km/h"

fmtHumidity :: Text -> Text
fmtHumidity val = pack $ printf "%s%%" val

fmtPressure :: Text -> Text
fmtPressure val = pack $ printf "%s hPa" val

fmtVisibility :: Text -> Text
fmtVisibility val = pack $ printf "%skm" val

-- | Format cache key by replacing whitespace with '+'
--   and converting it to uppercase
fmtCacheKey :: Text -> Text
fmtCacheKey key =
    let spaceTrimmedKey = T.map (\c -> if c == ' ' then '+' else c) key
    in toUpper spaceTrimmedKey

getWeather :: Text -> Bool -> AppM Weather
getWeather city isImperial = do
    -- Read from cache
    State{zCache = tCache} <- ask
    State{statDB = tDB} <- ask
    weatherCache <- liftIO $ readTVarIO tCache

    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYR_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (fmtCacheKey city <> "_weather") weatherCache of
        Just (WeatherCache weather, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- Format temperature
                let fmtWeather = weather { temperature = fmtTemperature (temperature weather) isImperial
                                         , feelsLike = fmtTemperature (feelsLike weather) isImperial
                                         }
                pure fmtWeather
        _ -> fetchWeather tCache tDB
    where
        fetchWeather :: TVar ZCache -> TVar StatDB -> AppM Weather
        fetchWeather cache' db = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYR_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city apiKey
            coords <- handleCityResult coordRes

            -- Get Weather
            weatherRes <- liftIO $ getCityWeather coords apiKey
            weather <- handleResult weatherRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (fmtCacheKey city <> "_weather")
                    (WeatherCache weather, currTime))

            -- Insert statistics into the statistics database
            insertStatistic db (fmtCacheKey city) weather

            -- Format temperature
            let fmtWeather = weather { temperature = fmtTemperature (temperature weather) isImperial
                                     , feelsLike = fmtTemperature (feelsLike weather) isImperial 
                                     }
            -- Return the weather
            pure fmtWeather

getMetrics :: Text -> Bool -> AppM Metrics
getMetrics city isImperial = do
    -- Read from cache
    State{zCache = tCache} <- ask
    metricsCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYR_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (fmtCacheKey city <> "_metrics") metricsCache of
        Just (MetricsCache metrics, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- Format metrics
                let fmtMetrics = metrics { humidity = fmtHumidity (humidity metrics)
                                         , pressure = fmtPressure (pressure metrics) 
                                         , dewPoint = fmtTemperature (dewPoint metrics) isImperial
                                         -- UV index left unchanged
                                         , visibility = fmtVisibility (visibility metrics)
                                         }
                pure fmtMetrics
        _ -> fetchMetrics tCache
    where
        fetchMetrics :: TVar ZCache -> AppM Metrics
        fetchMetrics cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYR_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city apiKey
            coords <- handleCityResult coordRes

            -- Get Metrics
            metricsRes <- liftIO $ getCityMetrics coords apiKey
            metrics <- handleResult metricsRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (fmtCacheKey city <> "_metrics")
                    (MetricsCache metrics, currTime))

            -- Format metrics
            let fmtMetrics = metrics { humidity = fmtHumidity (humidity metrics)
                                     , pressure = fmtPressure (pressure metrics) 
                                     , dewPoint = fmtTemperature (dewPoint metrics) isImperial
                                     -- UV index left unchanged
                                     , visibility = fmtVisibility (visibility metrics)
                                     }
            pure fmtMetrics

getWind :: Text -> Bool -> AppM Wind
getWind city isImperial = do
    -- Read from cache
    State{zCache = tCache} <- ask
    windCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYR_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (fmtCacheKey city <> "_wind") windCache of
        Just (WindCache wind, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- format wind
                let fmtWind = wind { speed = fmtWindSpeed (speed wind) isImperial }
                pure fmtWind
        _ -> fetchWind tCache
    where
        fetchWind :: TVar ZCache -> AppM Wind
        fetchWind cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYR_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city apiKey
            coords <- handleCityResult coordRes

            -- Get Wind
            windRes <- liftIO $ getCityWind coords apiKey
            wind <- handleResult windRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (fmtCacheKey city <> "_wind")
                    (WindCache wind, currTime))

            -- format wind
            let fmtWind = wind { speed = fmtWindSpeed (speed wind) isImperial }
            pure fmtWind

getForecast :: Text -> Bool -> AppM Forecast
getForecast city isImperial = do
    -- Read from cache
    State{zCache = tCache} <- ask
    forecastCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYR_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup (fmtCacheKey city <> "_forecast") forecastCache of
        Just (ForecastCache fc, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> do
                -- Format forecast
                let fmtForecast = fc { forecast = map (\fcElement ->
                        (fcElement { fcMin = fmtTemperature (fcMin fcElement) isImperial
                                   , fcMax = fmtTemperature (fcMax fcElement) isImperial
                                   , fcFL = fmtTemperature (fcFL fcElement) isImperial
                                   , fcWindSpeed = fmtWindSpeed (fcWindSpeed fcElement) isImperial})) (forecast fc) }
                pure fmtForecast
        _ -> fetchForecast tCache
    where
        fetchForecast :: TVar ZCache -> AppM Forecast
        fetchForecast cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYR_TOKEN"
            let apiKey = maybe "" pack apiKeyEnv :: Text

            -- Get Coordinates
            coordRes <- liftIO $ getCityCoords city apiKey
            coords <- handleCityResult coordRes

            -- Get Forecast
            forecastRes <- liftIO $ getCityForecast coords apiKey
            fc <- handleResult forecastRes

            -- Add result to the cache
            currTime <- liftIO getCurrentTime
            liftIO $ atomically $ modifyTVar' cache'
                (Map.insert
                    (fmtCacheKey city <> "_forecast")
                    (ForecastCache fc, currTime))

            -- Format forecast
            let fmtForecast = fc { forecast = map (\fcElement ->
                    (fcElement { fcMin = fmtTemperature (fcMin fcElement) isImperial
                               , fcMax = fmtTemperature (fcMax fcElement) isImperial
                               , fcFL = fmtTemperature (fcFL fcElement) isImperial
                               , fcWindSpeed = fmtWindSpeed (fcWindSpeed fcElement) isImperial})) (forecast fc) }
            pure fmtForecast
            
getMoonPhase :: AppM Moon
getMoonPhase = do
    -- Read from cache
    State{zCache = tCache} <- ask
    moonCache <- liftIO $ readTVarIO tCache
    currentTime <- liftIO getCurrentTime

    -- Read TTL value from environment variable
    ttlEnv <- liftIO $ lookupEnv "ZEPHYR_CACHE_TTL"
    let timeToLive = fromMaybe 3 (ttlEnv >>= readMaybe) :: Int

    case Map.lookup "default_moonphase" moonCache of
        Just (MoonCache moon, timestamp)
            | not (isCacheExpired currentTime timeToLive timestamp) -> pure moon
        _ -> fetchMoonPhase tCache
    where
        fetchMoonPhase :: TVar ZCache -> AppM Moon
        fetchMoonPhase cache' = do
            -- Read API key from environment variable
            apiKeyEnv <- liftIO $ lookupEnv "ZEPHYR_TOKEN"
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
    cityStatsRes <- liftIO $ getCityStatistics (fmtCacheKey city) db
    
    handleResult cityStatsRes