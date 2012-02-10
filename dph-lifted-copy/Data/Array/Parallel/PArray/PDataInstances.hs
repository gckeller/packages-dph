{-# LANGUAGE CPP, TemplateHaskell, EmptyDataDecls #-}
{-# OPTIONS -fno-warn-orphans -fno-warn-missing-methods #-}

#include "fusion-phases.h"

-- | Instances for the PData class
module Data.Array.Parallel.PArray.PDataInstances(
  PData(..), PDatas(..), Sels2,
  pvoid,
  punit,

  -- * Operators on arrays of tuples
  zipPA#,  unzipPA#, zip3PA#, unzip3PA#, unzip4PA#,
  zip4PA#, unzip4PA#, zip5PA#, unzip5PA#, zip6PA#, unzip6PA#, 
  zip7PA#, unzip7PA#, zip8PA#, unzip8PA#, 
  
  -- * Operators on nested arrays
  segdPA#, concatPA#, segmentPA#, copySegdPA#
)
where
import Data.Array.Parallel.PArray.Base
import Data.Array.Parallel.PArray.PData
import Data.Array.Parallel.PArray.PRepr
import Data.Array.Parallel.PArray.Types
import Data.Array.Parallel.Lifted.TH.Repr
import Data.Array.Parallel.Lifted.Unboxed       (elementsSegd#, elementsSel2_0#, elementsSel2_1#)
import Data.Array.Parallel.Base.DTrace          (traceFn)
import Data.Array.Parallel.Base                 (intToTag)
import qualified Data.Array.Parallel.Unlifted   as U
import Data.List                                (unzip4, unzip5, unzip6, unzip7)
import GHC.Exts                                 (Int(..), Int#)

-- Extra unzips ------------

-- We need unzips at large tuples (for tuple instances) as the closure environments generated by the
-- vectoriser are tuples whose arity is determined by the number of free variables.

unzip8  :: [(a,b,c,d,e,f,g,h)] -> ([a],[b],[c],[d],[e],[f],[g],[h])
unzip8  = foldr (\(a,b,c,d,e,f,g,h) ~(as,bs,cs,ds,es,fs,gs,hs) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs))
                 ([],[],[],[],[],[],[],[])
        
unzip9  :: [(a,b,c,d,e,f,g,h,i)] -> ([a],[b],[c],[d],[e],[f],[g],[h],[i])
unzip9  = foldr (\(a,b,c,d,e,f,g,h,i) ~(as,bs,cs,ds,es,fs,gs,hs,is) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs,i:is))
                 ([],[],[],[],[],[],[],[],[])
        
unzip10 :: [(a,b,c,d,e,f,g,h,i,j)] -> ([a],[b],[c],[d],[e],[f],[g],[h],[i],[j])
unzip10 = foldr (\(a,b,c,d,e,f,g,h,i,j) ~(as,bs,cs,ds,es,fs,gs,hs,is,js) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs,i:is,j:js))
                 ([],[],[],[],[],[],[],[],[],[])
        
unzip11 :: [(a,b,c,d,e,f,g,h,i,j,k)] -> ([a],[b],[c],[d],[e],[f],[g],[h],[i],[j],[k])
unzip11 = foldr (\(a,b,c,d,e,f,g,h,i,j,k) ~(as,bs,cs,ds,es,fs,gs,hs,is,js,ks) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs,i:is,j:js,k:ks))
                 ([],[],[],[],[],[],[],[],[],[],[])
        
unzip12 :: [(a,b,c,d,e,f,g,h,i,j,k,l)] -> ([a],[b],[c],[d],[e],[f],[g],[h],[i],[j],[k],[l])
unzip12 = foldr (\(a,b,c,d,e,f,g,h,i,j,k,l) ~(as,bs,cs,ds,es,fs,gs,hs,is,js,ks,ls) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs,i:is,j:js,k:ks,l:ls))
                 ([],[],[],[],[],[],[],[],[],[],[],[])

unzip13 :: [(a,b,c,d,e,f,g,h,i,j,k,l,m)] -> ([a],[b],[c],[d],[e],[f],[g],[h],[i],[j],[k],[l],[m])
unzip13 = foldr (\(a,b,c,d,e,f,g,h,i,j,k,l,m) ~(as,bs,cs,ds,es,fs,gs,hs,is,js,ks,ls,ms) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs,i:is,j:js,k:ks,l:ls,m:ms))
                 ([],[],[],[],[],[],[],[],[],[],[],[],[])

unzip14 :: [(a,b,c,d,e,f,g,h,i,j,k,l,m,n)] 
        -> ([a],[b],[c],[d],[e],[f],[g],[h],[i],[j],[k],[l],[m],[n])
unzip14 = foldr (\(a,b,c,d,e,f,g,h,i,j,k,l,m,n) ~(as,bs,cs,ds,es,fs,gs,hs,is,js,ks,ls,ms,ns) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs,i:is,j:js,k:ks,l:ls,m:ms,n:ns))
                 ([],[],[],[],[],[],[],[],[],[],[],[],[],[])

unzip15 :: [(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)] 
        -> ([a],[b],[c],[d],[e],[f],[g],[h],[i],[j],[k],[l],[m],[n],[o])
unzip15 = foldr (\(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o) ~(as,bs,cs,ds,es,fs,gs,hs,is,js,ks,ls,ms,ns,os) ->
                    (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs,h:hs,i:is,j:js,k:ks,l:ls,m:ms,n:ns,o:os))
                 ([],[],[],[],[],[],[],[],[],[],[],[],[],[],[])


-- Void -----------------------------------------------------------------------

-- | The Void type is used when representing enumerations. 
--   A type like Bool is represented as @Sum2 Void Void@, meaning that we only
--   only care about the tag of the data constructor and not its argumnent.
--
data instance PData Void

pvoid :: PData Void
pvoid =  error "Data.Array.Parallel.PData Void"

$(voidPRInstance ''Void 'void 'pvoid)


-- Unit -----------------------------------------------------------------------
-- | An array of unit values is represented by a single constructor.
--   There is only one possible value, so we only need to record it once.
--
--   We often uses arrays of unit values as the environmnent portion of a 
--   lifted closure. For example, suppose we vectorise the unary function 
--   @neg@. This function has no environment, so we construct the closure, 
--   we fill in the environment field with @()@, which gives @Clo neg_v neg_l ()@.
--
--   Suppose we then compute @replicate n neg@. This results in an array of 
--   closures. We only need one copy of the implementation functions neg_v and
--   neg_l, but the unit environment () is lifted to an array of units, 
--   which we represent as PUnit.
--
--   Note that we need to store at least one real value, PUnit in this case, 
--   because this value also represents the divergence behaviour of the whole
--   array. When evaluating a bulk-strict array, if any of the elements diverge 
--   then the whole array does. We represent a diverging array of () by using
--   a diverging computation of type PUnit as its representation.
--
data instance PData ()
        = PUnit

punit :: PData ()
punit =  PUnit

$(unitPRInstance 'PUnit)


-- Wrap -----------------------------------------------------------------------
newtype instance PData (Wrap a)
        = PWrap (PData a)

$(wrapPRInstance ''Wrap 'Wrap 'unWrap 'PWrap)

{- Generated code:
instance PA a => PR (Wrap a) where
... INLINE pragmas ...
    emptyPR = traceFn "emptyPR" "Wrap a" (PWrap emptyPD)

    replicatePR n# (Wrap x)
            = traceFn "replicatePR" "Wrap a" (PWrap (replicatePD n# x))

    replicatelPR segd (PWrap xs)
            = traceFn "replicatelPR" "Wrap a" (PWrap (replicatelPD segd xs))

    repeatPR n# len# (PWrap xs)
            = traceFn "repeatPR" "Wrap a" (PWrap (repeatPD n# len# xs))

    indexPR (PWrap xs) i#
            = traceFn "indexPR" "Wrap a" (Wrap (indexPD xs i#))

    extractPR (PWrap xs) i# n#
            = traceFn "extractPR" "Wrap a" (PWrap (extractPD xs i# n#))

    bpermutePR (PWrap xs) n# is
            = traceFn "bpermutePR" "Wrap a" (PWrap (bpermutePD xs n# is))

    appPR (PWrap xs1) (PWrap xs2)
            = traceFn "appPR" "Wrap a" (PWrap (appPD xs1 xs2))

    applPR segd is (PWrap xs1) js (PWrap xs2)
            = traceFn "applPR" "Wrap a" (PWrap (applPD segd is xs1 js xs2))

    packByTagPR (PWrap xs) n# tags t#
            = traceFn
            "packByTagPR" "Wrap a" (PWrap (packByTagPD xs n# tags t#))

    combine2PR n# sel (PWrap xs1) (PWrap xs2)
            = traceFn "combine2PR" "Wrap a" (PWrap (combine2PD n# sel xs1 xs2))

    updatePR (PWrap xs1) is (PWrap xs2)
            = traceFn "updatePR" "Wrap a" (PWrap (updatePD xs1 is xs2))

    fromListPR n# xs
            = traceFn "fromListPR" "Wrap a" (PWrap (fromListPD n# (map unWrap xs)))
      
    nfPR (PWrap xs) 
            = traceFn "nfPR" "Wrap a" (nfPD xs) }
-}


-- Tuples ---------------------------------------------------------------------

$(tupleInstances [2..15])

{- Generated code:

data instance PData (a,b)
  = P_2 (PData a)
        (PData b)

instance (PR a, PR b) => PR (a,b) where
    {-# INLINE emptyPR #-}
    emptyPR = P_2 emptyPR emptyPR

    {-# INLINE replicatePR #-}
    replicatePR n# (a,b) = 
      P_2 (replicatePR n# a)
          (replicatePR n# b)

    {-# INLINE replicatelPR #-}
    replicatelPR segd (P_2 as bs) =
      P_2 (replicatelPR segd as)
          (replicatelPR segd bs) 

    {-# INLINE repeatPR #-}
    repeatPR n# len# (P_2 as bs) =
      P_2 (repeatPR n# len# as)
          (repeatPR n# len# bs)

    {-# INLINE indexPR #-}
    indexPR (P_2 as bs) i# = (indexPR as i#, indexPR bs i#)

    {-# INLINE extractPR #-}
    extractPR (P_2 as bs) i# n# = 
      P_2 (extractPR as i# n#)
          (extractPR bs i# n#)

    {-# INLINE bpermutePR #-}
    bpermutePR (P_2 as bs) n# is =
      P_2 (bpermutePR as n# is)
          (bpermutePR bs n# is)

    {-# INLINE appPR #-}
    appPR (P_2 as1 bs1) (P_2 as2 bs2) =
      P_2 (appPR as1 as2) (appPR bs1 bs2)

    {-# INLINE applPR #-}
    applPR is (P_2 as1 bs1) js (P_2 as2 bs2) =
      P_2 (applPR is as1 js as2)
          (applPR is bs1 js bs2)

    {-# INLINE packByTagPR #-}
    packByTagPR (P_2 as bs) n# tags t# =
      P_2 (packByTagPR as n# tags t#)
          (packByTagPR bs n# tags t#)

    {-# INLINE combine2PR #-}
    combine2PR n# sel (P_2 as1 bs1) (P_2 as2 bs2) =
      P_2 (combine2PR n# sel as1 as2)
          (combine2PR n# sel bs1 bs2)

    {-# INLINE updatePR #-}
    updatePR (P_2 as1 bs1) is (P_2 as2 bs2) =
      P_2 (updatePR as1 is as2)
          (updatePR bs1 is bs2)

    {-# INLINE fromListPR #-}
    fromListPR n# xs = let (as,bs) = unzip xs in
      P_2 (fromListPR n# as)
          (fromListPR n# bs)

    {-# INLINE nfPR #-}
    nfPR (P_2 as bs) = nfPR as `seq` nfPR bs
-}

data instance PDatas (a, b)
        = Ps_2 (PDatas a) (PDatas b)

-- Operators on arrays of tuples.
--   These are here instead of in "Data.Array.Parallel.PArray.Base" because
--   they need to know about the P_2 P_3 constructors. These are the representations
--   of tuple constructors that are generated by $(tupleInstances) above.
zipPA# :: PArray a -> PArray b -> PArray (a ,b)
{-# INLINE_PA zipPA# #-}
zipPA# (PArray n# xs) (PArray _ ys)
  = PArray n# (P_2 xs ys)

unzipPA# :: PArray (a, b) -> (PArray a, PArray b)
{-# INLINE_PA unzipPA# #-}
unzipPA# (PArray n# (P_2 xs ys))
  = (PArray n# xs, PArray n# ys)

zip3PA# :: PArray a -> PArray b -> PArray c -> PArray (a, b, c)
{-# INLINE_PA zip3PA# #-}
zip3PA# (PArray n# xs) (PArray _ ys) (PArray _ zs)
  = PArray n# (P_3 xs ys zs)

unzip3PA# :: PArray (a, b, c) -> (PArray a, PArray b, PArray c)
{-# INLINE_PA unzip3PA# #-}
unzip3PA# (PArray n# (P_3 xs ys zs))
  = (PArray n# xs, PArray n# ys, PArray n# zs)


zip4PA# :: PArray a -> PArray b -> PArray c -> PArray d -> PArray (a, b, c, d)
{-# INLINE_PA zip4PA# #-}
zip4PA# (PArray n# xs) (PArray _ ys) (PArray _ zs) (PArray _ as)
  = PArray n# (P_4 xs ys zs as)

unzip4PA# :: PArray (a, b, c, d) -> (PArray a, PArray b, PArray c, PArray d)
{-# INLINE_PA unzip4PA# #-}
unzip4PA# (PArray n# (P_4 ws xs ys zs))
   = (PArray n# ws, PArray n# xs, PArray n# ys, PArray n# zs)

zip5PA# :: PArray a -> PArray b -> PArray c -> PArray d -> PArray e -> PArray (a, b, c, d, e)
{-# INLINE_PA zip5PA# #-}
zip5PA# (PArray n# xs) (PArray _ ys) (PArray _ zs) (PArray _ as) (PArray _ bs)
  = PArray n# (P_5 xs ys zs as bs)

unzip5PA# :: PArray (a, b, c, d, e) -> (PArray a, PArray b, PArray c, PArray d, PArray e)
{-# INLINE_PA unzip5PA# #-}
unzip5PA# (PArray n# (P_5 vs ws xs ys zs))
  = (PArray n# vs, PArray n# ws, PArray n# xs, PArray n# ys, PArray n# zs)

zip6PA# :: PArray a -> PArray b -> PArray c -> PArray d -> PArray e -> PArray f -> PArray (a, b, c, d, e, f)
{-# INLINE_PA zip6PA# #-}
zip6PA# (PArray n# xs) (PArray _ ys) (PArray _ zs) (PArray _ as) (PArray _ bs) (PArray _ cs)
  = PArray n# (P_6 xs ys zs as bs cs)

unzip6PA# :: PArray (a, b, c, d, e, f) -> (PArray a, PArray b, PArray c, PArray d, PArray e, PArray f)
{-# INLINE_PA unzip6PA# #-}
unzip6PA# (PArray n# (P_6 us vs ws xs ys zs))
  = (PArray n# us, PArray n# vs, PArray n# ws, PArray n# xs, PArray n# ys, PArray n# zs)


zip7PA# :: PArray a -> PArray b -> PArray c -> PArray d -> PArray e -> PArray f -> PArray g ->
  PArray (a, b, c, d, e, f, g)
{-# INLINE_PA zip7PA# #-}
zip7PA# (PArray n# xs) (PArray _ ys) (PArray _ zs) (PArray _ as) (PArray _ bs) (PArray _ cs) (PArray _ ds)
  = PArray n# (P_7 xs ys zs as bs cs ds)

unzip7PA# :: PArray (a, b, c, d, e, f, g) -> (PArray a, PArray b, PArray c, PArray d, PArray e, PArray f, PArray g)
{-# INLINE_PA unzip7PA# #-}
unzip7PA# (PArray n# (P_7 ts us vs ws xs ys zs))
  = (PArray n# ts, PArray n# us, PArray n# vs, PArray n# ws, PArray n# xs, PArray n# ys, PArray n# zs)

zip8PA# :: PArray a -> PArray b -> PArray c -> PArray d -> PArray e -> PArray f -> PArray g -> PArray h ->
  PArray (a, b, c, d, e, f, g, h)
{-# INLINE_PA zip8PA# #-}
zip8PA# (PArray n# xs) (PArray _ ys) (PArray _ zs) (PArray _ as) (PArray _ bs) (PArray _ cs) (PArray _ ds) (PArray _ es)
  = PArray n# (P_8 xs ys zs as bs cs ds es)

unzip8PA# :: PArray (a, b, c, d, e, f, g, h) -> (PArray a, PArray b, PArray c, PArray d, PArray e, PArray f, PArray g, PArray h)
{-# INLINE_PA unzip8PA# #-}
unzip8PA# (PArray n# (P_8 ss ts us vs ws xs ys zs))
  = (PArray n# ss, PArray n# ts, PArray n# us, PArray n# vs, PArray n# ws, PArray n# xs, PArray n# ys, PArray n# zs)


-- Sums -----------------------------------------------------------------------
data instance PData (Sum2 a b)
        = PSum2 U.Sel2 (PData a) (PData b)

data instance PDatas (Sum2 a b)
        = PSums2 Sels2 (PDatas a) (PDatas b)

type Sels2 = ()

instance (PR a, PR b) => PR (Sum2 a b) where 
  {-# INLINE emptyPR #-}
  emptyPR
    = traceFn "emptyPR" "(Sum2 a b)" $
    PSum2 (U.mkSel2 U.empty U.empty 0 0 (U.mkSelRep2 U.empty)) emptyPR emptyPR

  {-# INLINE replicatePR #-}
  replicatePR n# (Alt2_1 x)
    = traceFn "replicatePR" "(Sum2 a b)" $
      PSum2 (U.mkSel2 (U.replicate (I# n#) 0)
                      (U.enumFromStepLen 0 1 (I# n#))
                      (I# n#) 0
                      (U.mkSelRep2 (U.replicate (I# n#) 0)))
            (replicatePR n# x)
            emptyPR
  replicatePR n# (Alt2_2 x)
    = traceFn "replicatePR" "(Sum2 a b)" $
      PSum2 (U.mkSel2 (U.replicate (I# n#) 1)
                      (U.enumFromStepLen 0 1 (I# n#))
                      0 (I# n#)
                      (U.mkSelRep2 (U.replicate (I# n#) 1)))
            emptyPR
            (replicatePR n# x)

  {-# INLINE replicatelPR #-}
  replicatelPR segd (PSum2 sel as bs)
    = traceFn "replicatelPR" "(Sum2 a b)" $
      PSum2 sel' as' bs'
    where
      tags      = U.tagsSel2 sel
      tags'     = U.replicate_s segd tags
      sel'      = U.tagsToSel2 tags'

      lens      = U.lengthsSegd segd

      asegd     = U.lengthsToSegd (U.packByTag lens tags 0)
      bsegd     = U.lengthsToSegd (U.packByTag lens tags 1)

      as'       = replicatelPR asegd as
      bs'       = replicatelPR bsegd bs

  {-# INLINE repeatPR #-}
  repeatPR m# n# (PSum2 sel as bs)
    = traceFn "repeatPR" "(Sum2 a b)" $
      PSum2 sel' as' bs'
    where
      sel' = U.tagsToSel2
           . U.repeat (I# m#) (I# n#)
           $ U.tagsSel2 sel

      as'  = repeatPR m# (elementsSel2_0# sel) as
      bs'  = repeatPR n# (elementsSel2_1# sel) bs

  {-# INLINE indexPR #-}
  indexPR (PSum2 sel as bs) i#
    = traceFn "indexPR" "(Sum2 a b)" $
    case U.index "indexPR[Sum2]" (U.indicesSel2 sel) (I# i#) of
      I# k# -> case U.index "indexPR[Sum2]" (U.tagsSel2 sel) (I# i#) of
                 0 -> Alt2_1 (indexPR as k#)
                 _ -> Alt2_2 (indexPR bs k#)

  {-# INLINE appPR #-}
  appPR (PSum2 sel1 as1 bs1)
                     (PSum2 sel2 as2 bs2)
    = traceFn "appPR" "(Sum2 a b)" $           
      PSum2 sel (appPR as1 as2)
                (appPR bs1 bs2)
    where
      sel = U.tagsToSel2
          $ U.tagsSel2 sel1 U.+:+ U.tagsSel2 sel2

  {-# INLINE packByTagPR #-}
  packByTagPR (PSum2 sel as bs) _ tags t#
    = PSum2 sel' as' bs'
    where
      my_tags  = U.tagsSel2 sel
      my_tags' = U.packByTag my_tags tags (intToTag (I# t#))
      sel'     = U.tagsToSel2 my_tags'

      atags    = U.packByTag tags my_tags 0
      btags    = U.packByTag tags my_tags 1

      as'      = packByTagPR as (elementsSel2_0# sel') atags t#
      bs'      = packByTagPR bs (elementsSel2_1# sel') btags t#

  {-# INLINE combine2PR #-}
  combine2PR _ sel (PSum2 sel1 as1 bs1)
                                 (PSum2 sel2 as2 bs2)
    = traceFn "combine2PR" "(Sum2 a b)" $
      PSum2 sel' as bs
    where
      tags  = U.tagsSel2 sel
      tags' = U.combine2 (U.tagsSel2 sel) (U.repSel2 sel)
                                          (U.tagsSel2 sel1)
                                          (U.tagsSel2 sel2)
      sel'  = U.tagsToSel2 tags'

      asel = U.tagsToSel2 (U.packByTag tags tags' 0)
      bsel = U.tagsToSel2 (U.packByTag tags tags' 1)

      as   = combine2PR (elementsSel2_0# sel') asel as1 as2
      bs   = combine2PR (elementsSel2_1# sel') bsel bs1 bs2


-- Nested Arrays --------------------------------------------------------------
data instance PData (PArray a)
        = PNested U.Segd (PData a)

instance PR a => PR (PArray a) where
  {-# INLINE emptyPR #-}
  emptyPR = traceFn "emptyPR" "(PArray a)" $
          PNested (U.mkSegd U.empty U.empty 0) emptyPR

  {-# INLINE replicatePR #-}
  replicatePR n# (PArray m# xs)
    = traceFn "replicatePR" "(PArray a)" $
    PNested (U.mkSegd (U.replicate (I# n#) (I# m#))
                      (U.enumFromStepLen 0 (I# m#) (I# n#))
                      (I# n# * I# m#))
            (repeatPR n# m# xs)

  {-# INLINE indexPR #-}
  indexPR (PNested segd xs) i#
    = traceFn "indexPR" "(PArray a)" $
      case U.index "indexPR[Nested]" (U.lengthsSegd segd) (I# i#) of { I# n# ->
      case U.index "indexPR[Nested]" (U.indicesSegd segd) (I# i#) of { I# k# ->
      PArray n# (extractPR xs k# n#) }}

  {-# INLINE extractPR #-}
  extractPR (PNested segd xs) i# n#
    = traceFn "extractPR" "(PArray a)" $
      PNested segd' (extractPR xs k# (elementsSegd# segd'))
    where
      segd' = U.lengthsToSegd
            $ U.extract (U.lengthsSegd segd) (I# i#) (I# n#)

      -- NB: not indicesSegd segd !: i because i might be one past the end
      !(I# k#) | I# i# == 0 = 0
               | otherwise  = U.index "extractPR[Nested]" (U.indicesSegd segd) (I# i# - 1)
                            + U.index "extractPR[Nested]" (U.lengthsSegd segd) (I# i# - 1)

  {-# INLINE bpermutePR #-}
  bpermutePR (PNested segd xs) _ is
    = traceFn "bpermutePR" "(PArray a)" $
      PNested segd' (bpermutePR xs (elementsSegd# segd') js)
    where
      lens'  = U.bpermute (U.lengthsSegd segd) is
      starts = U.bpermute (U.indicesSegd segd) is

      segd'  = U.lengthsToSegd lens'

      js     = U.zipWith (+) (U.indices_s segd')
                             (U.replicate_s segd' starts)

  {-# INLINE appPR #-}
  appPR (PNested xsegd xs) (PNested ysegd ys)
    = traceFn "appPR" "(PArray a)" $             
      PNested (U.lengthsToSegd (U.lengthsSegd xsegd U.+:+ U.lengthsSegd ysegd))
              (appPR xs ys)

  {-# INLINE applPR #-}
  applPR rsegd segd1 (PNested xsegd xs) segd2 (PNested ysegd ys)
    = traceFn "applPR" "(PArray a)"$
      PNested segd (applPR (U.plusSegd xsegd' ysegd') xsegd' xs ysegd' ys)
    where
      segd = U.lengthsToSegd
           $ U.append_s rsegd segd1 (U.lengthsSegd xsegd)
                              segd2 (U.lengthsSegd ysegd)

      xsegd' = U.lengthsToSegd
             $ U.sum_s segd1 (U.lengthsSegd xsegd)
      ysegd' = U.lengthsToSegd
             $ U.sum_s segd2 (U.lengthsSegd ysegd)

  {-# INLINE repeatPR #-}
  repeatPR n# len# (PNested segd xs)
    = traceFn "repeatPR" "(PArray a)" $
    PNested segd' (repeatPR n# (elementsSegd# segd) xs)
    where
      segd' = U.lengthsToSegd (U.repeat (I# n#) (I# len#) (U.lengthsSegd segd))

  {-# INLINE replicatelPR #-}
  replicatelPR segd (PNested xsegd xs)
    = traceFn "replicatelPR" "(PArray a)" $
    PNested xsegd' $ bpermutePR xs (elementsSegd# xsegd')
                   $ U.enumFromStepLenEach (U.elementsSegd xsegd')
                          is (U.replicate (U.elementsSegd segd) 1) ns
    where
      is = U.replicate_s segd (U.indicesSegd xsegd)
      ns = U.replicate_s segd (U.lengthsSegd xsegd)
      xsegd' = U.lengthsToSegd ns

  {-# INLINE packByTagPR #-}
  packByTagPR (PNested segd xs) _ tags t#
    = traceFn "packByTagPR" "(PArray a)" $
      PNested segd' xs'
    where
      segd' = U.lengthsToSegd
            $ U.packByTag (U.lengthsSegd segd) tags (intToTag (I# t#))

      xs'   = packByTagPR xs (elementsSegd# segd') (U.replicate_s segd tags) t#

  {-# INLINE combine2PR #-}
  combine2PR _ sel (PNested xsegd xs) (PNested ysegd ys)
    = traceFn "combine2PR" "(PArray a)" $
    PNested segd xys
    where
      tags = U.tagsSel2 sel

      segd = U.lengthsToSegd
           $ U.combine2 (U.tagsSel2 sel) (U.repSel2 sel)
                                         (U.lengthsSegd xsegd)
                                         (U.lengthsSegd ysegd)

      sel' = U.tagsToSel2
           $ U.replicate_s segd tags

      xys  = combine2PR (elementsSegd# segd) sel' xs ys


-- Operators on Nested Arrays
--  These are here instead of in "Data.Array.Parallel.PArray.Base" because
--  they need to know about the PNested constructor which is defined above.

-- | O(1). Extract the segment descriptor from a nested array.
segdPA# :: PArray (PArray a) -> U.Segd
{-# INLINE_PA segdPA# #-}
segdPA# (PArray _ (PNested segd _))
  = segd


-- | O(1). Concatenate a nested array. This is a constant time operation as
--         we can just discard the segment descriptor.
concatPA# :: PArray (PArray a) -> PArray a
{-# INLINE_PA concatPA# #-}
concatPA# (PArray _ (PNested segd xs))
  = PArray (elementsSegd# segd) xs


-- | O(1). Create a nested array from an element count, segment descriptor,
--         and data elements.
segmentPA# :: Int# -> U.Segd -> PArray a -> PArray (PArray a)
{-# INLINE_PA segmentPA# #-}
segmentPA# n# segd (PArray _ xs)
  = PArray n# (PNested segd xs)


-- | O(1). Create a nested array by using the element count and segment
--         descriptor from another, but use new data elements.
copySegdPA# :: PArray (PArray a) -> PArray b -> PArray (PArray b)
{-# INLINE copySegdPA# #-}
copySegdPA# (PArray n# (PNested segd _)) (PArray _ xs)
  = PArray n# (PNested segd xs)
