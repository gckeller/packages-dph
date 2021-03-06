{-# LANGUAGE CPP #-}
#include "fusion-phases.h"

-- | Parallel combinators for segmented unboxed arrays
module Data.Array.Parallel.Unlifted.Parallel.Segmented 
        ( replicateRSUP
        , appendSUP
        , foldRUP
        , sumRUP)
where
import Data.Array.Parallel.Unlifted.Distributed
import Data.Array.Parallel.Unlifted.Parallel.Basics
import Data.Array.Parallel.Unlifted.Parallel.UPSegd                     (UPSegd)
import Data.Array.Parallel.Unlifted.Sequential.USegd                    (USegd)
import Data.Array.Parallel.Unlifted.Sequential.Vector                   as Seq
import qualified Data.Array.Parallel.Unlifted.Parallel.UPSegd           as UPSegd
import qualified Data.Array.Parallel.Unlifted.Sequential                as Seq
import qualified Data.Array.Parallel.Unlifted.Sequential.USegd          as USegd
import Data.Vector.Fusion.Stream.Monadic ( Stream(..), Step(..) )
import Data.Vector.Fusion.Stream.Size    ( Size(..) )
import qualified Data.Vector.Fusion.Stream                              as S

here :: String -> String
here s = "Data.Array.Parallel.Unlifted.Parallel.Segmented." Prelude.++ s

-- replicate ------------------------------------------------------------------
-- | Segmented replication.
--   Each element in the vector is replicated the given number of times.
--   
--   @replicateRSUP 2 [1, 2, 3, 4, 5] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]@
--

--   TODO: make this efficient
replicateRSUP :: Unbox a => Int -> Vector a -> Vector a
{-# INLINE_UP replicateRSUP #-}
replicateRSUP n xs
        = UPSegd.replicateWithP (UPSegd.fromLengths (replicateUP (Seq.length xs) n)) xs


-- Append ---------------------------------------------------------------------
-- | Segmented append.
appendSUP
        :: Unbox a
        => UPSegd
        -> UPSegd -> Vector a
        -> UPSegd -> Vector a
        -> Vector a

{-# INLINE_UP appendSUP #-}
appendSUP segd !xd !xs !yd !ys
  = joinD theGang balanced
  . mapD  theGang append
  $ UPSegd.takeDistributed segd
  where append ((segd',seg_off),el_off)
         = Seq.unstream
         $ appendSegS (UPSegd.takeUSegd xd) xs
                      (UPSegd.takeUSegd yd) ys
                      (USegd.takeElements segd')
                      seg_off el_off

-- append ---------------------------------------------------------------------
appendSegS
        :: Unbox a      
        => USegd        -- ^ Segment descriptor of first array.
        -> Vector a     -- ^ Data of first array
        -> USegd        -- ^ Segment descriptor of second array.
        -> Vector a     -- ^ Data of second array.
        -> Int
        -> Int
        -> Int
        -> S.Stream a

{-# INLINE_STREAM appendSegS #-}
appendSegS !xd !xs !yd !ys !n seg_off el_off
  = Stream next state (Exact n)
  where
    !xlens = USegd.takeLengths xd
    !ylens = USegd.takeLengths yd

    {-# INLINE index1 #-}
    index1  = Seq.index (here "appendSegS")

    {-# INLINE index2 #-}
    index2  = Seq.index (here "appendSegS")
    
    state
      | n == 0 = Nothing
      | el_off < xlens `index1` seg_off
      = let i = (USegd.takeIndices xd `index1` seg_off) + el_off
            j =  USegd.takeIndices yd `index1` seg_off
            k = (USegd.takeLengths xd `index1` seg_off) - el_off
        in  Just (False, seg_off, i, j, k, n)

      | otherwise
      = let -- NOTE: *not* indicesUSegd xd ! (seg_off+1) since seg_off+1
            -- might be out of bounds
            i       = (USegd.takeIndices xd `index1` seg_off) + (USegd.takeLengths xd `index1` seg_off)
            el_off' = el_off - USegd.takeLengths xd `index1` seg_off
            j       = (USegd.takeIndices yd `index1` seg_off) + el_off'
            k       = (USegd.takeLengths yd `index1` seg_off) - el_off'
        in  Just (True, seg_off, i, j, k, n)

    {-# INLINE next #-}
    next Nothing = return Done

    next (Just (False, seg, i, j, k, n'))
      | n' == 0    = return Done
      | k  == 0    = return $ Skip (Just (True, seg, i, j, ylens `index1` seg, n'))
      | otherwise  = return $ Yield (xs `index2` i) (Just (False, seg, i+1, j, k-1, n'-1))

    next (Just (True, seg, i, j, k, n'))
      | n' == 0    = return Done
      | k  == 0
      = let !seg' = seg+1
        in  return $ Skip (Just (False, seg', i, j, xlens `index1` seg', n'))

      | otherwise = return $ Yield (ys `index2` j) (Just (True, seg, i, j+1, k-1, n'-1))


-- foldR ----------------------------------------------------------------------
-- | Regular segmented fold.
foldRUP :: (Unbox a, Unbox b) => (b -> a -> b) -> b -> Int -> Vector a -> Vector b
{-# INLINE_UP foldRUP #-}
foldRUP f z !segSize xs = 
   joinD theGang unbalanced
    (mapD theGang 
      (Seq.foldlRU f z segSize)
      (splitAsD theGang (mapD theGang (*segSize) dlen) xs))
  where
    noOfSegs = Seq.length xs `div` segSize
    dlen = splitLenD theGang noOfSegs


-- sumR -----------------------------------------------------------------------
-- | Regular segmented sum.
sumRUP :: (Num e, Unbox e) => Int -> Vector e -> Vector e
{-# INLINE_UP sumRUP #-}
sumRUP = foldRUP (+) 0


