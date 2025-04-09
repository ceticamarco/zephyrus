module StatsTests where

import Test.HUnit ( (~:), (~=?), Test(TestLabel, TestList) )
import Statistics (mean, stdDev, median, mode, robustZScore)

testMean :: Test
testMean = TestList [
    "Empty list" ~: 0 ~=? mean [],
    "Single element" ~: 5.0 ~=? mean [5.0],
    "Multiple elements" ~: 2.8499999999999996 ~=? mean [5.0, -4.2, 3.4, 7.2]
    ]

testStdDev :: Test
testStdDev = TestList [
    "Empty list" ~: 0 ~=? stdDev [],
    "Single element" ~: 0 ~=? stdDev [5.0],
    "Multiple elements" ~: 4.288064831599448 ~=? stdDev [5.0, -4.2, 3.4, 7.2]
    ]

testMedian :: Test
testMedian = TestList [
    "Empty list" ~: 0 ~=? median [],
    "Single element" ~: 5.0 ~=? median [5.0],
    "Multiple elements(even)" ~: 4.2 ~=? median [5.0, -4.2, 3.4, 7.2],
    "Multiple elements(odd)" ~: 3.4 ~=? median [5.0, -4.2, 1.4, 3.4, 7.2]
    ]
    
testMode :: Test
testMode = TestList [
    "Empty list" ~: 0 ~=? mode [],
    "Single element" ~: 5.0 ~=? mode [5.0],
    "Unique modes" ~: 2.0 ~=? mode [1.0, 2.0, 2.0, 3.0],
    "Multi-modal" ~: 3.0 ~=? mode [1.0, 1.0, 2.0, 3.0, 3.0]
    ]

-- (roughly)Binomial dataset representing normal
-- (ie without anomalies) temperatures
normalTemps :: [Double]
normalTemps = [
    18.0, 19.0, 19.0, 20.0, 20.0, 20.0, 21.0, 21.0, 21.0, 21.0,
    22.0, 22.0, 22.0, 22.0, 22.0, 23.0, 23.0, 23.0, 24.0, 24.0
    ]

testRobustZScore :: Test
testRobustZScore = TestList [
    "Empty List" ~:
        [] ~=? robustZScore [],
    
    "Single Element" ~:
        [] ~=? robustZScore [20.0],

    "Temperatures without anomalies" ~:
        [] ~=? robustZScore normalTemps,

    "High anomaly" ~:
        [(20, 40.0)] ~=? robustZScore (normalTemps ++ [40.0]), -- 🥵

    "Low anomaly" ~:
        [(20, -5.0)] ~=? robustZScore (normalTemps ++ [-5.0]) -- 🥶
    ]

statsTests :: Test
statsTests = TestList
    [ TestLabel "Mean Tests" testMean
    , TestLabel "Standard Deviation Tests" testStdDev
    , TestLabel "Median Tests" testMedian
    , TestLabel "Mode Tests" testMode 
    , TestLabel "Robust Z-Score Tests" testRobustZScore
    ]