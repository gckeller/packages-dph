-- | Distributed types and operations.
module Data.Array.Parallel.Unlifted.Distributed (
  -- * Gang operations
  Gang, forkGang, gangSize,

  -- * Gang hacks
  theGang,

  -- * Distributed types and classes
  DT(..),

  -- * Higher-order combinators
  mapD, zipWithD, foldD, scanD,

  -- * Equality
  eqD, neqD,

  -- * Distributed scalars
  scalarD,
  andD, orD, sumD,

  -- * Distributed pairs
  zipD, unzipD, fstD, sndD,

  -- * Distributed arrays
  lengthD, splitLenD, splitLenIdxD,
  splitD, splitAsD, joinLengthD, joinD, splitJoinD, joinDM,
  Distribution, balanced, unbalanced,

  -- * Distributed segment descriptors
  splitSegdOnSegsD, splitSegdOnElemsD, splitSD, joinSegdD,
  lengthUSegdD, lengthsUSegdD, indicesUSegdD, elementsUSegdD,

  -- * Distributed scattered segment descriptors
  splitSSegdOnElemsD,

  -- * Permutations
  permuteD, bpermuteD, atomicUpdateD,

  -- * Debugging
  fromD, toD, debugD
) where

import Data.Array.Parallel.Unlifted.Distributed.TheGang
import Data.Array.Parallel.Unlifted.Distributed.Combinators
import Data.Array.Parallel.Unlifted.Distributed.Scalars
import Data.Array.Parallel.Unlifted.Distributed.Arrays
import Data.Array.Parallel.Unlifted.Distributed.USSegd
import Data.Array.Parallel.Unlifted.Distributed.USegd
import Data.Array.Parallel.Unlifted.Distributed.Basics
import Data.Array.Parallel.Unlifted.Distributed.Types
import Data.Array.Parallel.Unlifted.Distributed.Gang (Gang, forkGang, gangSize)

