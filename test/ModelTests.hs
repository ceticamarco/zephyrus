{-# LANGUAGE OverloadedStrings #-}

module ModelTests where

import Test.HUnit ( (~:), (~=?), Test(TestLabel, TestList) )
import Model (getCardinalDir)

testCardinalDir :: Test
testCardinalDir = TestList [
    "bounded value" ~: ("ENE", "↙️") ~=? getCardinalDir 65.4,
    "out-of-bound value" ~: ("E", "⬅️") ~=? getCardinalDir 450.3,
    "negative value" ~: ("WNW", "↘️") ~=? getCardinalDir (-56.43)
    ]

modelTests :: Test
modelTests = TestList
    [ TestLabel "Cardinal Direction Converter Tests" testCardinalDir ]