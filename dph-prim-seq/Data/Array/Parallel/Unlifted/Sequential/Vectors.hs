{-# LANGUAGE BangPatterns, FlexibleInstances, UndecidableInstances, CPP #-}
#include "fusion-phases.h"

-- | Irregular two dimensional arrays.
--
--   * TODO: The inner arrays should be unboxed so we don't get an unboxing overhead
--           for every call to unsafeIndex2. This might need an extension to the GHC
--           runtime if we alwo want to convert a U.Vector directly to this form.
--
--   * TODO: We currently only allow primitive types to be in a Vectors, but 
--           in future we'll want `Vectors` of tuples etc.
--
module Data.Array.Parallel.Unlifted.Sequential.Vectors 
        ( Vectors(..)
        , Unboxes
        , empty
        , singleton
        , unsafeIndex
        , unsafeIndex2
        , unsafeIndexUnpack
        , append
        , fromVector
        , toVector
        
        , unsafeExtracts
        , unsafeStreamVectors)
where
import qualified Data.Primitive.ByteArray                       as P
import qualified Data.Primitive.Array                           as P
import qualified Data.Primitive.Types                           as P

import qualified Data.Vector.Generic                            as G
import qualified Data.Vector.Fusion.Stream                      as S
import qualified Data.Vector.Fusion.Stream.Size                 as S
import qualified Data.Vector.Fusion.Stream.Monadic              as M
import qualified Data.Vector.Primitive                          as R
import qualified Data.Vector.Unboxed                            as U
import qualified Data.Vector                                    as V
import Data.Vector.Unboxed                                      (Unbox)

import qualified Data.Array.Parallel.Unlifted.Sequential.USegd  as USegd
import qualified Data.Array.Parallel.Unlifted.Sequential.USSegd as USSegd
import Data.Array.Parallel.Unlifted.Sequential.USSegd           (USSegd(..))
import System.IO.Unsafe
import Prelude  hiding (length)
import Debug.Trace
import Data.Word

-- | Class of element types that can be used in a `Vectors`
class R.Prim a => Unboxes a
instance Unboxes Int
instance Unboxes Word8
instance Unboxes Float
instance Unboxes Double


-- | A 2-dimensional array,
--   where the inner arrays can all have different lengths.
data Vectors a
        = Vectors
                {-# UNPACK #-} !Int             -- number of inner vectors
                {-# UNPACK #-} !P.ByteArray     -- starting index of each vector in its chunk
                {-# UNPACK #-} !P.ByteArray     -- lengths of each inner vector
                {-# UNPACK #-} !(P.Array P.ByteArray)   -- chunks

instance (Unboxes a, Unbox a, Show a) => Show (Vectors a) where
        show = show . toVector
        {-# NOINLINE show #-}

-- | Construct an empty `Vectors` with no arrays of no elements.
empty :: Vectors a
empty   
 = unsafePerformIO
 $ do   mba     <- P.newByteArray 0
        ba      <- P.unsafeFreezeByteArray mba
        marr    <- P.newArray 0 ba
        arr     <- P.unsafeFreezeArray marr
        return  $ Vectors 0 ba ba arr
{-# INLINE_U empty #-}


-- | Construct a `Vectors` containing data from a single unboxed array.
singleton :: Unboxes a => R.Vector a -> Vectors a
singleton vec 
 = unsafePerformIO
 $ do   R.MVector start len mbaData <- R.unsafeThaw vec
        baData  <- P.unsafeFreezeByteArray mbaData
        
        mbaStarts       <- P.newByteArray 1
        P.writeByteArray mbaStarts 0 start
        baStarts        <- P.unsafeFreezeByteArray mbaStarts
        
        mbaLengths      <- P.newByteArray 1
        P.writeByteArray mbaLengths 0 len
        baLengths       <- P.unsafeFreezeByteArray mbaLengths
        
        maChunks        <- P.newArray 1 baData
        aChunks         <- P.unsafeFreezeArray maChunks
        
        return  $ Vectors 1 baStarts baLengths aChunks
{-# INLINE_U singleton #-}


-- | Yield the number of vectors in a `Vectors`.
length :: Unboxes a => Vectors a -> Int
length (Vectors len _ _ _)      = len
{-# INLINE_U length #-}


-- | Take one of the outer vectors from a `Vectors`.
unsafeIndex :: (Unboxes a, Unbox a) => Vectors a -> Int -> U.Vector a
unsafeIndex (Vectors _ starts lens arrs) ix
 = G.convert
 $ unsafePerformIO
 $ do   let start       = P.indexByteArray starts ix
        let len         = P.indexByteArray lens   ix
        let arr         = P.indexArray     arrs   ix
        marr            <- P.unsafeThawByteArray arr
        let mvec        = R.MVector start len marr
        R.unsafeFreeze mvec
{-# INLINE_U unsafeIndex #-}


-- | Retrieve a single element from a `Vectors`, 
--   given the outer and inner indices.
unsafeIndex2 :: Unboxes a => Vectors a -> Int -> Int -> a
unsafeIndex2 (Vectors _ starts lens arrs) ix1 ix2
 = (arrs `P.indexArray` ix1) `P.indexByteArray` (starts `P.indexByteArray` ix1 + ix2)
{-# INLINE_U unsafeIndex2 #-}


-- | Retrieve an inner array from a `Vectors`, returning the array data, 
--   starting index in the data, and vector length.
unsafeIndexUnpack :: Unboxes a => Vectors a -> Int -> (P.ByteArray, Int, Int)
unsafeIndexUnpack (Vectors n starts lens arrs) ix
 =      ( arrs   `P.indexArray` ix
        , starts `P.indexByteArray` ix
        , lens   `P.indexByteArray` ix)
{-# INLINE_U unsafeIndexUnpack #-}


-- | Append two `Vectors`.
--
--   * Important: appending two `Vectors` involes work proportional to
--     the length of the outer arrays, not the size of the inner ones.
append :: Unboxes a => Vectors a -> Vectors a -> Vectors a
append  (Vectors len1 starts1 lens1 chunks1)
        (Vectors len2 starts2 lens2 chunks2)
 = unsafePerformIO
 $ do   let len' = len1 + len2

        -- append starts into result
        let lenStarts1  = P.sizeofByteArray starts1
        let lenStarts2  = P.sizeofByteArray starts2
        maStarts        <- P.newByteArray (lenStarts1 + lenStarts2)
        P.copyByteArray maStarts 0          starts1 0 lenStarts1
        P.copyByteArray maStarts lenStarts1 starts2 0 lenStarts2
        starts'         <- P.unsafeFreezeByteArray maStarts
        
        -- append lens into result
        let lenLens1    = P.sizeofByteArray lens1
        let lenLens2    = P.sizeofByteArray lens2
        maLens          <- P.newByteArray (lenLens1 + lenLens2)
        P.copyByteArray maLens   0          lens1   0 lenLens1
        P.copyByteArray maLens   lenStarts1 lens2   0 lenLens2
        lens'           <- P.unsafeFreezeByteArray maLens
        
        -- append arrs into result
        maChunks        <- P.newArray len' (error "Vectors: append argh!")
        P.copyArray     maChunks 0          chunks1   0 len1
        P.copyArray     maChunks len1       chunks2   0 len2
        chunks'         <- P.unsafeFreezeArray maChunks
        
        return  $ Vectors len' starts' lens' chunks'
{-# INLINE_U append #-}


-- | Convert a boxed vector of unboxed vectors to a `Vectors`.
fromVector :: (Unboxes a, Unbox a) => V.Vector (U.Vector a) -> Vectors a
fromVector vecs
 = unsafePerformIO
 $ do   let len     = V.length vecs
        let (barrs, vstarts, vlens)     = V.unzip3 $ V.map unpackUVector vecs
        let (baStarts, _, _)    = unpackUVector $ V.convert vstarts
        let (baLens,   _, _)    = unpackUVector $ V.convert vlens
        mchunks                 <- P.newArray len (error "Vectors: fromVector argh!")
        V.zipWithM_ 
                (\i vec
                   -> let (ba, _, _)  = unpackUVector vec
                      in  P.writeArray mchunks i ba)
                (V.enumFromN 0 len)
                vecs

        chunks   <- P.unsafeFreezeArray mchunks        
        return $ Vectors len baStarts baLens chunks
{-# INLINE_U fromVector #-}


-- | Convert a `Vectors` to a boxed vector of unboxed vectors.
toVector :: (Unboxes a, Unbox a) => Vectors a -> V.Vector (U.Vector a)
toVector vectors
        = V.map (unsafeIndex vectors)
        $ V.enumFromN 0 (length vectors)
{-# INLINE_U toVector #-}


-- | Unpack an unboxed vector into array data, starting index, and vector length.
unpackUVector :: (Unbox a, P.Prim a) => U.Vector a -> (P.ByteArray, Int, Int)
unpackUVector vec
 = unsafePerformIO
 $ do   let pvec        = V.convert vec
        R.MVector start len mba <- R.unsafeThaw pvec
        ba              <- P.unsafeFreezeByteArray mba
        return  (ba, start, len)
{-# INLINE_U unpackUVector #-}


-- | Pack some array data, starting index and vector length unto an unboxed vector.
packUVector :: (Unbox a, P.Prim a) => P.ByteArray -> Int -> Int -> U.Vector a
packUVector ba start len
 = unsafePerformIO
 $ do   mba             <- P.unsafeThawByteArray ba
        pvec            <- R.unsafeFreeze $ R.MVector start len mba
        return $ G.convert pvec
{-# INLINE_U packUVector #-}


-- | Copy segments from a `Vectors` and concatenate them into a new array.
unsafeExtracts
        :: (Unboxes a, U.Unbox a)
        => USSegd -> Vectors a -> U.Vector a

unsafeExtracts ussegd vectors
        = G.unstream $ unsafeStreamVectors ussegd vectors
{-# INLINE_U unsafeExtracts #-}


-- Stream -----------------------------------------------------------------------------------------
-- | Stream segments from a `Vectors`.
-- 
--   * There must be at least one segment in the `USSegd`, but this is not checked.
-- 
--   * No bounds checking is done for the `USSegd`.
unsafeStreamVectors :: Unboxes a => USSegd -> Vectors a -> S.Stream a
unsafeStreamVectors ussegd@(USSegd _ segStarts segSources usegd) vectors
 = segStarts `seq` segSources `seq` usegd `seq` vectors `seq`
   let  -- Length of each segment
        !segLens        = USegd.takeLengths usegd

        -- Total number of segments.
        !segsTotal      = USSegd.length ussegd
 
        -- Total number of elements to stream.
        !elements       = USegd.takeElements usegd
 
        -- seg, ix of that seg in usegd, length of seg, elem in seg
        {-# INLINE_INNER fnSeg #-}
        fnSeg (ixSeg, baSeg, ixEnd, ixElem)
         = ixSeg `seq` baSeg `seq`
           if ixElem >= ixEnd                   -- Was that the last elem in the current seg?
            then if ixSeg + 1 >= segsTotal      -- Was that last seg?

                       -- That was the last seg, we're done.
                  then return $ S.Done
                  
                       -- Move to the next seg.
                  else let ixSeg'       = ixSeg + 1
                           sourceSeg    = U.unsafeIndex segSources ixSeg'
                           startSeg     = U.unsafeIndex segStarts  ixSeg'
                           lenSeg       = U.unsafeIndex segLens    ixSeg'
                           (arr, startArr, lenArr) = unsafeIndexUnpack vectors sourceSeg
                       in  return $ S.Skip
                                  ( ixSeg'
                                  , arr
                                  , startArr + startSeg + lenSeg
                                  , startArr + startSeg)

                 -- Stream the next element from the segment.
            else let !result  = P.indexByteArray baSeg ixElem
                 in  return   $ S.Yield result (ixSeg, baSeg, ixEnd, ixElem + 1)

        -- Starting state of the stream.
        !initState
         = let  sourceSeg       = U.unsafeIndex segSources 0
                startSeg        = U.unsafeIndex segStarts  0
                lenSeg          = U.unsafeIndex segLens    0
                (arr, startArr, lenArr) = unsafeIndexUnpack vectors sourceSeg
           in   ( 0                              -- starting segment id
                , arr                            -- starting segment data
                , startArr + startSeg + lenSeg   -- segment end
                , startArr + startSeg)           -- segment start ix

        -- It's important that we set the result stream size, so Data.Vector
        -- doesn't need to add code to grow the result when it overflows.
   in   M.Stream fnSeg initState (S.Exact elements) 
{-# INLINE_STREAM unsafeStreamVectors #-}
