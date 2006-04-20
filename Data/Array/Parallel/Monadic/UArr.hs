-----------------------------------------------------------------------------
-- |
-- Module      : Data.Array.Parallel.Monadic.UArr
-- Copyright   : (c) [2001..2002] Manuel M T Chakravarty & Gabriele Keller
--		 (c) 2006         Manuel M T Chakravarty
-- License     : see libraries/base/LICENSE
-- 
-- Maintainer  : Manuel M T Chakravarty <chak@cse.unsw.edu.au>
-- Stability   : internal
-- Portability : non-portable (GADTS)
--
-- Description ---------------------------------------------------------------
--
-- This module defines unlifted arrays generically as a GADT.
--
-- Clipping is implemented by each `BUArr' having the clipping information.  A
-- possible alternative design would be to maintain this information in
-- `UArr', but not in the representations, but at the root.  Both designs
-- seems to have advantages.
--
-- Todo ----------------------------------------------------------------------
--

module Data.Array.Parallel.Monadic.UArr (
  -- * Array types and classes containing the admissble elements types
  UA, MUA, UArr(..), MUArr(..), USel(..), MUSel(..), USegd(..), MUSegd(..),

  -- * Basic operations on parallel arrays
  lengthU, indexU, clipU, sliceU, newMU, newMSU, writeMU, nextMSU,
  unsafeFreezeMU, unsafeFreezeMSU, zipU, unzipU, (>:), flattenU, toUSegd,
  fromUSegd
) where

-- standard libraries
import Monad (liftM)

-- friends
import Data.Array.Parallel.Base.Hyperstrict
import Data.Array.Parallel.Base.BUArr (
  BUArr, MBUArr, UAE, lengthBU, lengthMBU, newMBU, indexBU, clipBU, readMBU,
  writeMBU, unsafeFreezeMBU, replicateBU, loopBU, loopArr, sliceBU, mapBU,
  scanBU, sliceMBU, insertMBU,  
  ST)
import Data.Array.Parallel.Base.Prim (
  Prim(..), MPrim(..),
  unPrim, unMPrim, mkPrim, mkMPrim)


infixl 9 `indexU`
infixr 9 >:


-- |Basic operations on representation types
-- -----------------------------------------

-- |This type class determines the types that can be elements immutable
-- unboxed arrays. The representation type of these arrays is defined by way
-- of an associated type.  All representation-dependent functions are methods
-- of this class.
--
class HS e => UA e where
--  data UArr e

  -- |Yield the length of an unboxed array (if segmented, number of segments)
  lengthU :: UArr e               -> Int

  -- |Extract an element out of an immutable unboxed array
  indexU  :: UArr e -> Int        -> e

  -- |Restrict access to a subrange of the original array (no copying)
  clipU  :: UArr e -> Int -> Int -> UArr e

  -- |Extract a slice out of an immutable unboxed array
  sliceU  :: UArr e -> Int -> Int -> UArr e

-- GADT TO REPLACE AT FOR THE MOMENT
data UArr e where
  UAUnit :: !Int                               -> UArr ()
  UAProd ::           !(UArr e1) -> !(UArr e2) -> UArr (e1 :*: e2)
  UASum  :: !USel  -> !(UArr e1) -> !(UArr e2) -> UArr (e1 :+: e2)
  UAPrim ::           !(Prim e)                -> UArr e
  UAUArr :: !USegd -> !(UArr e)                -> UArr (UArr e)

instance HS e => HS (UArr e)

-- |This type class covers those element types of unboxed arrays that can be
-- contained in immutable versions of these arrays.
--
class UA e => MUA e where
--  data MUArr e s

  -- |Allocate a mutable parallel array (which must not be segmented)
  newMU          :: Int                   -> ST s (MUArr e s)

  -- |Update an element in a mutable parallel array (must not be segmented)
  writeMU        :: MUArr e s -> Int -> e -> ST s ()

  -- |Convert a mutable into an immutable parallel array
  unsafeFreezeMU :: MUArr e s -> Int      -> ST s (UArr e)

-- GADT TO REPLACE AT FOR THE MOMENT
data MUArr e s where
  MUAUnit :: !Int                                          -> MUArr () s
  MUAProd ::                !(MUArr e1 s) -> !(MUArr e2 s) -> MUArr (e1 :*: e2) s
  MUASum  :: !(MUSel s)  -> !(MUArr e1 s) -> !(MUArr e2 s) -> MUArr (e1 :+: e2) s
  MUAPrim ::                !(MPrim e s)                   -> MUArr e s
  MUAUArr :: !(MUSegd s) -> !(MUArr e s)                   -> MUArr (UArr e) s

instance HS e => HS (MUArr e s)

-- |The functions `newMSU', `nextMSU', and `unsafeFreezeMSU' are to 
-- iteratively define a segmented mutable array; i.e., arrays of type `MUArr s
-- (UArr s e)'.  These arrays have *no* MUA instance.

-- |Allocate a segmented parallel array (providing the number of segments and
-- number of base elements); there can only be one segmentation level.
--
newMSU :: MUA e => Int -> Int -> ST s (MUArr (UArr e) s)
{-# INLINE newMSU #-}
newMSU nsegd n = do
		   segd <- newMBU nsegd
		   psum <- newMBU nsegd
		   a    <- newMU n
		   return $ MUAUArr (MUSegd segd psum) a

-- |Iterator support for filling a segmented mutable array left-to-right.
--
-- * If no element is given (ie, third argument is `Nothing'), a segment is
--   initialised.  Segment initialisation relies on previous segments already
--   being completed.
--
-- * Every segment must be initialised before it is filled left-to-right
--
nextMSU :: MUA e => MUArr (UArr e) s -> Int -> Maybe e -> ST s ()
{-# INLINE nextMSU #-}
nextMSU (MUAUArr (MUSegd segd psum) a) i Nothing =
  do                                                -- segment initialisation
    i' <- if i == 0 then return 0 
		    else do
		      off <- psum `readMBU` (i - 1)
		      n   <- segd `readMBU` (i - 1)
		      return $ off + n
    writeMBU psum i i'
    writeMBU segd i 0
nextMSU (MUAUArr (MUSegd segd psum) a) i (Just e) = 
  do
    i' <- psum `readMBU` i
    n' <- segd `readMBU` i
    writeMU a (i' + n') e
    writeMBU segd i (n' + 1)

-- |Convert a mutable segmented array into an immutable one.
--
unsafeFreezeMSU :: MUA e => MUArr (UArr e) s -> Int -> ST s (UArr (UArr e))
{-# INLINE unsafeFreezeMSU #-}
unsafeFreezeMSU (MUAUArr segd a) n = 
  do
    segd' <- unsafeFreezeMBU (segdMUS segd) n
    psum' <- unsafeFreezeMBU (psumMUS segd) n
    let n' = if n == 0 then 0 else psum' `indexBU` (n - 1) + 
				   segd' `indexBU` (n - 1)
    a' <- unsafeFreezeMU a n'
    return $ UAUArr (USegd segd' psum') a'



-- |Family of representation types
-- -------------------------------

-- |Array operations on the unit representation.
--
instance UA () where
  lengthU (UAUnit n)     = n
  indexU  (UAUnit _) _   = ()
  clipU   (UAUnit _) _ n = UAUnit n
  sliceU  (UAUnit _) _ n = UAUnit n

instance MUA () where
  newMU   n                    = return $ MUAUnit n
  writeMU (MUAUnit _) _ _      = return ()
  unsafeFreezeMU (MUAUnit _) n = return $ UAUnit n

-- |Array operations on the pair representation.
--
instance (UA a, UA b) => UA (a :*: b) where
  lengthU (UAProd l _)     = lengthU l
  {-# INLINE indexU #-}
  indexU  (UAProd l r) i   = indexU l i :*: indexU r i
  {-# INLINE clipU #-}
  clipU   (UAProd l r) i n = UAProd (clipU l i n) (clipU r i n)
  {-# INLINE sliceU #-}
  sliceU  (UAProd l r) i n = UAProd (sliceU l i n) (sliceU r i n)

instance (MUA a, MUA b) => MUA (a :*: b) where
  {-# INLINE newMU #-}
  newMU n = 
    do
      a <- newMU n
      b <- newMU n
      return $ MUAProd a b
  {-# INLINE writeMU #-}
  writeMU (MUAProd a b) i (x :*: y) = 
    do
      writeMU a i x
      writeMU b i y
  {-# INLINE unsafeFreezeMU #-}
  unsafeFreezeMU (MUAProd a b) n = 
    do
      a' <- unsafeFreezeMU a n
      b' <- unsafeFreezeMU b n
      return $ UAProd a' b'

-- |Selector for immutable arrays of sums
--
data USel = USel {
	      selUS  :: !(BUArr Bool),  -- selector (False => left)
	      lidxUS :: !(BUArr Int),   -- left indices
	      ridxUS :: !(BUArr Int)    -- right indices
	    }

instance HS USel

-- |Selector for mutable arrays of sums
--
data MUSel s = MUSel {
	         selMUS  :: !(MBUArr s Bool),  -- selector (False => left)
	         lidxMUS :: !(MBUArr s Int),   -- left indices
	         ridxMUS :: !(MBUArr s Int)    -- right indices
	       }

instance HS (MUSel s)

-- |Array operations on the sum representation
--
instance (UA a, UA b) => UA (a :+: b) where
  lengthU (UASum sel _ _)     = lengthBU (selUS sel)
  {-# INLINE indexU #-}
  indexU  (UASum sel l r) i   = if (selUS sel)`indexBU`i then Inr $ indexU r i 
					 	         else Inl $ indexU l i
  {-# INLINE clipU #-}
  clipU   (UASum sel l r) i n = 
    let
      sel'     = clipBU (selUS sel) i n
      li       = lidxUS sel`indexBU`i
      ri       = ridxUS sel`indexBU`i
      lidx     = mapBU (subtract li) $ clipBU (lidxUS sel) i n
      ridx     = mapBU (subtract ri) $ clipBU (ridxUS sel) i n
      (ln, rn) = if n == 0 then (0, 0) else (lidx`indexBU`(n - 1), 
					     ridx`indexBU`(n - 1))
    in
    UASum (USel sel' lidx ridx) (clipU l li ln) (clipU r ri rn)
  {-# INLINE sliceU #-}
  sliceU  (UASum sel l r) i n = 
    let
      sel'     = sliceBU (selUS sel) i n
      li       = lidxUS sel`indexBU`i
      ri       = ridxUS sel`indexBU`i
      lidx     = mapBU (subtract li) $ clipBU (lidxUS sel) i n
      ridx     = mapBU (subtract ri) $ clipBU (ridxUS sel) i n
      (ln, rn) = if n == 0 then (0, 0) else (lidx`indexBU`(n - 1), 
					     ridx`indexBU`(n - 1))
    in
    UASum (USel sel' lidx ridx) (sliceU l li ln) (sliceU r ri rn)

instance (MUA a, MUA b) => MUA (a :+: b) where
  {-# INLINE newMU #-}
  newMU n = do
	      sel  <- newMBU n
	      lidx <- newMBU n
	      ridx <- newMBU n
	      a    <- newMU n
	      b    <- newMU n
	      return $ MUASum (MUSel sel lidx ridx) a b
  {-# INLINE writeMU #-}
  writeMU (MUASum sel l r) i (Inl x) = 
    do
      let lidx = lidxMUS sel
	  ridx = ridxMUS sel
      writeMBU (selMUS sel) i False
      li <- if i == 0 then return 0 else liftM (+ 1) $ lidx`readMBU`(i - 1)
      ri <- if i == 0 then return 0 else	       ridx`readMBU`(i - 1)
      writeMBU lidx i li
      writeMBU ridx i ri
      writeMU l li x
  writeMU (MUASum sel l r) i (Inr x) = 
    do
      let lidx = lidxMUS sel
	  ridx = ridxMUS sel
      writeMBU (selMUS sel) i True
      li <- if i == 0 then return 0 else               lidx`readMBU`(i - 1)
      ri <- if i == 0 then return 0 else liftM (+ 1) $ ridx`readMBU`(i - 1)
      writeMBU lidx i li
      writeMBU ridx i ri
      writeMU r ri x
    --FIXME: that works only when the array is constructed left to right, but
    --not for something like permutations
  {-# INLINE unsafeFreezeMU #-}
  unsafeFreezeMU (MUASum sel l r) n = 
    do
      sel' <- unsafeFreezeMBU (selMUS  sel) n
      lidx <- unsafeFreezeMBU (lidxMUS sel) n
      ridx <- unsafeFreezeMBU (ridxMUS sel) n
      let ln = if n == 0 then 0 else lidx`indexBU`(n - 1)
	  rn = if n == 0 then 0 else ridx`indexBU`(n - 1)
      l' <- unsafeFreezeMU l ln
      r' <- unsafeFreezeMU r rn
      return $ UASum (USel sel' lidx ridx) l' r'

-- |Array operations on unboxed arrays
-- -
--
-- NB: We use instances for all possible unboxed types instead of re-using the
--     overloading provided by UAE to avoid having to store the UAE dictionary
--     in `UAPrimU'.

instance UA Bool where
  lengthU (UAPrim (PrimBool ua))    = lengthBU ua
  {-# INLINE indexU #-}
  indexU (UAPrim (PrimBool ua)) i   = ua `indexBU` i
  {-# INLINE clipU #-}
  clipU  (UAPrim (PrimBool ua)) i n = UAPrim . PrimBool $ clipBU ua i n
  {-# INLINE sliceU #-}
  sliceU (UAPrim (PrimBool ua)) i n = UAPrim . PrimBool $ sliceBU ua i n

instance MUA Bool where
  {-# INLINE newMU #-}
  newMU          n                            = 
    liftM (MUAPrim . MPrimBool  ) $ newMBU n
  {-# INLINE writeMU #-}
  writeMU        (MUAPrim (MPrimBool ua)) i e = writeMBU ua i e
  {-# INLINE unsafeFreezeMU #-}
  unsafeFreezeMU (MUAPrim (MPrimBool ua)) n   = 
    liftM (UAPrim . PrimBool  ) $ unsafeFreezeMBU ua n

instance UA Char where
  lengthU (UAPrim (PrimChar ua))    = lengthBU ua
  {-# INLINE indexU #-}
  indexU (UAPrim (PrimChar ua)) i   = ua `indexBU` i
  {-# INLINE clipU #-}
  clipU  (UAPrim (PrimChar ua)) i n = UAPrim . PrimChar $ clipBU ua i n
  {-# INLINE sliceU #-}
  sliceU (UAPrim (PrimChar ua)) i n = UAPrim . PrimChar $ sliceBU ua i n

instance MUA Char where
  {-# INLINE newMU #-}
  newMU          n                              = 
    liftM (MUAPrim . MPrimChar  ) $ newMBU n
  {-# INLINE writeMU #-}
  writeMU        (MUAPrim (MPrimChar ua)) i e = writeMBU ua i e
  {-# INLINE unsafeFreezeMU #-}
  unsafeFreezeMU (MUAPrim (MPrimChar ua)) n   = 
    liftM (UAPrim . PrimChar  ) $ unsafeFreezeMBU ua n

instance UA Int where
  lengthU (UAPrim (PrimInt ua))    = lengthBU ua
  {-# INLINE indexU #-}
  indexU (UAPrim (PrimInt ua)) i   = ua `indexBU` i
  {-# INLINE clipU #-}
  clipU  (UAPrim (PrimInt ua)) i n = UAPrim . PrimInt $ clipBU ua i n
  {-# INLINE sliceU #-}
  sliceU (UAPrim (PrimInt ua)) i n = UAPrim . PrimInt $ sliceBU ua i n

instance MUA Int where
  {-# INLINE newMU #-}
  newMU          n                            = 
    liftM (MUAPrim . MPrimInt   ) $ newMBU n
  {-# INLINE writeMU #-}
  writeMU        (MUAPrim (MPrimInt  ua)) i e = writeMBU ua i e
  {-# INLINE unsafeFreezeMU #-}
  unsafeFreezeMU (MUAPrim (MPrimInt  ua)) n   = 
    liftM (UAPrim . PrimInt   ) $ unsafeFreezeMBU ua n

instance UA Float where
  lengthU (UAPrim (PrimFloat ua))    = lengthBU ua
  {-# INLINE indexU #-}
  indexU (UAPrim (PrimFloat ua)) i   = ua `indexBU` i
  {-# INLINE clipU #-}
  clipU  (UAPrim (PrimFloat ua)) i n = UAPrim . PrimFloat $ clipBU ua i n
  {-# INLINE sliceU #-}
  sliceU (UAPrim (PrimFloat ua)) i n = UAPrim . PrimFloat $ sliceBU ua i n

instance MUA Float where
  {-# INLINE newMU #-}
  newMU          n                             = 
    liftM (MUAPrim . MPrimFloat ) $ newMBU n
  {-# INLINE writeMU #-}
  writeMU        (MUAPrim (MPrimFloat ua)) i e = writeMBU ua i e
  {-# INLINE unsafeFreezeMU #-}
  unsafeFreezeMU (MUAPrim (MPrimFloat ua)) n   = 
    liftM (UAPrim . PrimFloat ) $ unsafeFreezeMBU ua n

instance UA Double where
  lengthU (UAPrim (PrimDouble ua))    = lengthBU ua
  {-# INLINE indexU #-}
  indexU (UAPrim (PrimDouble ua)) i   = ua `indexBU` i
  {-# INLINE clipU #-}
  clipU  (UAPrim (PrimDouble ua)) i n = UAPrim . PrimDouble $ clipBU ua i n
  {-# INLINE sliceU #-}
  sliceU (UAPrim (PrimDouble ua)) i n = UAPrim . PrimDouble $ sliceBU ua i n

instance MUA Double where
  {-# INLINE newMU #-}
  newMU          n                              = 
    liftM (MUAPrim . MPrimDouble) $ newMBU n
  {-# INLINE writeMU #-}
  writeMU        (MUAPrim (MPrimDouble ua)) i e = writeMBU ua i e
  {-# INLINE unsafeFreezeMU #-}
  unsafeFreezeMU (MUAPrim (MPrimDouble ua)) n   = 
    liftM (UAPrim . PrimDouble) $ unsafeFreezeMBU ua n

-- |Segment descriptors are used to represent the structure of nested arrays.
--
data USegd = USegd {
	       segdUS :: !(BUArr Int),  -- segment lengths
	       psumUS :: !(BUArr Int)   -- prefix sum of former
	     }

-- |Mutable segment descriptor
--
data MUSegd s = MUSegd {
	          segdMUS :: !(MBUArr s Int),  -- segment lengths
	          psumMUS :: !(MBUArr s Int)   -- prefix sum of former
	        }

-- |Array operations on the segmented array representation
--
instance UA a => UA (UArr a) where
  lengthU (UAUArr segd _)    = lengthBU (segdUS segd)
  {-# INLINE indexU #-}
  indexU (UAUArr segd a) i   = sliceU a (psumUS segd `indexBU` i) 
				        (segdUS segd `indexBU` i)
  {-# INLINE clipU #-}
  clipU (UAUArr segd a) i n = 
    let
      segd1 = segdUS segd
      psum  = psumUS segd
      m     = if i == 0 then 0 else psum `indexBU` (i - 1)
      psum' = mapBU (subtract m) (clipBU psum i n)
      segd' = USegd (clipBU segd1 i n) psum'
      i'    = psum `indexBU` i
    in
    UAUArr segd' (clipU a i' (psum `indexBU` (i + n - 1) - i' + 1))
  {-# INLINE sliceU #-}
  sliceU (UAUArr segd a) i n = 
    let
      segd1 = segdUS segd
      psum  = psumUS segd
      m     = if i == 0 then 0 else psum `indexBU` (i - 1)
      psum' = mapBU (subtract m) (sliceBU psum i n)
      segd' = USegd (sliceBU segd1 i n) psum'
      i'    = psum `indexBU` i
    in
    UAUArr segd' (sliceU a i' (psum `indexBU` (i + n - 1) - i' + 1))



-- |NB: There is no `MUA' instance for `MUAUArr', as we cannot implement its
-- methods.  (Hence, newMSP and friends as extra functions above.)


-- |Further basic operations
-- -------------------------

-- |Elementwise pairing of array elements.
--
zipU :: (UA a, UA b) => UArr a -> UArr b -> UArr (a :*: b)
{-# INLINE [1] zipU #-}	-- see `UAFusion'
zipU = UAProd

-- |Elementwise unpairing of array elements.
--
unzipU :: (UA a, UA b) => UArr (a :*: b) -> (UArr a, UArr b)
unzipU (UAProd l r) = (l, r)

-- |Compose a nested array.
--
(>:) :: UA a => USegd -> UArr a -> UArr (UArr a)
{-# INLINE [1] (>:) #-}  -- see `UAFusion'
(>:) = UAUArr

-- |Decompose a nested array.
--
flattenU :: UA a => UArr (UArr a) -> (USegd , UArr a)
flattenU (UAUArr segd a) = (segd, a)

-- |Convert a length array into a segment descriptor.
--
toUSegd :: UArr Int -> USegd 
toUSegd (UAPrim (PrimInt lens)) = USegd lens (scanBU (+) 0 lens)

-- |Extract the length array from a segment descriptor.
--
fromUSegd :: USegd -> UArr Int
fromUSegd (USegd lens _) = UAPrim (PrimInt lens)