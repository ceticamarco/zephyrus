{-# LANGUAGE OverloadedStrings #-}
module Statistics where

import Types (Weather(..), StatDB, AppM)
import GHC.Conc (atomically)
import Control.Concurrent.STM.TVar (TVar, readTVarIO, modifyTVar')
import Control.Monad.IO.Class (liftIO)
import qualified Data.Map as Map
import Data.Text (Text, pack, isSuffixOf)
import Data.Time (getCurrentTime, utctDay, addDays)

insertStatistic :: TVar StatDB -> Text -> Weather -> AppM ()
insertStatistic tDb city weather = do
    -- Extract database from the state
    statDB <- liftIO $ readTVarIO tDb

    -- Format the key
    let key = (pack . show $ date weather) <> "@" <> city

    -- Insert statistic into the database if it doesn't exist
    case Map.lookup key statDB of
        Just _ -> return ()
        Nothing -> do
            liftIO $ atomically $ modifyTVar' tDb (Map.insert city weather)

-- A key is invalid if it has less than 2 entries in the last 2 days
isKeyInvalid :: StatDB -> Text -> IO Bool
isKeyInvalid db key = do
    currentTime <- getCurrentTime
    let dbList = Map.toList db
    let isValid (k, weather) =
            isSuffixOf key k &&
            date weather >= addDays (-2) (utctDay currentTime)
    return $ length (filter isValid dbList) < 2

mean :: [Double] -> Double
mean [] = 0
mean temps = sum temps / fromIntegral (length temps)