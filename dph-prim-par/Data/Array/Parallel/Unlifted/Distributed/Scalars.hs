{-# OPTIONS -Wall -fno-warn-orphans -fno-warn-missing-signatures #-}

-- | Operations on distributed scalars.
--   With a distributed value like (Dist Int), each thread has its own integer, 
--   which may or may not have the same values as the ones on other threads.
module Data.Array.Parallel.Unlifted.Distributed.Scalars (
  scalarD,
  orD, andD, sumD
) where
import Data.Array.Parallel.Unlifted.Distributed.Gang
import Data.Array.Parallel.Unlifted.Distributed.Types
import Data.Array.Parallel.Unlifted.Distributed.Combinators


-- | Distribute a scalar.
--   Each thread gets its own copy of the same value.
--   Example:  scalarD theGangN4 10 = [10, 10, 10, 10] 
scalarD :: DT a => Gang -> a -> Dist a
scalarD g x = mapD g (const x) (unitD g)


-- | OR together all instances of a distributed 'Bool'.
orD :: Gang -> Dist Bool -> Bool
orD g = foldD g (||)


-- | AND together all instances of a distributed 'Bool'.
andD :: Gang -> Dist Bool -> Bool
andD g = foldD g (&&)


-- | Sum all instances of a distributed number.
sumD :: (Num a, DT a) => Gang -> Dist a -> a
sumD g = foldD g (+)


