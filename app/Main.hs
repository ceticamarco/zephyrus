{-# LANGUAGE OverloadedStrings #-}

module Main where

import Servant ( hoistServer, serve, Application, Handler )
import qualified Data.Map as Map
import Control.Monad.Trans.Reader (ReaderT (runReaderT))
import Control.Concurrent.STM.TVar (newTVarIO)
import Network.Wai.Handler.Warp (run)
import System.Environment (lookupEnv)
import System.Exit (die)
import Data.Text (Text, unpack)
import Text.Read (readMaybe)
import qualified Data.Text as T

import Server (api, server)
import Types (State(..), AppM)

validatePort :: Int -> IO Int
validatePort port = if port < 0 || port > 65535
    then die "The port must be within the 0-65535 range"
    else pure port

validateTTL :: Int -> IO Int
validateTTL ttl = if ttl < 0
    then die "time-to-live variable must be a non-negative integer"
    else pure ttl

validateToken :: String -> Maybe Text
validateToken token =
    let tk = T.pack token
    in if T.length tk /= 32 
        then Nothing
        else Just tk

getEnvVariable :: Text -> (String -> Maybe a) -> (a -> IO b) -> IO b
getEnvVariable var parse validate = do
    maybeVal <- lookupEnv (unpack var)
    case maybeVal >>= parse of
        Just value -> validate value
        Nothing -> die (unpack var <> ": variable not set or invalid format")

appToHandler :: State -> AppM a -> Handler a
appToHandler state appM = runReaderT appM state

app :: State -> Application
app state = serve api (hoistServer api (appToHandler state) server)

main :: IO ()
main = do
    port <- getEnvVariable
        "ZEPHYRUS_PORT"
        readMaybe
        validatePort

    _ <- getEnvVariable
        "ZEPHYRUS_CACHE_TTL"
        readMaybe
        validateTTL

    _ <- getEnvVariable
        "ZEPHYRUS_TOKEN"
        validateToken
        pure

    -- Initialize cache and statistical database
    cache <- newTVarIO Map.empty
    db <- newTVarIO Map.empty

    -- Create initial state
    let state = State { zCache = cache, statDB = db }

    putStrLn ("Listening on http://127.0.0.1:" <> show port)
    run port (app state)