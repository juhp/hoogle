
module Console.Search(actionSearch) where

import CmdLine.All
import Console.Files
import Data.Range
import Data.TagStr
import General.Code
import Hoogle.Query.All
import Hoogle.Search.All
import Hoogle.DataBase.All
import Hoogle.Item.All
import Data.Binary.Defer.Index


actionSearch :: [CmdFlag] -> Query -> IO ()
actionSearch flags q = do
    db <- getDataBaseFiles flags q
    when verbose $
        putStr $ unlines $ "= DATABASES =" : map ("  "++) db

    dbs <- mapM loadDataBase db
    let sug = suggestQuery dbs q
    when (isJust sug) $
        putStrLn $ showTag $ fromJust sug
    when verbose $ putStrLn "= ANSWERS ="

    when (isJust (typeSig q) && color) $ do
        let view = [ArgPosNum i i | i <- [0..10]]
            tags = renderEntryText view $ renderTypeSig $ fromJust $ typeSig q
        putStrLn $ "Searching for: " ++ showTag tags

    let res = search dbs q
    if null res then
        putStrLn "No results found"
     else if Info `elemEnum` flags then do
        let ent = fromLink $ resultEntry $ head res
            pkg = fromLink $ entryPackage ent
        putStrLns 2 $ f $ renderResult $ head res
        putStrLns 2 $ showTag $ renderHaddock $ entryDocs ent
        putStrLn $ "From package " ++ packageName pkg ++ ", version " ++ packageVersion pkg
        putStrLns 1 $ entryURL ent
     else
        putStr $ unlines $ map (f . renderResult) res
    where
        search | start == 0 && count == maxBound = searchAll
               | otherwise = searchRange (rangeStartCount start count)
            where start = headDef 0 [i-1 | Start i <- flags]
                  count = headDef maxBound [i | Count i <- flags]

        verbose = Verbose `elem` flags
        color = Color True `elem` flags
        showTag = if color then showTagConsole else showTagText

        f (m,r,v) = maybe "" (\m -> showModule m ++ " ") m ++
                    showTag r ++ (if verbose then "  -- " ++ v else "")


-- Put out a string with some blank links following
-- Do not put out the blank lines if no text output
putStrLns :: Int -> String -> IO ()
putStrLns n xs = when (xs /= "") $ do
                     putStr xs
                     putStr $ replicate n '\n'