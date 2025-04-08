{-# LANGUAGE OverloadedStrings #-}

module Model where

import Data.Aeson (Value, withObject, withArray)
import Data.Aeson.Types (Value(..), (.:), parseEither, Parser)
import Data.Aeson.Key (fromText)
import qualified Data.Vector as V
import Data.Text (Text, pack, unpack, isSuffixOf)
import Text.Read (readMaybe)
import Data.Maybe (mapMaybe)
import Text.Printf (printf)
import Data.Scientific (toRealFloat)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Data.Time.Clock (utctDay)
import Data.Time (Day)
import Network.HTTP.Req ((/:), (=:), req, https, runReq, defaultHttpConfig, jsonResponse, responseBody)
import qualified Network.HTTP.Req as Req
import qualified Data.Map as Map

import Types (Weather(..), Metrics(..), Wind(..), Forecast(..), Moon(..), City(..), StatResult(..), WeatherAnomaly(..), StatDB)
import Statistics (isKeyInvalid, mean, stdDev, median, mode, detectAnomalies)

extractField :: Text -> [Value] -> Parser Text
extractField field (x:_) = withObject "weather[0]" (.: fromText field) x
extractField _ _ = fail "Weather array is empty"

getEmoji :: Text -> Bool -> Text
getEmoji condition' isNight =
    case condition' of
        "Thunderstorm" -> "⛈️"
        "Drizzle"      -> "🌦 "
        "Rain"         -> "🌧 "
        "Snow"         -> "☃️"
        "Mist"         -> "💭"
        "Smoke"        -> "💭"
        "Haze"         -> "💭"
        "Dust"         -> "💭"
        "Fog"          -> "💭"
        "Sand"         -> "💭"
        "Ash"          -> "💭"
        "Squall"       -> "💭"
        "Tornado"      -> "🌪 "
        "Clear"        -> if isNight then "🌙" else "☀️"
        "Clouds"       -> "☁️"
        _              -> "❓"

getCityCoords :: Text -> Text -> IO (Either Text City)
getCityCoords city appid = runReq defaultHttpConfig $ do
    -- Fetch city coordinates
    let reqUri = https "api.openweathermap.org" /: "geo" /: "1.0" /: "direct"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "q" =: city <>
        "limit" =: (5 :: Int) <>
        "appid" =: appid

    -- Parse JSON response
    let respBody = responseBody response :: Value
    case respBody of
        Array arr | V.null arr -> pure $ Left "Cannot find this city"
        Array arr -> do
            let root = V.head arr
            case parseEither parseCoords root of
                Right coords -> pure $ Right $ City
                    { name = city
                    , lat = fst coords
                    , lon = snd coords
                    }
                Left err -> pure $ Left $ "JSON parsing error: " <> pack err
        _ -> pure $ Left "Unexpected response format"
    where
        parseCoords :: Value -> Parser (Double, Double)
        parseCoords = withObject "root" $ \obj -> do
            latitude <- obj .: "lat"
            longitude <- obj .: "lon"
            pure (toRealFloat latitude, toRealFloat longitude)

getCityWeather :: City -> Text -> IO (Either Text Weather)
getCityWeather city appid = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: lat city <>
        "lon" =: lon city <>
        "appid" =: appid <>
        "units" =: ("metric" :: Text) <>
        "exclude" =: ("minutely,hourly,daily,alerts" :: Text)

    -- Parse JSON response
    let resBody = responseBody response :: Value
    case parseWeather resBody of
        Right weather -> pure $ Right weather
        Left err -> pure $ Left $ "Unable to parse API request: " <> pack err
    where
        parseWeather :: Value -> Either String Weather
        parseWeather = parseEither (withObject "root" $ \root -> do
            -- Extract keys from JSON response
            current <- root .: "current"
            weatherArray <- current .: "weather"
            conditionVal <- withArray "weather" (extractField "main" . V.toList) weatherArray
            temp <- current .: "temp"
            unixTs <- current .: "dt"
            icon <- withArray "weather" (extractField "icon" . V.toList) weatherArray

            -- Compute temperature in Celsius and Fahrenheit
            let celsiusVal = round (temp :: Double) :: Int
            let fahrenheitVal = (celsiusVal * 9 `div` 5) + 32

            -- Format UNIX timestamp as '<DAY_OF_THE_WEEK> dd/MM'
            let utcTime = posixSecondsToUTCTime (fromIntegral (unixTs :: Int))
            let weatherDate = utctDay utcTime

            -- Get emoji from weather condition
            let isNight = "n" `isSuffixOf` icon
            let emojiVal = getEmoji conditionVal isNight

            pure $ Weather
                { date = weatherDate
                , fahrenheitTemp = pack $ show fahrenheitVal
                , celsiusTemp = pack $ show celsiusVal
                , condition = conditionVal
                , condEmoji = emojiVal 
                })

getCityMetrics :: City -> Text -> IO (Either Text Metrics)
getCityMetrics city appid = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: lat city <>
        "lon" =: lon city <>
        "appid" =: appid <>
        "units" =: ("metric" :: Text) <>
        "exclude" =: ("minutely,hourly,daily,alerts" :: Text)

    -- Parse JSON response
    let resBody = responseBody response :: Value
    case parseMetrics resBody of
        Right metrics -> pure $ Right metrics
        Left err -> pure $ Left $ "Unable to parse API request: " <> pack err
    where
        parseMetrics :: Value -> Either String Metrics
        parseMetrics = parseEither (withObject "root" $ \root -> do
            -- Extract keys from JSON response
            current <- root .: "current"
            pressure' <- current .: "pressure"
            humidity' <- current .: "humidity"
            dewPoint <- current .: "dew_point"
            uvi <- current .: "uvi"
            vs <- current .: "visibility"

            -- Compute dew point in Celsius and Fahrenheit
            let celsiusDewPoint' = round (dewPoint :: Double) :: Int
            let fahrenheitDewPoint' = (celsiusDewPoint' * 9 `div` 5) + 32

            -- Build pressure string
            let pressureStr = pack $ printf "%s hPa" (show (pressure' :: Int))

            -- Build humidity string
            let humidityStr = pack $ printf "%s%%" (show (humidity' :: Int))

            -- Round UV index
            let uv = round (uvi :: Double) :: Int

            -- Build visibility string
            let visInKm = pack $ printf "%dkm" (round (vs / 1000 :: Double) :: Int)

            -- Build dew point strings in metric and imperial units
            let celsiusStr = pack $ printf "%s%s°C"
                    (if celsiusDewPoint' > 0 then "+" else "" :: String)
                    (show celsiusDewPoint')
            let fahrenheitStr = pack $ printf "%s%s°F"
                    (if fahrenheitDewPoint' > 0 then "+" else "" :: String)
                    (show fahrenheitDewPoint')

            pure $ Metrics humidityStr pressureStr celsiusStr fahrenheitStr uv visInKm)

getCityWind :: City -> Text -> IO (Either Text Wind)
getCityWind city apiKey = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: lat city <>
        "lon" =: lon city <>
        "appid" =: apiKey <>
        "units" =: ("metric" :: Text) <>
        "exclude" =: ("minutely,hourly,daily,alerts" :: Text)

    -- Parse JSON response
    let resBody = responseBody response :: Value
    case parseWind resBody of
        Right wind -> pure $ Right wind
        Left err -> pure $ Left $ "Unable to parse API request: " <> pack err
    where
        parseWind :: Value -> Either String Wind
        parseWind = parseEither (withObject "root" $ \root -> do
            -- Extract keys from JSON response
            current <- root .: "current"
            windSpeed <- current .: "wind_speed"
            windDegree <- current .: "wind_deg"

            -- Get cardinal direction and direction icon
            let (windDirection, windArrow) = getCardinalDir windDegree
            
            -- Represent wind speed to km/s and MPH from m/s
            -- 1 m/s = 2.23694 mph
            -- 1 m/s = 3.6 km/h
            let wind_kmh = (windSpeed * 3.6 :: Double)
            let wind_mph = (windSpeed * 2.23694 :: Double)

            -- Build wind speed string in metric and imperial units
            let windSpeedMetric = pack $ printf "%.2f km/h" wind_kmh
            let windSpeedImperial = pack $ printf "%.2f mph" wind_mph

            pure $ Wind windSpeedMetric windSpeedImperial windDirection windArrow)
            
        getCardinalDir :: Double -> (Text, Text)
        getCardinalDir windDeg =
            -- Each cardinal direction represents a segment of 22.5 degrees
            let cardinalDirections =
                    [ ("N", "↓")   -- 0/360 DEG
                    , ("NNE", "↙") -- 22.5 DEG
                    , ("NE",  "↙") -- 45 DEG
                    , ("ENE", "↙") -- 67.5 DEG
                    , ("E",   "←") -- 90 DEG
                    , ("ESE", "↖") -- 112.5 DEG
                    , ("SE",  "↖") -- 135 DEG
                    , ("SSE", "↖") -- 157.5 DEG
                    , ("S",   "↑") -- 180 DEG
                    , ("SSW", "↗") -- 202.5 DEG
                    , ("SW",  "↗") -- 225 DEG
                    , ("WSW", "↗") -- 247.5 DEG
                    , ("W",   "→") -- 270 DEG
                    , ("WNW", "↘") -- 292.5 DEG
                    , ("NW",  "↘") -- 315 DEG
                    , ("NNW", "↘") -- 337.5 DEG
                    ]
                -- Computes "idx ≡ round(wind_deg / 22.5) (mod 16)"
                -- to ensure that values above 360 degrees or below 0 degrees
                -- "stay" bounded to the map
                idx = round (windDeg / 22.5) `mod` 16
            in cardinalDirections !! idx

getCityForecast :: City -> Text -> IO (Either Text Forecast)
getCityForecast city apiKey = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: lat city <>
        "lon" =: lon city <>
        "appid" =: apiKey <>
        "units" =: ("metric" :: Text) <>
        "exclude" =: ("current,minutely,hourly,alerts" :: Text)

    -- Parse JSON response
    let resBody = responseBody response :: Value
    case parseForecast resBody of
        Right fc -> pure $ Right fc
        Left err -> pure $ Left $ "Unable to parse API request: " <> pack err
    where
        parseForecast :: Value -> Either String Forecast
        parseForecast = parseEither (withObject "root" $ \root -> do
            -- Extract the daily array from the JSON object
            daily <- root .: "daily"

            -- Parse each element of the array into a Weather object
            fc <- withArray "daily" (mapM parseDailyWeather . take 5 . V.toList) daily

            pure $ Forecast fc)

        parseDailyWeather :: Value -> Parser Weather
        parseDailyWeather = withObject "daily element" $ \obj -> do
            -- Extract temperature and weather condition
            temp <- obj .: "temp" >>= (.: "day")
            weatherArray <- obj .: "weather"
            unixTs <- obj .: "dt"
            conditionVal <- withArray "weather" (extractField "main" . V.toList) weatherArray
            icon <- withArray "weather" (extractField "icon" . V.toList) weatherArray
            
            -- Compute temperature in Celsius and Fahrenheit
            let celsiusVal = round (temp :: Double) :: Int
            let fahrenheitVal = (celsiusVal * 9 `div` 5) + 32

            -- Format UNIX timestamp as '<DAY_OF_THE_WEEK> dd/MM'
            let utcTime = posixSecondsToUTCTime (fromIntegral (unixTs :: Int))
            let weatherDate = utctDay utcTime

            -- Get emoji from weather condition
            let isNight = "n" `isSuffixOf` icon
            let emojiVal = getEmoji conditionVal isNight

            pure $ Weather
                { date = weatherDate
                , fahrenheitTemp = pack $ show fahrenheitVal
                , celsiusTemp = pack $ show celsiusVal
                , condition = conditionVal
                , condEmoji = emojiVal 
                }

getMoon :: Text -> IO (Either Text Moon)
getMoon apiKey = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: (41.8933203 :: Double) <> -- Rome latitude
        "lon" =: (12.4829321 :: Double) <> -- Rome longitude
        "appid" =: apiKey <>
        "units" =: ("metric" :: Text) <>
        "exclude" =: ("minutely,hourly,current,alerts" :: Text)

    -- Parse JSON response
    let resBody = responseBody response :: Value
    case parseMoon resBody of
        Right moon -> pure $ Right moon
        Left err -> pure $ Left $ "Unable to parse API request: " <> pack err
    where
        parseMoon :: Value -> Either String Moon
        parseMoon = parseEither (withObject "root" $ \root -> do
            -- Extract keys from JSON response
            daily <- root .: "daily"
            moonValue <- withArray "daily" (\arr -> do
                if V.null arr
                    then fail "daily array is empty"
                    else withObject "daily element" (.: "moon_phase") (V.head arr)) daily

            -- Map moon phase to emoji and phase description
            let (icon, phase) = getMoonPhase moonValue
            pure $ Moon icon phase)

        {- 0 and 1 are 'new moon',
        0.25 is 'first quarter moon',
        0.5 is 'full moon' and 0.75 is 'last quarter moon'.
        The periods in between are called 'waxing crescent',
        'waxing gibbous', 'waning gibbous' and 'waning crescent', respectively. -}
        getMoonPhase :: Double -> (Text, Text)
        getMoonPhase moonValue
            | moonValue == 0 || moonValue == 1 = ("🌑", "New Moon")
            | moonValue > 0 && moonValue < 0.25 = ("🌒", "Waxing Crescent")
            | moonValue == 0.25 = ("🌓", "First Quarter")
            | moonValue > 0.25 && moonValue < 0.5 = ("🌔", "Waxing Gibbous")
            | moonValue == 0.5 = ("🌕", "Full Moon")
            | moonValue > 0.5 && moonValue < 0.75 = ("🌖", "Waning Gibbous")
            | moonValue == 0.75 = ("🌗", "Last Quarter")
            | moonValue > 0.75 && moonValue < 1 = ("🌘", "Waning Crescent")
            | otherwise = ("❓", "Unknown moon phase")

getCityStatistics :: Text -> StatDB -> IO (Either Text StatResult)
getCityStatistics city db = do
    isInvalid <- isKeyInvalid db city
    
    if isInvalid
        then pure $ Left "Not enough data, can't apply statistics"
        else do
            -- Extract records from the database
            let stats = map snd $ filter (\(key, _) -> city `isSuffixOf` key) (Map.toList db)
                temps = mapMaybe (readMaybe . unpack . celsiusTemp) stats :: [Double]
                anomalies = detectAnomalies stats

            -- Compute statistics
            let res = StatResult
                    { Types.mean = roundValue $ Statistics.mean temps
                    , Types.min = minimum temps
                    , Types.max = maximum temps
                    , count = length temps
                    , Types.stdDev = roundValue $ Statistics.stdDev temps
                    , Types.median = Statistics.median temps
                    , Types.mode = Statistics.mode temps
                    , anomaly = parseAnomalies anomalies
                    }
            pure $ Right res
    where
        roundValue :: Double -> Double
        roundValue x = fromIntegral (round (x * 10000) :: Int) / 10000 -- 10^4 = 10000

        parseAnomalies :: [(Day, Double)] -> Maybe [WeatherAnomaly]
        parseAnomalies anomalies =
            if null anomalies
                then Nothing
                else Just (map (uncurry WeatherAnomaly) anomalies)