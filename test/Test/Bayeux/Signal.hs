{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE OverloadedStrings #-}

module Test.Bayeux.Signal
  ( tests
  ) where

import Bayeux.Encode
import Bayeux.Signal
import Bayeux.Width
import Data.Finite
import Data.Word
import Prettyprinter
import Prettyprinter.Render.String
import Test.Tasty
import Test.Tasty.HUnit

tests :: [TestTree]
tests =
  [ testGroup "encoding" valEncoding
  ]

valEncoding :: [TestTree]
valEncoding =
  [ valTest True  "1'1"
  , valTest False "1'0"
  , valTest (0xFF :: Word8) "8'11111111"
  , valTest (Nothing :: Maybe Bool) "2'00"
  , valTest (Just False) "2'10"
  , valTest (Just True)  "2'11"
  , valTest (0 :: Finite 1) "1'0"
  , valTest (1 :: Finite 2) "1'1"
  , valTest (2 :: Finite 3) "2'10"
  , valTest (1 :: Finite 3) "2'01"
  , valTest (7 :: Finite 8) "3'111"
  ]

valTest :: Encode a => Show a => Width a => a -> Sig a -> TestTree
valTest a s = testCase testName $ val a @?= s
  where
    testName = show a <> " ~ " <> renderPretty s

renderPretty :: Pretty a => a -> String
renderPretty = renderString . layoutPretty defaultLayoutOptions . pretty
