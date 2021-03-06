{-# LANGUAGE ParallelArrays #-}
{-# OPTIONS -fvectorise #-}
module Vectorised (ranksPA) where
import Data.Array.Parallel
import Data.Array.Parallel.Prelude.Int
import Data.Array.Parallel.Prelude.Bool
import qualified Prelude as P


ranksPA :: PArray Int -> PArray Int
ranksPA ps = toPArrayP (ranks (fromPArrayP ps))
{-# NOINLINE ranksPA #-}


ranks :: [:Int:] -> [:Int:]
ranks arr  = [: lengthP [: a | a <- arr, a < b :] | b <- arr :]
{-# NOINLINE ranks #-}

