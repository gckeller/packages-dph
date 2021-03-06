{-# OPTIONS -Wall -fno-warn-orphans -fno-warn-missing-signatures #-}
{-# LANGUAGE CPP #-}
#include "fusion-phases.h"

-- | Distribution of Segment Descriptors
module Data.Array.Parallel.Unlifted.Distributed.Types.USSegd (
        lengthD,
        takeLengthsD,
        takeIndicesD,
        takeElementsD,
        takeStartsD,
        takeSourcesD,
        takeUSegdD
) where
import Data.Array.Parallel.Unlifted.Distributed.Types.Base
import Data.Array.Parallel.Unlifted.Sequential.USSegd                   (USSegd)
import Data.Array.Parallel.Unlifted.Sequential.USegd                    (USegd)
import Data.Array.Parallel.Unlifted.Sequential.Vector                   (Vector)
import Data.Array.Parallel.Pretty
import Control.Monad
import Prelude                                                          as P
import qualified Data.Array.Parallel.Unlifted.Distributed.Types.USegd   as DUSegd
import qualified Data.Array.Parallel.Unlifted.Distributed.Types.Vector  as DV
import qualified Data.Array.Parallel.Unlifted.Sequential.USSegd         as USSegd

instance DT USSegd where
  data Dist USSegd   
        = DUSSegd  !(Dist (Vector Int))         -- segment starts
                   !(Dist (Vector Int))         -- segment sources
                   !(Dist USegd)                -- distributed usegd

  data MDist USSegd s 
        = MDUSSegd !(MDist (Vector Int) s)      -- segment starts
                   !(MDist (Vector Int) s)      -- segment sources
                   !(MDist USegd        s)      -- distributed usegd

  indexD str (DUSSegd starts sources usegds) i
   = USSegd.mkUSSegd
        (indexD (str ++ "/indexD[USSegd]") starts i)
        (indexD (str ++ "/indexD[USSegd]") sources i)
        (indexD (str ++ "/indexD[USSegd]") usegds i)

  newMD g
   = liftM3 MDUSSegd (newMD g) (newMD g) (newMD g)

  readMD (MDUSSegd starts sources usegds) i
   = liftM3 USSegd.mkUSSegd (readMD starts i) (readMD sources i) (readMD usegds i)

  writeMD (MDUSSegd starts sources usegds) i ussegd
   = do writeMD starts  i (USSegd.takeStarts  ussegd)
        writeMD sources i (USSegd.takeSources ussegd)
        writeMD usegds  i (USSegd.takeUSegd   ussegd)

  unsafeFreezeMD (MDUSSegd starts sources usegds)
   = liftM3 DUSSegd (unsafeFreezeMD starts)
                    (unsafeFreezeMD sources)
                    (unsafeFreezeMD usegds)

  deepSeqD ussegd z
   = deepSeqD (USSegd.takeStarts  ussegd)
   $ deepSeqD (USSegd.takeSources ussegd)
   $ deepSeqD (USSegd.takeUSegd   ussegd) z

  sizeD  (DUSSegd  _ _ usegd) = sizeD usegd
  sizeMD (MDUSSegd _ _ usegd) = sizeMD usegd

  measureD ussegd 
   = "USSegd "  P.++ show (USSegd.takeStarts    ussegd)
   P.++ " "     P.++ show (USSegd.takeSources   ussegd)
   P.++ " "     P.++ measureD (USSegd.takeUSegd ussegd)


instance PprPhysical (Dist USSegd) where
 pprp (DUSSegd starts sources usegds)
  =  text "DUSSegd"
  $$ (nest 7 $ vcat
        [ text "starts:  " <+> pprp starts
        , text "sources: " <+> pprp sources
        , text "usegds:  " <+> pprp usegds])


-- | O(1). Yield the overall number of segments.
lengthD :: Dist USSegd -> Dist Int
{-# INLINE_DIST lengthD #-}
lengthD (DUSSegd starts _ _) 
        = DV.lengthD starts


-- | O(1). Yield the lengths of the individual segments.
takeLengthsD :: Dist USSegd -> Dist (Vector Int)
{-# INLINE_DIST takeLengthsD #-}
takeLengthsD (DUSSegd _ _ usegds)
        = DUSegd.takeLengthsD usegds


-- | O(1). Yield the segment indices.
takeIndicesD :: Dist USSegd -> Dist (Vector Int)
{-# INLINE_DIST takeIndicesD #-}
takeIndicesD (DUSSegd _ _ usegds)
        = DUSegd.takeIndicesD usegds


-- | O(1). Yield the number of data elements.
takeElementsD :: Dist USSegd -> Dist Int
{-# INLINE_DIST takeElementsD #-}
takeElementsD (DUSSegd _ _ usegds)
        = DUSegd.takeElementsD usegds


-- | O(1). Yield the starting indices.
takeStartsD :: Dist USSegd -> Dist (Vector Int)
{-# INLINE_DIST takeStartsD #-}
takeStartsD (DUSSegd starts _ _)
        = starts
        
-- | O(1). Yield the source ids
takeSourcesD :: Dist USSegd -> Dist (Vector Int)
{-# INLINE_DIST takeSourcesD #-}
takeSourcesD (DUSSegd _ sources _)
        = sources


-- | O(1). Yield the USegd
takeUSegdD :: Dist USSegd -> Dist USegd
{-# INLINE_DIST takeUSegdD #-}
takeUSegdD (DUSSegd _ _ usegd)
        = usegd

