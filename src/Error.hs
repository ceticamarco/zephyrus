{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Error where

import GHC.Generics (Generic)
import Data.Aeson (ToJSON, encode)
import Data.Text (Text)
import Servant ( ServerError(..) )

-- Custom error response
newtype ErrorResponse = ErrorResponse { error :: Text } deriving (Generic)
instance ToJSON ErrorResponse

jsonError :: Int -> Text -> ServerError
jsonError code errMsg = ServerError
    { errHTTPCode = code
    , errReasonPhrase = show errMsg
    , errBody = encode $ ErrorResponse errMsg
    , errHeaders = [("Content-Type", "application/json")]
    }