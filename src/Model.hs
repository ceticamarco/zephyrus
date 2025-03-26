{-# LANGUAGE OverloadedStrings #-}

module Model where

import Data.Aeson (Value, withObject, withArray)
import Data.Aeson.Types (Value(..), (.:), parseEither, Parser)
import Data.Aeson.Key (fromText)
import qualified Data.Vector as V
import Data.Text (Text, pack, isSuffixOf)
import Data.Scientific (toRealFloat)
import Network.HTTP.Req ((/:), (=:), req, https, runReq, defaultHttpConfig, jsonResponse, responseBody)
import qualified Network.HTTP.Req as Req

import Types (Weather(..))

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
    let respBody = responseBody response :: Value
    case parseWeather respBody of
        Right weather -> pure $ Right weather
        Left err -> pure $ Left $ "Unable to parse API request: " <> pack err
    where
        parseWeather :: Value -> Either String Weather
        parseWeather = parseEither (withObject "root" $ \root -> do
            current <- root .: "current"
            weatherArray <- current .: "weather"
            condition <- withArray "weather" (extractField "main" . V.toList) weatherArray
            temp <- current .: "temp"
            icon <- withArray "weather" (extractField "icon" . V.toList) weatherArray
            let celsiusVal = fromIntegral (round (temp :: Double) :: Int)
            let fahrenheitVal = fromIntegral (round (celsiusVal * 1.8 + 32) :: Int)
            let isNight = "n" `isSuffixOf` icon
            pure $ Weather fahrenheitVal celsiusVal (getEmoji condition isNight))

        extractField :: Text -> [Value] -> Parser Text
        extractField field (x:_) = withObject "weather[0]" (.: fromText field) x
        extractField _ _ = fail "Weather array is empty"

        getEmoji :: Text -> Bool -> Text
        getEmoji condition isNight = 
            case condition of
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

