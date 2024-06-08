{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE OverloadedStrings          #-}

-- | Yosys [RTLIL](https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_text.html)
module Bayeux.Rtlil
  ( -- * Lexical elements
    Ident(..)
  , Value(..)
  , BinaryDigit(..)
  , binaryDigits
  , -- * File
    File(..)
  , top
  , fiatLux
  , -- ** Autoindex statements
    AutoIdxStmt(..)
  , -- ** Modules
    Module(..)
  , ModuleStmt(..)
  , ModuleBody(..)
  , ParamStmt(..)
  , Constant(..)
  , ModuleEndStmt(..)
  , initial
  , counter
  , -- ** Attribute statements
    AttrStmt(..)
  , -- ** Signal specifications
    SigSpec(..)
  , -- ** Connections
    ConnStmt(..)
  , -- ** Wires
    Wire(..)
  , WireStmt(..)
  , WireId(..)
  , WireOption(..)
  , -- ** Memories
    Memory(..)
  , MemoryStmt(..)
  , MemoryOption(..)
  , -- ** Cells
    Cell(..)
  , CellStmt(..)
  , CellId(..)
  , CellType(..)
  , CellBodyStmt(..)
  , CellEndStmt(..)
  , -- *** Binary cells
    binaryCell
  , shiftCell
  , andC
  , orC
  , xorC
  , xnorC
  , shlC
  , shrC
  , sshlC
  , sshrC
  , logicAndC
  , logicOrC
  , eqxC
  , nexC
  , powC
  , ltC
  , leC
  , eqC
  , neC
  , geC
  , gtC
  , addC
  , subC
  , mulC
  , divC
  , modC
  , divFloorC
  , modFloorC
  , -- *** Primitive cells
    sbRgbaDrv
  , -- ** Processes
    Process(..)
  , ProcStmt(..)
  , ProcessBody(..)
  , AssignStmt(..)
  , DestSigSpec(..)
  , SrcSigSpec(..)
  , ProcEndStmt(..)
  , -- ** Switches
    Switch(..)
  , SwitchStmt(..)
  , Case(..)
  , CaseStmt(..)
  , Compare(..)
  , CaseBody(..)
  , SwitchEndStmt(..)
  , -- ** Syncs
    Sync(..)
  , SyncStmt(..)
  , SyncType(..)
  , UpdateStmt(..)
  ) where

import Data.Bits
import Data.Bool
import Data.String
import Data.Text (Text)
import Prettyprinter

newtype Ident = Ident Text
  deriving (Eq, IsString, Pretty, Read, Semigroup, Monoid, Show)

data Value = Value Integer [BinaryDigit]
  deriving (Eq, Read, Show)

instance Pretty Value where
  pretty (Value i bs) = pretty i <> "\'" <> foldMap pretty bs

data BinaryDigit = B0
                 | B1
                 | X
                 | Z
                 | M
                 | D
  deriving (Eq, Read, Show)

instance Pretty BinaryDigit where
  pretty = \case
    B0 -> "0"
    B1 -> "1"
    X  -> "x"
    Z  -> "z"
    M  -> "m"
    D  -> "-"

binaryDigits :: FiniteBits b => b -> [BinaryDigit]
binaryDigits b = bool B0 B1 . testBit b <$> reverse [0..finiteBitSize b - 1]

data File = File (Maybe AutoIdxStmt) [Module]
  deriving (Eq, Read, Show)

instance Pretty File where
  pretty (File iM ms) = let ms' = pretty <$> ms
                        in vsep $ case iM of
                             Just i  -> pretty i : ms'
                             Nothing -> ms'

top :: [ModuleBody] -> File
top body = File (Just 0) [Module [] "\\top" body ModuleEndStmt]

fiatLux :: File
fiatLux = top $
  [ ModuleBodyWire $ Wire [] $ WireStmt [WireOptionOutput 1] "\\red"
  , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionOutput 2] "\\green"
  , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionOutput 3] "\\blue"
  ] <> initial "\\pwm_r" True
    <> initial "\\pwm_g" False
    <> initial "\\pwm_b" False
    <> [ModuleBodyCell sbRgbaDrv]

newtype AutoIdxStmt = AutoIdxStmt Integer
  deriving (Eq, Num, Read, Show)

instance Pretty AutoIdxStmt where
  pretty (AutoIdxStmt i) = "autoidx" <+> pretty i

data Module = Module [AttrStmt] ModuleStmt [ModuleBody] ModuleEndStmt
  deriving (Eq, Read, Show)

instance Pretty Module where
  pretty (Module as m bs e) = vsep
    [ vsep $ pretty <$> as
    , pretty m
    , indent 2 $ vsep $ pretty <$> bs
    , pretty e
    ]

newtype ModuleStmt = ModuleStmt Ident
  deriving (Eq, IsString, Read, Show)

instance Pretty ModuleStmt where
  pretty (ModuleStmt i) = "module" <+> pretty i <> hardline

data ModuleBody = ModuleBodyParamStmt ParamStmt
                | ModuleBodyWire Wire
                | ModuleBodyMemory Memory
                | ModuleBodyCell Cell
                | ModuleBodyProcess Process
                | ModuleBodyConnStmt ConnStmt
  deriving (Eq, Read, Show)

instance Pretty ModuleBody where
  pretty = \case
    ModuleBodyParamStmt p -> pretty p
    ModuleBodyWire      w -> pretty w
    ModuleBodyMemory    m -> pretty m
    ModuleBodyCell      c -> pretty c
    ModuleBodyProcess   p -> pretty p
    ModuleBodyConnStmt  c -> pretty c


data ParamStmt = ParamStmt Ident (Maybe Constant)
  deriving (Eq, Read, Show)

instance Pretty ParamStmt where
  pretty (ParamStmt i cM) = mconcat
    [ "parameter" <+> pretty i
    , maybe mempty (surround " " " " . pretty) cM
    , hardline
    ]

data Constant = ConstantValue Value
              | ConstantInteger Integer
              | ConstantString Text
  deriving (Eq, Read, Show)

instance Pretty Constant where
  pretty = \case
    ConstantValue   v -> pretty v
    ConstantInteger i -> pretty i
    ConstantString  t -> dquotes $ pretty t

data ModuleEndStmt = ModuleEndStmt
  deriving (Eq, Read, Show)

instance Pretty ModuleEndStmt where
  pretty _ = "end" <> hardline

initial
  :: FiniteBits output
  => Text -- ^ output identifier
  -> output
  -> [ModuleBody]
initial outputIdent output =
  [ ModuleBodyWire $ Wire [] $ WireStmt [WireOptionWidth 1] $ WireId $ Ident outputIdent
  , ModuleBodyConnStmt $ ConnStmt
      (SigSpecWireId $ WireId $ Ident outputIdent)
      (SigSpecConstant value)
  ]
  where
    value = let size = fromIntegral $ finiteBitSize output
                bs   = binaryDigits output
            in ConstantValue $ Value size bs

counter
  :: Integer -- ^ width
  -> Ident   -- ^ old
  -> Ident   -- ^ new
  -> [ModuleBody]
counter w old new =
  [ ModuleBodyWire $ Wire [] $ WireStmt [WireOptionWidth w] $ WireId $ "\\" <> old
  , ModuleBodyWire $ Wire [] $ WireStmt [WireOptionWidth w] $ WireId new
  , ModuleBodyCell $ addC
      (CellId old)
      False
      w
      False
      w
      w
      (SigSpecWireId $ WireId $ "\\" <> old)
      (SigSpecConstant $ ConstantInteger 1)
      (WireId new)
  , ModuleBodyProcess $ Process
      []
      "$procStmt"
      (ProcessBody
         []
         Nothing
         []
         [Sync
            (SyncStmt Posedge (SigSpecWireId "\\clk"))
            [UpdateStmt
               (DestSigSpec $ SigSpecWireId $ WireId $ "\\" <> old)
               (SrcSigSpec  $ SigSpecWireId $ WireId new)
            ]
         ]
      )
      ProcEndStmt
  ]

data AttrStmt = AttrStmt Ident Constant
  deriving (Eq, Read, Show)

instance Pretty AttrStmt where
  pretty (AttrStmt i c) = "attribute" <+> pretty i <+> pretty c <> hardline

data SigSpec = SigSpecConstant Constant
             | SigSpecWireId   WireId
             | SigSpecSlice    SigSpec Integer (Maybe Integer)
             | SigSpecCat      [SigSpec]
  deriving (Eq, Read, Show)

instance Pretty SigSpec where
  pretty = \case
    SigSpecConstant c   -> pretty c
    SigSpecWireId w     -> pretty w
    SigSpecSlice s x yM -> pretty s <+> brackets (pretty x <> maybe mempty ((":" <>) . pretty) yM)
    SigSpecCat ss       -> braces $ foldMap pretty ss

data ConnStmt = ConnStmt SigSpec SigSpec
  deriving (Eq, Read, Show)

instance Pretty ConnStmt where
  pretty (ConnStmt x y) = "connect" <+> pretty x <+> pretty y <> hardline

data Wire = Wire [AttrStmt] WireStmt
  deriving (Eq, Read, Show)

instance Pretty Wire where
  pretty (Wire as s) = foldMap pretty as <> pretty s

data WireStmt = WireStmt [WireOption] WireId
  deriving (Eq, Read, Show)

instance Pretty WireStmt where
  pretty (WireStmt os i) = "wire" <+> hsep (pretty <$> os) <+> pretty i <> hardline

newtype WireId = WireId Ident
  deriving (Eq, IsString, Pretty, Read, Show)

data WireOption = WireOptionWidth  Integer
                | WireOptionOffset Integer
                | WireOptionInput  Integer
                | WireOptionOutput Integer
                | WireOptionInout  Integer
                | WireOptionUpto
                | WireOptionSigned
  deriving (Eq, Read, Show)

instance Pretty WireOption where
  pretty = \case
    WireOptionWidth  i -> "width"  <+> pretty i
    WireOptionOffset i -> "offset" <+> pretty i
    WireOptionInput  i -> "input"  <+> pretty i
    WireOptionOutput i -> "output" <+> pretty i
    WireOptionInout  i -> "inout"  <+> pretty i
    WireOptionUpto     -> "upto"
    WireOptionSigned   -> "signed"

data Memory = Memory [AttrStmt] MemoryStmt
  deriving (Eq, Read, Show)

instance Pretty Memory where
  pretty (Memory as s) = hsep $ pretty `fmap` as <> [pretty s]

data MemoryStmt = MemoryStmt [MemoryOption] Ident
  deriving (Eq, Read, Show)

instance Pretty MemoryStmt where
  pretty (MemoryStmt os i) = "memory" <> foldMap pretty os <> pretty i

data MemoryOption = MemoryOptionWidth  Integer
                  | MemoryOptionSize   Integer
                  | MemoryOptionOffset Integer
  deriving (Eq, Read, Show)

instance Pretty MemoryOption where
  pretty = \case
    MemoryOptionWidth  i -> "width"  <+> pretty i
    MemoryOptionSize   i -> "size"   <+> pretty i
    MemoryOptionOffset i -> "offset" <+> pretty i

data Cell = Cell [AttrStmt] CellStmt [CellBodyStmt] CellEndStmt
  deriving (Eq, Read, Show)

instance Pretty Cell where
  pretty (Cell as s bs e) = vsep
    [ foldMap pretty as <> pretty s
    , indent 2 $ foldMap pretty bs
    , pretty e
    ]


data CellStmt = CellStmt CellType CellId
  deriving (Eq, Read, Show)

instance Pretty CellStmt where
  pretty (CellStmt t i) = "cell" <+> pretty t <+> pretty i <> hardline

newtype CellId = CellId Ident
  deriving (Eq, IsString, Pretty, Read, Show)

newtype CellType = CellType Ident
  deriving (Eq, IsString, Pretty, Read, Show)

data ParamType = Signed | Real
  deriving (Eq, Read, Show)

instance Pretty ParamType where
  pretty Signed = "signed"
  pretty Real   = "real"

data CellBodyStmt = CellParameter (Maybe ParamType) Ident Constant
                  | CellConnect Ident SigSpec
  deriving (Eq, Read, Show)

instance Pretty CellBodyStmt where
  pretty = \case
    CellParameter Nothing i c -> "parameter" <+> pretty i <+> pretty c <> hardline
    CellParameter (Just p) i c -> "parameter" <+> pretty p <+> pretty i <+> pretty c <> hardline
    CellConnect i s -> "connect" <+> pretty i <+> pretty s <> hardline

data CellEndStmt = CellEndStmt
  deriving (Eq, Read, Show)

instance Pretty CellEndStmt where
  pretty _ = "end" <> hardline

binaryCell
  :: CellStmt
  -> Bool    -- ^ \\A_SIGNED
  -> Integer -- ^ \\A_WIDTH
  -> Bool    -- ^ \\B_SIGNED
  -> Integer -- ^ \\B_WIDTH
  -> Integer -- ^ \\Y_WIDTH
  -> SigSpec -- ^ A
  -> SigSpec -- ^ B
  -> WireId  -- ^ Y
  -> Cell
binaryCell cellStmt aSigned aWidth bSigned bWidth yWidth a b y = Cell
  []
  cellStmt
  [ CellParameter Nothing "\\A_SIGNED" $ ConstantInteger $ fromBool aSigned
  , CellParameter Nothing "\\A_WIDTH"  $ ConstantInteger aWidth
  , CellParameter Nothing "\\B_SIGNED" $ ConstantInteger $ fromBool bSigned
  , CellParameter Nothing "\\B_WIDTH"  $ ConstantInteger bWidth
  , CellParameter Nothing "\\Y_WIDTH"  $ ConstantInteger yWidth
  , CellConnect "\\A" a
  , CellConnect "\\B" b
  , CellConnect "\\Y" $ SigSpecWireId y
  ]
  CellEndStmt
  where
    fromBool :: Bool -> Integer
    fromBool True  = 1
    fromBool False = 0

shiftCell
  :: CellStmt
  -> Bool
  -> Integer
  -> Integer
  -> Integer
  -> SigSpec
  -> SigSpec
  -> WireId
  -> Cell
shiftCell cellStmt aSigned aWidth = binaryCell cellStmt aSigned aWidth False

-- binary cells
andC, orC, xorC, xnorC, logicAndC, logicOrC, eqxC, nexC, powC, ltC, leC, eqC, neC, geC, gtC, addC, subC, mulC, divC, modC, divFloorC, modFloorC
  :: CellId
  -> Bool
  -> Integer
  -> Bool
  -> Integer
  -> Integer
  -> SigSpec
  -> SigSpec
  -> WireId
  -> Cell

shlC, shrC, sshlC, sshrC
  :: CellId
  -> Bool
  -> Integer
  -> Integer
  -> Integer
  -> SigSpec
  -> SigSpec
  -> WireId
  -> Cell

andC      = binaryCell . CellStmt "$and"
orC       = binaryCell . CellStmt "$or"
xorC      = binaryCell . CellStmt "$xor"
xnorC     = binaryCell . CellStmt "$xnor"
shlC      = shiftCell  . CellStmt "$shl"
shrC      = shiftCell  . CellStmt "$shr"
sshlC     = shiftCell  . CellStmt "$sshl"
sshrC     = shiftCell  . CellStmt "$sshr"
logicAndC = binaryCell . CellStmt "$logic_and"
logicOrC  = binaryCell . CellStmt "$logic_or"
eqxC      = binaryCell . CellStmt "$eqx"
nexC      = binaryCell . CellStmt "$nex"
powC      = binaryCell . CellStmt "$pow"
ltC       = binaryCell . CellStmt "$lt"
leC       = binaryCell . CellStmt "$le"
eqC       = binaryCell . CellStmt "$eq"
neC       = binaryCell . CellStmt "$ne"
geC       = binaryCell . CellStmt "$ge"
gtC       = binaryCell . CellStmt "$gt"
addC      = binaryCell . CellStmt "$add"
subC      = binaryCell . CellStmt "$sub"
mulC      = binaryCell . CellStmt "$mul"
divC      = binaryCell . CellStmt "$div"
modC      = binaryCell . CellStmt "$mod"
divFloorC = binaryCell . CellStmt "$divfloor"
modFloorC = binaryCell . CellStmt "$modfloor"

sbRgbaDrv :: Cell
sbRgbaDrv = Cell
  [AttrStmt "\\module_not_derived" $ ConstantInteger 1]
  (CellStmt "\\SB_RGBA_DRV" "\\RGBA_DRIVER")
  [ CellParameter Nothing "\\CURRENT_MODE" $ ConstantString "0b1"
  , CellParameter Nothing "\\RGB0_CURRENT" $ ConstantString "0b111111"
  , CellParameter Nothing "\\RGB1_CURRENT" $ ConstantString "0b111111"
  , CellParameter Nothing "\\RGB2_CURRENT" $ ConstantString "0b111111"
  , CellConnect "\\CURREN" $ SigSpecConstant $ ConstantValue $ Value 1 [B1]
  , CellConnect "\\RGB0" $ SigSpecWireId "\\red"
  , CellConnect "\\RGB0PWM" $ SigSpecWireId "\\pwm_r"
  , CellConnect "\\RGB1" $ SigSpecWireId "\\green"
  , CellConnect "\\RGB1PWM" $ SigSpecWireId "\\pwm_g"
  , CellConnect "\\RGB2" $ SigSpecWireId "\\blue"
  , CellConnect "\\RGB2PWM" $ SigSpecWireId "\\pwm_b"
  , CellConnect "\\RGBLEDEN" $ SigSpecConstant $ ConstantValue $ Value 1 [B1]
  ]
  CellEndStmt

data Process = Process [AttrStmt] ProcStmt ProcessBody ProcEndStmt
  deriving (Eq, Read, Show)

instance Pretty Process where
  pretty (Process as s b e) = vsep
    [ foldMap pretty as <> pretty s
    , indent 2 $ pretty b
    , pretty e
    ]

newtype ProcStmt = ProcStmt Ident
  deriving (Eq, IsString, Read, Show)

instance Pretty ProcStmt where
  pretty (ProcStmt i) = "process" <+> pretty i <> hardline

data ProcessBody = ProcessBody [AssignStmt] (Maybe Switch) [AssignStmt] [Sync]
  deriving (Eq, Read, Show)

instance Pretty ProcessBody where
  pretty (ProcessBody as sM bs ss) = vsep
    [ foldMap pretty as
    , maybe mempty pretty sM
    , foldMap pretty bs
    , foldMap pretty ss
    ]

data AssignStmt = AssignStmt DestSigSpec SrcSigSpec
  deriving (Eq, Read, Show)

instance Pretty AssignStmt where
  pretty (AssignStmt d s) = "assign" <+> pretty d <+> pretty s <> hardline

newtype DestSigSpec = DestSigSpec SigSpec
  deriving (Eq, Pretty, Read, Show)

newtype SrcSigSpec = SrcSigSpec SigSpec
  deriving (Eq, Pretty, Read, Show)

data ProcEndStmt = ProcEndStmt
  deriving (Eq, Read, Show)

instance Pretty ProcEndStmt where
  pretty _ = "end" <> hardline

data Switch = Switch SwitchStmt [Case] SwitchEndStmt
  deriving (Eq, Read, Show)

instance Pretty Switch where
  pretty (Switch s cs e) = pretty s <> foldMap pretty cs <> pretty e

data SwitchStmt = SwitchStmt [AttrStmt] SigSpec
  deriving (Eq, Read, Show)

instance Pretty SwitchStmt where
  pretty (SwitchStmt as s) = foldMap pretty as <> "switch" <+> pretty s <> hardline

data Case = Case [AttrStmt] CaseStmt CaseBody
  deriving (Eq, Read, Show)

instance Pretty Case where
  pretty (Case as s b) = foldMap pretty as <> pretty s <+> pretty b

newtype CaseStmt = CaseStmt (Maybe Compare)
  deriving (Eq, Read, Show)

instance Pretty CaseStmt where
  pretty (CaseStmt Nothing)  = "case" <> hardline
  pretty (CaseStmt (Just c)) = "case" <+> pretty c <> hardline

data Compare = Compare SigSpec [SigSpec]
  deriving (Eq, Read, Show)

instance Pretty Compare where
  pretty (Compare s ss) = hsep $ punctuate "," $ pretty <$> s : ss

newtype CaseBody = CaseBody [Either Switch AssignStmt]
  deriving (Eq, Read, Show)

instance Pretty CaseBody where
  pretty (CaseBody es) = vsep $ either pretty pretty <$> es

data SwitchEndStmt = SwitchEndStmt
  deriving (Eq, Read, Show)

instance Pretty SwitchEndStmt where
  pretty _ = "end" <> hardline

data Sync = Sync SyncStmt [UpdateStmt]
  deriving (Eq, Read, Show)

instance Pretty Sync where
  pretty (Sync s us) = vsep
    [ pretty s
    , indent 2 $ foldMap pretty us
    ]

data SyncStmt = SyncStmt SyncType SigSpec
              | SyncStmtGlobal
              | SyncStmtInit
              | SyncStmtAlways
  deriving (Eq, Read, Show)

instance Pretty SyncStmt where
  pretty = \case
    SyncStmt t s   -> "sync" <+> pretty t <+> pretty s <> hardline
    SyncStmtGlobal -> "sync" <+> "global" <> hardline
    SyncStmtInit   -> "sync" <+> "init"   <> hardline
    SyncStmtAlways -> "sync" <+> "always" <> hardline

data SyncType = Low
              | High
              | Posedge
              | Negedge
              | Edge
  deriving (Eq, Read, Show)

instance Pretty SyncType where
  pretty = \case
    Low     -> "low"
    High    -> "high"
    Posedge -> "posedge"
    Negedge -> "negedge"
    Edge    -> "edge"

data UpdateStmt = UpdateStmt DestSigSpec SrcSigSpec
  deriving (Eq, Read, Show)

instance Pretty UpdateStmt where
  pretty (UpdateStmt d s) = "update" <+> pretty d <+> pretty s <> hardline