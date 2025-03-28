{-# LANGUAGE OverloadedStrings #-}

module Model where

import Data.Aeson (Value, withObject, withArray)
import Data.Aeson.Types (Value(..), (.:), parseEither, Parser)
import Data.Aeson.Key (fromText)
import qualified Data.Vector as V
import Data.Text (Text, pack, isSuffixOf)
import Text.Printf (printf)
import Data.Scientific (toRealFloat)
import Network.HTTP.Req ((/:), (=:), req, https, runReq, defaultHttpConfig, jsonResponse, responseBody)
import qualified Network.HTTP.Req as Req

import Types (Weather(..), Metrics(..), Wind(..), Coordinates)

getCityCoords :: Text -> Text -> IO (Either Text Coordinates)
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
                Right coords -> pure $ Right coords
                Left err -> pure $ Left $ "JSON parsing error: " <> pack err
        _ -> pure $ Left "Unexpected response format"
    where
        parseCoords :: Value -> Parser Coordinates
        parseCoords = withObject "root" $ \obj -> do
            lat <- obj .: "lat"
            lon <- obj .: "lon"
            pure (toRealFloat lat, toRealFloat lon)

getCityWeather :: Coordinates -> Text -> IO (Either Text Weather)
getCityWeather coordinates appid = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: fst coordinates <>
        "lon" =: snd coordinates <>
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
            icon <- withArray "weather" (extractField "icon" . V.toList) weatherArray

            -- Compute temperature in Celsius and Fahrenheit
            let celsiusVal = round (temp :: Double) :: Int
            let fahrenheitVal = (celsiusVal * 9 `div` 5) + 32

            -- Build temperature strings in metric and imperial units
            let celsiusStr = pack $ printf "%s%s°C"
                    (if celsiusVal > 0 then "+" else "" :: String)
                    (show celsiusVal)
            let fahrenheitStr = pack $ printf "%s%s°F"
                    (if fahrenheitVal > 0 then "+" else "" :: String)
                    (show fahrenheitVal)

            -- Get emoji from weather condition
            let isNight = "n" `isSuffixOf` icon
            let emojiVal = getEmoji conditionVal isNight

            pure $ Weather fahrenheitStr celsiusStr conditionVal emojiVal)

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

getCityMetrics :: Coordinates -> Text -> IO (Either Text Metrics)
getCityMetrics coordinates appid = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: fst coordinates <>
        "lon" =: snd coordinates <>
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

getCityWind :: Coordinates -> Text -> IO (Either Text Wind)
getCityWind coordinates apiKey = runReq defaultHttpConfig $ do
    -- Fetch weather data
    let reqUri = https "api.openweathermap.org" /: "data" /: "3.0" /: "onecall"
    response <- req Req.GET reqUri Req.NoReqBody jsonResponse $
        "lat" =: fst coordinates <>
        "lon" =: snd coordinates <>
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