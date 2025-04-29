module Main where
import StatsTests (statsTests)
import ModelTests (modelTests)
import Test.HUnit ( runTestTTAndExit, Test(TestList) )

tests :: Test
tests = TestList 
    [ statsTests
    , modelTests ]

main :: IO ()
main = runTestTTAndExit tests