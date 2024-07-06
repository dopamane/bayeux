module Test.Bayeux.Led
  ( tests
  ) where

import Bayeux.Led
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

tests :: [TestTree]
tests =
  [ testGroup "pretty"
      [ prettyTest "ledCtrl" $ handleErr $ compile ledCtrl
      ]
  , testGroup "synth"
      [ synthTest "ledCtrl" $ handleErr $ compile ledCtrl
      ]
  ]

handleErr :: Either Err File -> File
handleErr = either (error . show) id

prettyTest :: Pretty a => TestName -> a -> TestTree
prettyTest n = goldenVsString n (curDir </> n <.> "pretty")
                 . return . fromString . T.unpack . render . pretty

synthTest :: TestName -> File -> TestTree
synthTest n rtl = testCase n $ withTempFile $ \t -> do
  TIO.writeFile t $ render $ pretty rtl
  let c = "yosys -q -p \"synth_ice40\" -f rtlil " <> t
  (ExitSuccess @=?) =<< waitForProcess =<< spawnCommand c

curDir :: FilePath
curDir = "test" </> "Test" </> "Bayeux" </> "Led" </> "golden"

render :: Doc ann -> Text
render = renderStrict . layoutSmart defaultLayoutOptions