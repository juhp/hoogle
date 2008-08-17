
module Hoogle(hoogle) where

import Util

hoogle :: String -> IO ()
hoogle "keyword" = copyFile "temp/keyword/hoogle.txt" "result/keyword.txt"

hoogle name = do
    -- read the cabal info
    cabal <- liftM lines $ readFile $ "temp/" ++ name ++ "/" ++ name ++ ".cabal"

    -- rewrite with extra information
    src <- readFile $ "temp/" ++ name ++ "/hoogle.txt"

    -- '\r' because of haddock/cabal interactions going weird..
    let res = concatMap (f cabal) $ lines $ filter (/= '\r') src
        (res1,res2) = if name == "base" then splitGHC res else (res,[])

    writeFile ("result/" ++ name ++ ".txt") $ unlines res1
    when (res2 /= []) $ writeFile "result/ghc.txt" $ unlines $ ghcPrefix ++ res2
    where
        f cabal x
            | "@package" `isPrefixOf` x =
                [x] ++
                ["@version " ++ v2 | let v = cabalVersion cabal, v /= "",
                    let v2 = if name == "base" then "3.0.1.0" else v] ++
                ["@depends " ++ d | d <- cabalDepends cabal, d /= "rts"]
            | "@version" `isPrefixOf` x = []
            | otherwise = [x]


cabalVersion xs = head $ readFields "version" xs ++ [""]

cabalDepends xs = nub $ filter f $ words $ map (rep ',' ' ') $ unwords $ readFields "build-depends" xs
    where f x = x /= "" && isAlpha (head x)


readFields :: String -> [String] -> [String]
readFields name = f
    where
        f (x:xs) | (name ++ ":") `isPrefixOf` map toLower x2 =
                [x4 | x4 /= []] ++ map trim ys ++ f zs
            where
                x4 = trim x3
                x3 = drop (length name + 1) x2
                (spc,x2) = span isSpace x
                (ys,zs) = span ((> length spc) . length . takeWhile isSpace) xs
        f (x:xs) = f xs
        f [] = []


trim = reverse . ltrim . reverse . ltrim
ltrim = dropWhile isSpace


splitGHC :: [String] -> ([String],[String])
splitGHC = f True
    where
        f pile xs | null b = add pile xs ([], [])
                  | otherwise = add pile2 (a++[b1]) $ f pile2 bs
            where
                pile2 = if not $ "module " `isPrefixOf` b1 then pile
                        else not $ "module GHC." `isPrefixOf` b1
                b1:bs = b
                (a,b) = span isComment xs

        add left xs (a,b) = if left then (xs++a,b) else (a,xs++b)
        isComment x = x == "--" || "-- " `isPrefixOf` x


ghcPrefix :: [String]
ghcPrefix =
    ["-- Hoogle documentation, generated by Hoogle"
    ,"-- The GHC.* modules of the base library"
    ,"-- See Hoogle, http://www.haskell.org/hoogle/"
    ,""
    ,"-- | GHC modules that are part of the base library"
    ,"@package base"
    ,"@version 3.0.1.0"
    ,""
    ]
