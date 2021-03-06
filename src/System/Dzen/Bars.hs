-- |
-- Module      :  System.Dzen.Bars
-- Copyright   :  (c) 2009 Felipe A. Lessa
-- License     :  GPL 3 (see the LICENSE file in the distribution)
--
-- Maintainer  :  felipe.lessa@gmail.com
-- Stability   :  experimental
-- Portability :  semi-portable (uses MPTC and type families)
--
-- Drawing of progress bars (sometimes called progress gauges),
-- like @dbar@ and @gdbar@ utilities work but a little more
-- powerful (in fact, we can simulate both utilities, see 'dbar'
-- and 'gdbar').
--
-- An example of text progress bar that can be drawn:
--
-- > 96% [==================> ]
{-# LANGUAGE
    OverloadedStrings
  , NamedFieldPuns
  , ExplicitForAll
  , LambdaCase
  , StrictData
  , PatternGuards
  , ConstraintKinds
  #-}
module System.Dzen.Bars
  ( -- * Simple interface
    -- ** Mimicking @dbar@
    dbar
  , cdbar
    -- ** Mimicking @gdbar@
  , gdbar
  , cgdbar
    -- * Generic interface
  , bar
  , cbar
  , BarType(..)
  , BarTextType(..)
  , BarText(..)
    -- * Styles of the simple interfaces
    -- You may want to use some of these as the
    -- base for your own style. Look at the sources!
  , dbarStyle
  , gdbarStyle
  ) where

import Control.Arrow
import System.Dzen.Base
import System.Dzen.Colour
import System.Dzen.Graphics
import System.Dzen.Padding

type TNum n = (Num n, Enum n, Ord n, Show n)

-- | Helper function used below.
maybeLeft :: Bool -> BarText
maybeLeft v = if v then AtLeft Percentage else None

-- | Mimics the dbar utility. Uses the 'dbar_style'.
dbar :: TNum a
     => Bool  -- ^ If @True@, write the percentage on the left.
     -> Width -- ^ Width of the bar interior.
     -> (a,a) -- ^ Minimum and maximum values.
     -> a     -- ^ Actual value.
     -> DString
dbar p = bar (maybeLeft p) . dbarStyle '='

-- | Mimics the dbar utility while getting the input dinamically.
cdbar :: TNum a => Bool -> Width -> (a,a) -> Printer a
cdbar p = cbar (maybeLeft p) . dbarStyle '='

-- | The style produced by the dbar utility.
dbarStyle :: Char -> Width -> BarType
dbarStyle c txtWidth
    | txtFilled <- str [c] = Text
        { txtOpen       = "["
        , txtFilled
        , txtMiddle     = Nothing
        , txtBackground = " "
        , txtClose      = "]"
        , txtWidth
        }

-- | Mimics the gdbar utility. Uses the 'gdbar_style'.
gdbar :: TNum a
      => Bool            -- ^ If @True@, write the percentage on the left.
      -> (Width, Height) -- ^ Size of the whole bar (excluding text).
      -> Maybe DColour   -- ^ Filled colour (see 'grpFilled').
      -> Maybe DColour   -- ^ Background/border colour
                         --   (see 'grpBackground' and 'grpBorder').
      -> Bool            -- ^ @True@ to mimic @-o@ option (outline).
      -> (a,a)           -- ^ Minimum and maximum values.
      -> a               -- ^ Actual value.
      -> DString
gdbar p wh mFill mBg mOOpt = bar (maybeLeft p) (gdbarStyle wh mFill mBg mOOpt)

-- | Mimics the gdbar utility while getting the input dinamically.
cgdbar :: TNum a => Bool -> (Width, Height)
       -> Maybe DColour -> Maybe DColour -> Bool -> (a,a) -> Printer a
cgdbar p wh mFill mBg mOOpt = cbar (maybeLeft p) (gdbarStyle wh mFill mBg mOOpt)

-- | The style of gdbar (or something very close).
gdbarStyle :: (Width, Height) -> Maybe DColour
            -> Maybe DColour -> Bool -> BarType
gdbarStyle grpSize grpFilled back = \case
    False -> Filled
      { grpFilled
      , grpBackground = back
      , grpSize
      }
    True -> Hollow
      { grpFilled
      , grpBackground = Nothing -- That's what gdbar does!
      , grpBorder     = back
      , grpSize
      }

-- | The type of the bar to be drawn.
data BarType
  -- | Draws a text bar. Note, however, that the
  --  @DString@s below can be anything, not just
  --  text. For example, they may have colours ('fg'),
  --  shapes ('rect's and 'circ's) or 'icon's, you may
  --  even simulate both 'Filled' and 'Hollow' using just
  --  'Text' (although performance would be suboptimal).
  = Text
    { -- | Text written at the start.
      txtOpen       :: DString
      -- | Text written for each filled square.
    , txtFilled     :: DString
      -- | Text written for the last filled square.
      --   If @Nothing@, the same as the filled square
      --   is used, but more fairly than if you used
      --   the same value for filled and middle chars.
    , txtMiddle     :: Maybe DString
      -- | Text written for the unfilled squares.
    , txtBackground :: DString
      -- | Text written at the end.
    , txtClose      :: DString
      -- | How many squares there should be
      --   (i.e. does not count the open and close parts).
    , txtWidth      :: Width
    }
    -- | Draws a filled graphical bar, like @gdbar@ would.
  | Filled
    {
      -- | Colour used for filled squares, or @Nothing@
      --   to use the default /foreground/ colour.
      grpFilled     :: Maybe DColour
      -- | Colour used for the unfilled squares, or
      --   @Nothing@ to use the default /background/
      --   colour.
    , grpBackground :: Maybe DColour
      -- | Size of the whole bar.
    , grpSize       :: (Width, Height)}
    -- | Draws a filled graphical bar with a surrounding
    --   border.
  | Hollow
    {
      -- | Same as @grpFilled@ above.
      grpFilled     :: !(Maybe DColour)
      -- | Same as @grpBackground@ above.
    , grpBackground :: !(Maybe DColour)
      -- | Colour of the border, or @Nothing@ to use
      --   the default /foreground/ colour.
    , grpBorder     :: !(Maybe DColour)
      -- | Size of the whole bar (including border).
    , grpSize       :: !(Width, Height)
    }
  deriving (Show)

-- | The type of text to be written.
data BarTextType
    = Percentage
    | Absolute
    deriving (Eq, Ord, Show, Enum)

-- | How to draw the bar text. @AtLeft@ and @AtRight@ are used to
--   specify if the text is at the left or the right of the bar,
--   and @None@ means that no text will be written.
data BarText
    = AtLeft BarTextType
    | AtRight BarTextType
    | None
    deriving (Eq, Ord, Show)

-- | Draws a bar and optionally some text describing some quantity
--   in relation to some range. For example,
--
--   > bar (AtLeft Percentage) (Text "[" "=" (Just ">") " " "]" 20) (-10,10) i
--
--   produces the bars
--
--   > "  2% [                    ]"    where i = -9.6
--   > "  2% [>                   ]"    where i = -9.5
--   > " 50% [=========>          ]"    where i = 0
--   > " 96% [==================> ]"    where i = 9.4
--   > " 99% [===================>]"    where i = 9.99
--   > "100% [====================]"    where i = 10
--
--   Note that the text is always padded to four characters. If the
--   first bar above had @AtRight Percentage@ the result would be
--
--   > "[                    ] 2%  "
--
--   so the padding always inserts the spaces on the outside.
bar :: TNum a => BarText ->
       BarType -> (a,a) -> a -> DString
bar txt bar_ r v =
    case txt of
      None      -> drawnBar
      AtLeft t  -> padL 4 (barText t r v) <> " " <> drawnBar
      AtRight t -> drawnBar <> " " <> padR 4 (barText t r v)
    where
      drawnBar = barDraw bar_ r v

-- | 'bar' wrapped with 'simple' so that the value is
--   taken from an input.
cbar :: forall a. TNum a => BarText ->
         BarType -> (a,a) -> Printer a
cbar txt ty pair = simple (bar txt ty pair)

-- | Draws the text part of the bar.
barText :: TNum a => BarTextType -> (a,a) -> a -> DString
barText Absolute   _     val = str $ show val
barText Percentage range val
    = str $ (show . fst . fst $ barRound 100 range val) ++ "%"
{-# INLINE barText #-}

-- | Draws the bar itself.
barDraw :: TNum a => BarType -> (a,a) -> a -> DString
barDraw bt range val = case bt of
    Text { txtOpen = to
         , txtFilled = tf
         , txtMiddle
         , txtBackground = tb
         , txtClose = tc
         , txtWidth = tw
         } ->
        case txtMiddle of
          Just tm ->
              let ((f, b), more) = barRound tw range val
                  r | f >= tw      = to : replicate tw tf
                    | f > 0        = to : replicate f' tf ++ tm : replicate b' tb
                    | more         = to : tm : replicate (tw-1) tb
                    | otherwise    = to : replicate tw tb
                    where (f',b') | more      = (f, b-1)
                                  | otherwise = (f-1, b)
              in mconcat r <> tc
          Nothing ->
             let (f, b) = fst $ barRound tw range val
                 r = to : replicate f tf ++ replicate b tb
             in mconcat r <> tc
    Filled { grpFilled = gf
           , grpBackground = gb
           , grpSize = (gw,gh)
           } ->
        let (f, b) = fst $ barRound gw range val
        in mconcat [changeFg gf $ rect f gh
                   ,transpRect gb b gh]
    Hollow { grpFilled = gf
           , grpBackground = gb
           , grpBorder = gbd
           , grpSize = (gw_orig, gh_orig)
           } ->
        let gw = gw_orig - 4 -- Account for the border
            gh = gh_orig - 4
            (f, b) = fst $ barRound gw range val
      in mconcat [ pos 2
                 , changeFg gf $ rect f gh
                 , transpRect gb b gh
                 , pos $ negate (gw + 2)
                 , changeFg gbd $ ignoreBg True $ rectO gw_orig gh_orig
                 ]
{-# INLINE barDraw #-}

-- | Simulates transparency by not drawing at all.
transpRect :: Maybe DColour -> Width -> Height -> DString
transpRect Nothing  w _ = pos w
transpRect (Just c) w h = fg c $ rect w h

-- | Function used for rounding. It always rounds towards minus
--   infinity, so only the maximum value gives a full bar.
--   Values outside the range are clamped. The boolean returned
--   is @True@ iff the value would be one more if we rounded
--   half-up.
barRound :: TNum a =>
            Width -> (a,a) -> a -> ((Int, Int), Bool)
barRound w r n = let (f, b) = barRound' w r n in ((f, w - f), b)

barRound' :: TNum a =>
             Width -> (a,a) -> a -> (Int, Bool)
barRound' w (mini,maxi) n
    | maxi < mini = error "System.Dzen.Bars.bar: max value is less than min."
    | n <= mini   = (0, False)
    | n >= maxi   = (w, False)
    | otherwise   = let r = fromEnum (2 * fromIntegral w * (n-mini))
                            `div` fromEnum (maxi-mini)
                    in second (== 1) (r `divMod` 2)
