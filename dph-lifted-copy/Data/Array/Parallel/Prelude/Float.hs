{-# OPTIONS_GHC -fvectorise #-}

module Data.Array.Parallel.Prelude.Float (
  Float,
  
  -- Ord
  (==), (/=), (<), (<=), (>), (>=), min, max,

  minimumP, maximumP, minIndexP, maxIndexP,

  -- Num
  (+), (-), (*), negate, abs,

  sumP, productP,

  -- Fractional
  (/), recip,

  -- Floating
  pi, exp, sqrt, log, (**), logBase,
  sin, tan, cos, asin, atan, acos,
  sinh, tanh, cosh, asinh, atanh, acosh,

  -- RealFrac and similar
  fromInt,

  truncate, round, ceiling, floor,
) where

import Data.Array.Parallel.Prim ()       -- dependency required by the vectoriser

import Data.Array.Parallel.Prelude.Base

import Data.Array.Parallel.PArr
import Data.Array.Parallel.Lifted.Scalar
import Data.Array.Parallel.Lifted.Closure

import qualified Prelude as P


infixr 8 **
infixl 7 *, /
infixl 6 +, -
infix 4 ==, /=, <, <=, >, >=


(==), (/=), (<), (<=), (>), (>=) :: Float -> Float -> Bool
(==) = (P.==)
{-# VECTORISE SCALAR (==) #-}
(/=) = (P./=)
{-# VECTORISE SCALAR (/=) #-}
(<=) = (P.<=)
{-# VECTORISE SCALAR (<=) #-}
(<)  = (P.<)
{-# VECTORISE SCALAR (<) #-}
(>=) = (P.>=)
{-# VECTORISE SCALAR (>=) #-}
(>)  = (P.>)
{-# VECTORISE SCALAR (>) #-}

min, max :: Float -> Float -> Float
min = P.min
{-# VECTORISE SCALAR min #-}
max = P.max
{-# VECTORISE SCALAR max #-}

minimumP, maximumP :: PArr Float -> Float
{-# NOINLINE minimumP #-}
minimumP a = a `indexPArr` 0
{-# VECTORISE minimumP = minimumP_v #-}
{-# NOINLINE maximumP #-}
maximumP a = a `indexPArr` 0
{-# VECTORISE maximumP = maximumP_v #-}

minimumP_v, maximumP_v:: PArray Float :-> Float
{-# INLINE minimumP_v #-}
minimumP_v = closure1 (scalar_fold1 P.min) (scalar_fold1s P.min)
{-# NOVECTORISE minimumP_v #-}
{-# INLINE maximumP_v #-}
maximumP_v = closure1 (scalar_fold1 P.max) (scalar_fold1s P.max)
{-# NOVECTORISE maximumP_v #-}

minIndexP :: PArr Float -> Int
{-# NOINLINE minIndexP #-}
minIndexP _ = 0   -- FIXME: add proper implementation
{-# VECTORISE minIndexP = minIndexPA #-}

minIndexPA :: PArray Float :-> Int
{-# INLINE minIndexPA #-}
minIndexPA = closure1 (scalar_fold1Index min') (scalar_fold1sIndex min')
{-# NOVECTORISE minIndexPA #-}

min' (i,x) (j,y) | x P.<= y    = (i,x)
                 | P.otherwise = (j,y)
{-# NOVECTORISE min' #-}

maxIndexP :: PArr Float -> Int
{-# NOINLINE maxIndexP #-}
maxIndexP _ = 0   -- FIXME: add proper implementation
{-# VECTORISE maxIndexP = maxIndexPA #-}

maxIndexPA :: PArray Float :-> Int
{-# INLINE maxIndexPA #-}
maxIndexPA = closure1 (scalar_fold1Index max') (scalar_fold1sIndex max')
{-# NOVECTORISE maxIndexPA #-}

max' (i,x) (j,y) | x P.>= y    = (i,x)
                 | P.otherwise = (j,y)
{-# NOVECTORISE max' #-}

(+), (-), (*) :: Float -> Float -> Float
(+) = (P.+)
{-# VECTORISE SCALAR (+) #-}
(-) = (P.-)
{-# VECTORISE SCALAR (-) #-}
(*) = (P.*)
{-# VECTORISE SCALAR (*) #-}

negate, abs :: Float -> Float
negate = P.negate
{-# VECTORISE SCALAR negate #-}
abs = P.abs
{-# VECTORISE SCALAR abs #-}

sumP, productP :: PArr Float -> Float
{-# NOINLINE sumP #-}
sumP a = a `indexPArr` 0
{-# VECTORISE sumP = sumP_v #-}
{-# NOINLINE productP #-}
productP a = a `indexPArr` 0
{-# VECTORISE productP = productP_v #-}

sumP_v, productP_v:: PArray Float :-> Float
{-# INLINE sumP_v #-}
sumP_v     = closure1 (scalar_fold (+) 0) (scalar_folds (+) 0)
{-# NOVECTORISE sumP_v #-}
{-# INLINE productP_v #-}
productP_v = closure1 (scalar_fold (*) 1) (scalar_folds (*) 1)
{-# NOVECTORISE productP_v #-}

(/) :: Float -> Float -> Float
(/) = (P./)
{-# VECTORISE SCALAR (/) #-}

recip :: Float -> Float
recip = P.recip
{-# VECTORISE SCALAR recip #-}

pi :: Float
pi = P.pi
{-# NOVECTORISE pi #-}

exp, sqrt, log, sin, tan, cos, asin, atan, acos, sinh, tanh, cosh,
  asinh, atanh, acosh :: Float -> Float
exp = P.exp
{-# VECTORISE SCALAR exp #-}
sqrt = P.sqrt
{-# VECTORISE SCALAR sqrt #-}
log = P.log
{-# VECTORISE SCALAR log #-}
sin = P.sin
{-# VECTORISE SCALAR sin #-}
tan = P.tan
{-# VECTORISE SCALAR tan #-}
cos = P.cos
{-# VECTORISE SCALAR cos #-}
asin = P.asin
{-# VECTORISE SCALAR asin #-}
atan = P.atan
{-# VECTORISE SCALAR atan #-}
acos = P.acos
{-# VECTORISE SCALAR acos #-}
sinh = P.sinh
{-# VECTORISE SCALAR sinh #-}
tanh = P.tanh
{-# VECTORISE SCALAR tanh #-}
cosh = P.cosh
{-# VECTORISE SCALAR cosh #-}
asinh = P.asinh
{-# VECTORISE SCALAR asinh #-}
atanh = P.atanh
{-# VECTORISE SCALAR atanh #-}
acosh = P.acosh
{-# VECTORISE SCALAR acosh #-}

(**), logBase :: Float -> Float -> Float
(**) = (P.**)
{-# VECTORISE SCALAR (**) #-}
logBase = P.logBase
{-# VECTORISE SCALAR logBase #-}

fromInt :: Int -> Float
fromInt = P.fromIntegral
{-# VECTORISE SCALAR fromInt #-}

truncate, round, ceiling, floor :: Float -> Int
truncate = P.truncate
{-# VECTORISE SCALAR truncate #-}
round = P.round
{-# VECTORISE SCALAR round #-}
ceiling = P.ceiling
{-# VECTORISE SCALAR ceiling #-}
floor = P.floor
{-# VECTORISE SCALAR floor #-}
