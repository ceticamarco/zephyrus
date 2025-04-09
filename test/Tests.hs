module Main where
import StatsTests (statsTests)
import Test.HUnit ( runTestTTAndExit, Test(TestList) )

tests :: Test
tests = TestList [ statsTests ]

main :: IO ()
main = runTestTTAndExit tests