{-# LANGUAGE OverloadedStrings #-}

module Main where

import Servant ( hoistServer, serve )
import qualified Data.Map as Map
import Control.Monad.Trans.Reader (ReaderT (runReaderT))
import Control.Concurrent.STM.TVar (newTVarIO)
import Network.Wai.Handler.Warp (run)
import System.Environment (lookupEnv)
import System.Exit (die)
import Data.Text (Text, unpack)

import Server (api, server)
import Types (State(..))

getEnvVariable :: Read a => Text -> Text -> IO a
getEnvVariable var errMsg = do
    maybeVal <- lookupEnv (unpack var)
    case maybeVal of
        Just value -> pure (read value)
        Nothing -> die (unpack errMsg)

main :: IO ()
main = do
    port <- getEnvVariable "ZEPHYRUS_PORT" "The ZEPHYRUS_PORT environment variable is not set" :: IO Int
    _ <- getEnvVariable "ZEPHYRUS_CACHE_TTL" "The ZEPHYRUS_CACHE_TTL environment variable is not set" :: IO Int
    _ <- getEnvVariable "ZEPHYRUS_TOKEN" "The ZEPHYRUS_TOKEN environment variable is not set" :: IO Int

    putStrLn ("Listening on http://127.0.0.1:" <> show port)
    initialCache <- newTVarIO Map.empty
    run port $ serve api $ hoistServer api (`runReaderT` State initialCache) server