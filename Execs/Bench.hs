{- Copyright 2016-2018
 - Licence: MIT -}
import Criterion.Main


import qualified Data.Vector as V
import qualified Data.Conduit.List as CL
import qualified Data.Conduit.Binary as CB
import qualified Data.Conduit as C
import qualified Data.Text as T
import           Data.Conduit ((=$=), ($$))
import           Control.DeepSeq (NFData)

import Control.Monad.Trans.Resource (runResourceT)

import NGLess (NGLessIO, testNGLessIO)


import Interpretation.Count (performCount, MMMethod(..), loadFunctionalMap, CountOpts(..), annotationRule, AnnotationIntersectionMode(..), Annotator(..), NMode(..))
import Interpretation.Substrim (substrim)
import StandardModules.Parallel (pasteCounts)
import Interpret (interpret)
import FileOrStream (FileOrStream(..))
import Parse (parsengless)
import Language (Script(..))
import Data.Sam (readSamLine, readSamGroupsC, samStatsC)
import Data.FastQ (statsFromFastQ, FastQEncoding(..), ShortRead(..), fqDecodeVector)
import Utils.Conduit (linesC, ByteLine(..))
import Transform (transform)
import NGLess.NGLEnvironment (setupTestEnvironment)

nfNGLessIO :: (NFData a) => NGLessIO a -> Benchmarkable
nfNGLessIO = nfIO . testNGLessIO

nfNGLessScript :: T.Text -> Benchmarkable
nfNGLessScript sc = case parsengless "bench" False sc of
    Left err -> error (show err)
    Right expr -> nfNGLessIO $ interpret [] . nglBody $ expr

nfNGLessScriptWithTransform :: T.Text -> Benchmarkable
nfNGLessScriptWithTransform code = case parsengless "bench" False code of
    Left err -> error (show err)
    Right sc -> nfNGLessIO $ do
        sc' <- transform [] sc
        interpret [] (nglBody sc')


nfRIO = nfIO . runResourceT
countRights = loop (0 :: Int)
    where
        loop !i = C.await >>= \case
            Nothing -> return i
            Just (Right !_) -> loop (i+1)
            Just (Left !_) -> loop i

rightOrDie (Right r) = r
rightOrDie err = error $ "Expected Right, got: " ++ show err
exampleSR :: ShortRead
exampleSR = V.head . rightOrDie . fqDecodeVector SangerEncoding $ V.fromList
                [ByteLine "@SRR867735.1 HW-ST997:253:C16APACXX:7:1101:2971:1948/1"
                ,ByteLine "NCCGCTGCTCGGGATCAAGACATACCGCGGGGGGAGGGGAGCGGGACCAC"
                ,ByteLine "+"
                ,ByteLine "#11ABDD6DFBDFHEGHDDGFFFHE?@GEEGA##################"]


count= loop (0 :: Int)
    where
        loop !i = C.await >>= \case
            Nothing -> return i
            Just _ -> loop (i+1)

basicCountOpts = CountOpts
        { optFeatures = []
        , optSubFeatures = Nothing
        , optIntersectMode = annotationRule IntersectStrict
        , optStrandSpecific = False
        , optMinCount = 0.0
        , optMMMethod = MMDist1
        , optDelim = "\t"
        , optNormMode = NMRaw
        , optIncludeMinus1 = True
        }

main = setupTestEnvironment >> defaultMain [
    bgroup "sam-stats"
        [ bench "sample" $ nfNGLessIO (CB.sourceFile "test_samples/sample.sam" =$= linesC $$ samStatsC)
        ]
    ,bgroup "fastq"
        [ bench "fastqStats" $ nfNGLessIO (statsFromFastQ "test_samples/sample.fq.gz" SangerEncoding)
        , bench "preprocess" $ nfNGLessScript                          "p = fastq('test_samples/sample.fq.gz')\npreprocess(p) using |r|:\n  r = substrim(r, min_quality=26)\n  if len(r) < 45:\n    discard"
        , bench "preprocess-transformed" $ nfNGLessScriptWithTransform "p = fastq('test_samples/sample.fq.gz')\npreprocess(p) using |r|:\n  r = substrim(r, min_quality=26)\n  if len(r) < 45:\n    discard"
        , bench "preprocess-pair" $ nfNGLessScript
                "p = paired('test_samples/sample.fq.gz', 'test_samples/sample.fq.gz')\npreprocess(p) using |r|:\n  r = substrim(r, min_quality=26)\n"
        , bench "preprocess-pair-transformed" $ nfNGLessScriptWithTransform
                "p = paired('test_samples/sample.fq.gz', 'test_samples/sample.fq.gz')\npreprocess(p) using |r|:\n  r = substrim(r, min_quality=26)\n"
        , bench "preprocess-pair-nop" $ nfNGLessScriptWithTransform
                "p = paired('test_samples/sample.fq.gz', 'test_samples/sample.fq.gz')\npreprocess(p) using |r|:\n  r = r\n"
        , bench "substrim" $ nf (substrim 30) exampleSR
        ]
    ,bgroup "parse-sam"
        [ bench "readSamLine" $ nfRIO (CB.sourceFile "test_samples/sample.sam" =$= CB.lines =$= CL.map readSamLine $$ countRights)
        , bench "samGroups" $ nfNGLessIO (CB.sourceFile "test_samples/sample.sam" =$= linesC =$= readSamGroupsC $$ count)
        ]
    ,bgroup "count"
        [ bench "load-map"      $ nfNGLessIO (loadFunctionalMap "test_samples/functional.map" ["KEGG_ko", "eggNOG_OG"])
        , bench "annotate-seqname" . nfNGLessIO $ performCount (File "test_samples/sample.sam") "testing" [SeqNameAnnotator Nothing] basicCountOpts
        , bench "annotate-functionalmap" . nfNGLessIO $ do
                    amap <- loadFunctionalMap "test_samples/functional.map" ["KEGG_ko", "eggNOG_OG"]
                    performCount (File "test_samples/sample.sam") "testing" amap basicCountOpts
        ]
    ,bgroup "parallel"
        [ bench "paste-sparse"   $ nfNGLessIO (pasteCounts [] False ["sample" | _ <- [(0 :: Int)..127]]
                                                                ["test_samples/merge/sp_sample_"++show i | i <- [(0 :: Int)..127]])
        , bench "paste-dense"    $ nfNGLessIO (pasteCounts [] True ["sample" | _ <- [(0 :: Int)..127]]
                                                                ["test_samples/merge/sample_"++show i | i <- [(0 :: Int)..127]])
        ]
    ]
