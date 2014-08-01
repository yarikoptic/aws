{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies    #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Aws.DynamoDb.Commands.Scan
-- Copyright   :  Soostone Inc
-- License     :  BSD3
--
-- Maintainer  :  Ozgun Ataman <ozgun.ataman@soostone.com>
-- Stability   :  experimental
--
-- Implementation of Amazon DynamoDb Scan command.
--
-- See: @http:\/\/docs.aws.amazon.com\/amazondynamodb\/latest\/APIReference\/API_Scan.html@
----------------------------------------------------------------------------

module Aws.DynamoDb.Commands.Scan where

-------------------------------------------------------------------------------
import           Control.Applicative
import           Data.Aeson
import           Data.Default
import           Data.Maybe
import qualified Data.Text           as T
import           Data.Typeable
import qualified Data.Vector         as V
-------------------------------------------------------------------------------
import           Aws.Core
import           Aws.DynamoDb.Core
-------------------------------------------------------------------------------


-- | A Scan command that uses primary keys for an expedient scan.
data Scan = Scan {
      sTableName     :: T.Text
    -- ^ Required.
    , sFilter        :: Conditions
    -- ^ Whether to filter results before returning to client
    , sStartKey      :: Maybe PrimaryKey
    -- ^ Exclusive start key to resume a previous query.
    , sLimit         :: Maybe Int
    -- ^ Whether to limit result set size
    , sSelect        :: QuerySelect
    -- ^ What to return from 'Scan'
    , sRetCons       :: ReturnConsumption
    , sSegment       :: Int
    , sTotalSegments :: Int
    } deriving (Eq,Show,Read,Ord,Typeable)


-- | Construct a minimal 'Scan' request.
scan :: T.Text                   -- ^ Table name
     -> Scan
scan tn = Scan tn def Nothing Nothing def def 0 1

-------------------------------------------------------------------------------
instance ToJSON Scan where
    toJSON Scan{..} = object $
      catMaybes
        [ ("ExclusiveStartKey" .= ) <$> sStartKey
        , ("Limit" .= ) <$> sLimit
        ] ++
      conditionsJson "ScanFilter" sFilter ++
      querySelectJson sSelect ++
      [ "TableName".= sTableName
      , "ReturnConsumedCapacity" .= sRetCons
      , "Segment" .= sSegment
      , "TotalSegments" .= sTotalSegments
      ]


-- | Response to a 'Scan' query.
data ScanResponse = ScanResponse {
      srItems    :: V.Vector Item
    , srLastKey  :: Maybe [Attribute]
    , srCount    :: Int
    , srScanned  :: Int
    , srConsumed :: Maybe ConsumedCapacity
    } deriving (Eq,Show,Read,Ord)


instance FromJSON ScanResponse where
    parseJSON (Object v) = ScanResponse
        <$> v .:?  "Items" .!= V.empty
        <*> ((do o <- v .: "LastEvaluatedKey"
                 Just <$> parseAttributeJson o)
             <|> pure Nothing)
        <*> v .:  "Count"
        <*> v .:  "ScannedCount"
        <*> v .:? "ConsumedCapacity"
    parseJSON _ = fail "ScanResponse must be an object."


instance Transaction Scan ScanResponse


instance SignQuery Scan where
    type ServiceConfiguration Scan = DdbConfiguration
    signQuery gi = ddbSignQuery "Scan" gi


instance ResponseConsumer r ScanResponse where
    type ResponseMetadata ScanResponse = DdbResponse
    responseConsumer _ ref resp = ddbResponseConsumer ref resp


instance AsMemoryResponse ScanResponse where
    type MemoryResponse ScanResponse = ScanResponse
    loadToMemory = return
