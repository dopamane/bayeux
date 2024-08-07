{-# LANGUAGE OverloadedStrings #-}

module Test.Bayeux.Rtl
  ( tests
  , prettyTest
  , synthTest
  ) where

import Bayeux.Rtl
import Data.String
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Prettyprinter
import Prettyprinter.Render.Text
import System.Exit
import System.FilePath
import System.IO.Extra
import System.Process
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.Golden
import Yosys.Rtl

tests :: [TestTree]
tests =
  [ testGroup "pretty"
      [ prettyTest' "led"       rtlLed
      , prettyTest' "add"     $ addC "\\adder" False 32 False 32 33 (SigSpecWireId "\\a") (SigSpecWireId "\\b") (SigSpecWireId "\\y")
      , prettyTest' "counter" $ counter 8 "\\old" "\\new" "$old" "$procStmt"
      ]
  , testGroup "synth"
      [ synthTest "led"     rtlLed
      ]
  ]

counter
  :: Integer  -- ^ width
  -> WireId   -- ^ old
  -> WireId   -- ^ new
  -> CellId   -- ^ add
  -> ProcStmt -- ^ update
  -> [ModuleBody]
counter w old new addId procStmt =
  [ ModuleBodyWire $ Wire [] $ WireStmt [WireOptionWidth w] old
  , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionWidth w] new
  , ModuleBodyCell $ addC
      addId
      False
      w
      False
      w
      w
      (SigSpecWireId old)
      (SigSpecConstant $ ConstantInteger 1)
      (SigSpecWireId new)
  , ModuleBodyProcess $ updateP procStmt
      (DestSigSpec $ SigSpecWireId old)
      (SrcSigSpec  $ SigSpecWireId new)
  ]

prettyTest :: Pretty a => FilePath -> TestName -> a -> TestTree
prettyTest curDir n = goldenVsString n (curDir </> n <.> "pretty")
                        . return . fromString . T.unpack . render . pretty

prettyTest' :: Pretty a => TestName -> a -> TestTree
prettyTest' = prettyTest $ "test" </> "Test" </> "Bayeux" </> "Rtl" </> "golden"


synthTest :: TestName -> File -> TestTree
synthTest n rtl = testCase n $ withTempFile $ \t -> do
  TIO.writeFile t $ render $ pretty rtl
  let c = "yosys -q -p \"synth_ice40\" -f rtlil " <> t
  (ExitSuccess @=?) =<< waitForProcess =<< spawnCommand c

rtlLed :: File
rtlLed = File Nothing
  [ Module
      []
      "\\top"
      [ ModuleBodyWire $ Wire [] $ WireStmt [WireOptionInput  1] "\\clk"
      , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionOutput 2] "\\LED_R"
      , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionOutput 3] "\\LED_G"
      , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionOutput 4] "\\LED_B"
      , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionWidth 26] "\\counter"
      , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionWidth 32] "\\counter_plus_one"
      , ModuleBodyCell $ addC "$increment" False 26 False 32 32
          (SigSpecWireId "\\counter")
          (SigSpecConstant $ ConstantInteger 1)
          (SigSpecWireId "\\counter_plus_one")
      , ModuleBodyCell $ notC "$not$1" False 1 1
          (SigSpecSlice (SigSpecWireId "\\counter") 23 Nothing)
          (SigSpecWireId "\\LED_R")
      , ModuleBodyCell $ notC "$not$2" False 1 1
          (SigSpecSlice (SigSpecWireId "\\counter") 24 Nothing)
          (SigSpecWireId "\\LED_G")
      , ModuleBodyCell $ notC "$not$3" False 1 1
          (SigSpecSlice (SigSpecWireId "\\counter") 25 Nothing)
          (SigSpecWireId "\\LED_B")
      , ModuleBodyProcess $ Process
          []
          "$run"
          (ProcessBody
             []
             Nothing
             []
             [ Sync
                 (SyncStmt Posedge (SigSpecWireId "\\clk"))
                 [ UpdateStmt
                     (DestSigSpec $ SigSpecWireId "\\counter")
                     (SrcSigSpec $ SigSpecSlice
                        (SigSpecWireId "\\counter_plus_one")
                        25
                        (Just 0)
                     )
                 ]
             ]
          )
          ProcEndStmt
      ]
      ModuleEndStmt
  ] 

render :: Doc ann -> Text
render = renderStrict . layoutSmart defaultLayoutOptions
