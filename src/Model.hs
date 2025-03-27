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

import Types (Weather(..), EnvMetrics(..))

getCityCoords :: Text -> Text -> IO (Either Text (Double, Double))
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
        parseCoords :: Value -> Parser (Double, Double)
        parseCoords = withObject "root" $ \obj -> do
            lat <- obj .: "lat"
            lon <- obj .: "lon"
            pure (toRealFloat lat, toRealFloat lon)

getCityWeather :: (Double, Double) -> Text -> IO (Either Text Weather)
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

getCityEnvMetrics :: (Double, Double) -> Text -> IO (Either Text EnvMetrics)
getCityEnvMetrics coordinates appid = runReq defaultHttpConfig $ do
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
    case parseEnvMetrics resBody of
        Right envMetrics -> pure $ Right envMetrics
        Left err -> pure $ Left $ "Unable to parse API request: " <> pack err
    where
        parseEnvMetrics :: Value -> Either String EnvMetrics
        parseEnvMetrics = parseEither (withObject "root" $ \root -> do
            -- Extract keys from JSON response
            current <- root .: "current"
            pressure' <- current .: "pressure"
            humidity' <- current .: "humidity"
            dewPoint <- current .: "dew_point"

            -- Compute dew point in Celsius and Fahrenheit
            let celsiusDewPoint' = round (dewPoint :: Double) :: Int
            let fahrenheitDewPoint' = (celsiusDewPoint' * 9 `div` 5) + 32

            -- Build pressure string
            let pressureStr = pack $ printf "%s hPa" (show (pressure' :: Int))

            -- Build humidity string
            let humidityStr = pack $ printf "%s%%" (show (humidity' :: Int))

            -- Build dew point strings in metric and imperial units
            let celsiusStr = pack $ printf "%s%s°C"
                    (if celsiusDewPoint' > 0 then "+" else "" :: String)
                    (show celsiusDewPoint')
            let fahrenheitStr = pack $ printf "%s%s°F"
                    (if fahrenheitDewPoint' > 0 then "+" else "" :: String)
                    (show fahrenheitDewPoint')

            pure $ EnvMetrics humidityStr pressureStr celsiusStr fahrenheitStr)