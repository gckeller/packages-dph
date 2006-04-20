-- |Debugging infrastructure for the parallel arrays library
--
--  Copyright (c) [2001..2002] Manuel M T Chakravarty & Gabriele Keller
--  Copyright (c) 2006	       Manuel M T Chakravarty
--
--  This file may be used, modified, and distributed under the same conditions
--  and the same warranty disclaimer as set out in the X11 license.
--
--- Description ---------------------------------------------------------------
--
--  Language: Haskell 98

module Data.Array.Parallel.Base.Debug (
    check
  , checkCritical
  , checkLen
  , checkEq
  , uninitialised
) where

import Data.Array.Parallel.Base.Config  (debug, debugCritical)

outOfBounds :: String -> Int -> Int -> a
outOfBounds loc n i = error $ loc ++ ": Out of bounds (size = "
                              ++ show n ++ "; index = " ++ show i ++ ")"

-- Check that the second integer is greater or equal to `0' and less than the
-- first integer
--
check :: String -> Int -> Int -> a -> a
{-# INLINE check #-}
check loc n i v 
  | debug      = if (i >= 0 && i < n) then v else outOfBounds loc n i
  | otherwise  = v
-- FIXME: Interestingly, ghc seems not to be able to optimise this if we test
--	  for `not debug' (it doesn't inline the `not'...)

-- Check that the second integer is greater or equal to `0' and less than the
-- first integer; this version is used to check operations that could corrupt
-- the heap
--
checkCritical :: String -> Int -> Int -> a -> a
{-# INLINE checkCritical #-}
checkCritical loc n i v 
  | debugCritical = if (i >= 0 && i < n) then v else outOfBounds loc n i
  | otherwise     = v

-- Check that the second integer is greater or equal to `0' and less or equal
-- than the first integer
--
checkLen :: String -> Int -> Int -> a -> a
{-# INLINE checkLen #-}
checkLen loc n i v 
  | debug      = if (i >= 0 && i <= n) then v else outOfBounds loc n i
  | otherwise  = v

checkEq :: (Eq a, Show a) => String -> String -> a -> a -> b -> b
checkEq loc msg x y v
  | debug     = if x == y then v else err
  | otherwise = v
  where
    err = error $ loc ++ ": " ++ msg
                  ++ " (first = " ++ show x
                  ++ "; second = " ++ show y ++ ")"

uninitialised :: String -> a
uninitialised loc = error $ loc ++ ": Touched an uninitialised value"
