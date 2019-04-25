module STCR2Z1T0Edge where

import           Data.Array.Repa         as R
import           Data.Binary             (decodeFile)
import           Data.Complex
import           Data.List               as L
import           DFT.Plan
import           Filter.Utils
import           FokkerPlanck.MonteCarlo
import           FokkerPlanck.Pinwheel
import           Image.Edge
import           Image.IO
import           STC.PowerMethod
import           STC.PointSet
import           System.Directory
import           System.Environment
import           System.FilePath
import           Types


main = do
  args@(numPointStr:numOrientationStr:sigmaStr:taoStr:lenStr:initialScaleStr:numTrailStr:maxTrailStr:theta0FreqsStr:thetaFreqsStr:histFilePath:pinwheelFlagStr:numIterationStr:writeSourceFlagStr:edgeFilePath:numThreadStr:_) <-
    getArgs
  print args
  let numPoint = read numPointStr :: Int
      numOrientation = read numOrientationStr :: Int
      sigma = read sigmaStr :: Double
      tao = read taoStr :: Double
      len = read lenStr :: Int
      initialScale = read initialScaleStr :: Double
      numTrail = read numTrailStr :: Int
      maxTrail = read maxTrailStr :: Int
      theta0Freq = read theta0FreqsStr :: Double
      theta0Freqs = [-theta0Freq .. theta0Freq]
      thetaFreq = read thetaFreqsStr :: Double
      thetaFreqs = [-thetaFreq .. thetaFreq]
      pinwheelFlag = read pinwheelFlagStr :: Bool
      numIteration = read numIterationStr :: Int
      writeSourceFlag = read writeSourceFlagStr :: Bool
      numThread = read numThreadStr :: Int
      folderPath = "output/test/STCR2Z1T0Edge"
  createDirectoryIfMissing True folderPath
  flag <- doesFileExist histFilePath
  radialArr <-
    if flag
      then R.map magnitude . getNormalizedHistogramArr <$>
           decodeFile histFilePath
      else do
        putStrLn "Couldn't find a Green's function data. Start simulation..."
        solveMonteCarloR2Z1T0Radial
          numThread
          numTrail
          maxTrail
          numPoint
          numPoint
          sigma
          tao
          1
          theta0Freqs
          thetaFreqs
          histFilePath
          (emptyHistogram
             [ (round . sqrt . fromIntegral $ 2 * (div numPoint 2) ^ 2)
             , L.length theta0Freqs
             , L.length thetaFreqs
             ]
             0)
  arrR2Z1T0 <-
    computeUnboxedP $
    computeR2Z1T0ArrayRadial
      radialArr
      numPoint
      numPoint
      1.5
      thetaFreqs
      theta0Freqs
  plan <- makeR2Z1T0Plan emptyPlan arrR2Z1T0
  xs <- parseEdgeFile edgeFilePath
  randomPonintSet <- generateRandomPointSet 40 numPoint numPoint
  let ys =
        L.map
          (\(R2S1RPPoint (a, b, c, d)) -> (R2S1RPPoint (a - 150, b - 150, c, d)))
          xs
      zs =
        L.map
          (\(R2S1RPPoint (a, b, c, d)) ->
             (R2S1RPPoint (a - center numPoint, b - center numPoint, c, d)))
          randomPonintSet
      points = ys L.++ zs
  let bias = computeBiasR2T0 numPoint numPoint theta0Freqs points
      eigenVec =
        computeInitialEigenVectorR2T0
          numPoint
          numPoint
          theta0Freqs
          thetaFreqs
          points
  powerMethod1
    plan
    folderPath
    numPoint
    numPoint
    numOrientation
    thetaFreqs
    theta0Freqs
    arrR2Z1T0
    numIteration
    writeSourceFlag
    ""
    0.5
    bias
    eigenVec

