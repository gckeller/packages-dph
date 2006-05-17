-----------------------------------------------------------------------------
-- |
-- Module      : Data.Array.Parallel.Unlifted.Segmented.Permute
-- Copyright   : (c) [2001..2002] Manuel M T Chakravarty & Gabriele Keller
--		 (c) 2006         Manuel M T Chakravarty & Roman Leshchinskiy
-- License     : see libraries/base/LICENSE
-- 
-- Maintainer  : Manuel M T Chakravarty <chak@cse.unsw.edu.au>
-- Stability   : internal
-- Portability : portable
--
-- Description ---------------------------------------------------------------
--
--  Permutations of segmented unlifted arrays.
--
-- Todo ----------------------------------------------------------------------
--

module Data.Array.Parallel.Unlifted.Segmented.Permute (
  bpermuteSU
) where

import Data.Array.Parallel.Base (
  (:*:)(..), MaybeS(..))
import Data.Array.Parallel.Base.Fusion (
  loopArrS)
import Data.Array.Parallel.Unlifted.Flat (
  UA, (!:))
import Data.Array.Parallel.Unlifted.Segmented.SUArr (
  SUArr, psumUS)
import Data.Array.Parallel.Unlifted.Segmented.Basics (
  flattenSU)
import Data.Array.Parallel.Unlifted.Segmented.Loop (
  loopSU)

-- |Segmented back permute
--
bpermuteSU :: UA e => SUArr e -> SUArr Int -> SUArr e
{-# INLINE bpermuteSU #-}
bpermuteSU as = loopArrS . loopSU extract nextOff 0
	        where
		  (segd :*: a) = flattenSU as
		  psum	       = psumUS segd
		  --
	          extract off i = (off :*: (JustS $ a!:(off + i)))
		  --
		  nextOff _ segi = (psum !: (segi + 1) :*: 
				    (NothingS::MaybeS ()))
