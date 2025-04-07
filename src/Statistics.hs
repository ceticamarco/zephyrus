module Statistics where

import Types (Weather(..), StatDB, AppM)
import GHC.Conc (atomically)
import Control.Concurrent.STM.TVar (TVar, readTVarIO, modifyTVar')
import Control.Monad.IO.Class (liftIO)
import Data.Time.Clock (getCurrentTime, UTCTime (utctDay))
import qualified Data.Map as Map
import Text.Printf (printf)
import Data.Text (Text, pack)
import Data.Functor ((<&>))
import Data.Time (toGregorian)

insertStatistic :: TVar StatDB -> Text -> Weather -> AppM ()
insertStatistic tDb city weather = do
    -- Extract database from the state
    statDB <- liftIO $ readTVarIO tDb
    currentDate <- liftIO $ getCurrentTime <&> toGregorian . utctDay
    
    -- Format the key as 'YYYY-MM-DD@city'
    let (y, m, d) = currentDate
        key = pack $ printf "%04d-%02d-%02d@%s" y m d city
    
    -- Insert statistic into the database if it doesn't exist
    case Map.lookup key statDB of
        Just _ -> return ()
        Nothing -> liftIO $ atomically $ modifyTVar' tDb (Map.insert key weather)