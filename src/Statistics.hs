{-# LANGUAGE OverloadedStrings #-}
module Statistics where

import Types (Weather(..), StatDB, AppM)
import GHC.Conc (atomically)
import Control.Concurrent.STM.TVar (TVar, readTVarIO, modifyTVar')
import Control.Monad.IO.Class (liftIO)
import qualified Data.Map as Map
import Data.Text (Text, pack, unpack, isSuffixOf)
import Data.List (sort, group, maximumBy)
import Data.Time (getCurrentTime, utctDay, addDays, Day)
import Data.Function (on)

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

-- | A key is invalid if it has less than 2 entries in the last 2 days
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

stdDev :: [Double] -> Double
stdDev [] = 0
stdDev temps =
    let avg = mean temps
        variance = sum [(t - avg) ** 2 | t <- temps] / fromIntegral (length temps)
    in sqrt variance

median :: [Double] -> Double
median [] = 0
median temps =
    let sorted = sort temps
        n = length sorted
        mid = n `div` 2
    in if even n
        then (sorted !! (mid - 1) + sorted !! mid) / 2
        else sorted !! mid

-- This method will always return the largest mode
-- on a multi-modal dataset
mode :: [Double] -> Double
mode [] = 0
mode temps =
    let sorted = sort temps
    -- Groups consecutive duplicates
        grp = group sorted
    -- Find the longest group(i.e. the most frequent value)
        longestGrp = maximumBy (compare `on` length) grp
    -- return just the first element
    in head longestGrp

-- | Detects statistical anomalies using the Robust Z-Score algorithm
--   
--   This method is based on the median and the Median Absolute Deviation(MAD),
--   making it more robust to anomalies than the standard z-score which uses the arithmetical mean 
--   the and standard deviation
--  
--   A value is considered an anomaly if its modified z-score exceeds a fixed threshold(3.5)
--  
--   The scaling constant Φ⁻¹(0.75) ≈ 0.6745 adjusts the MAD to be comparable to the standard deviation
--   under the assumption of normal distribution (i.e. 75% of values lie within ~0.6745 standard deviations
--   of the median)
robustZScore :: [Double] -> [(Int, Double)]
robustZScore temps =
    let med = median temps
        mad = median (map (\x -> abs (x - med)) temps)
        threshold = 3.5 -- Standard threshold for MAD ZScore algorithms
    in if mad == 0 then []
       else [ (i, x) | (i, x) <- zip [0..] temps
                     , let zScore = 0.6745 * (x - med) / mad -- Φ⁻¹(3/4) ≈ 0.6745
                     , abs zScore > threshold ]

detectAnomalies :: [Weather] -> [(Day, Double)]
detectAnomalies weatherList =
    let -- Map each weather record to a (Date, Temp) pair
        tempsWithDates = map (\(Weather dt _ temp _ _) -> (dt, read (unpack temp) :: Double)) weatherList
        
        -- Apply the Robust/MAD Z-Score anomaly detection algorithm
        anomalies = robustZScore (map snd tempsWithDates)

    -- Return the list of (date, temperature) representing the anomalies
    in [(fst (tempsWithDates !! i), temp) | (i, temp) <- anomalies]