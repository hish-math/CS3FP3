module Law where

import Parser
import Expr

-------------------------------------------------------------------------------
-- | Laws
type LawName = String

data Law
  = Law
      LawName -- Name
      Expr -- LHS
      Expr -- RHS
  deriving (Eq)

instance Show Law where
  show (Law name lhs rhs) = name ++ ": " ++ show lhs ++ " = " ++ show rhs

-- | Basic laws are laws that has 
-- LHS expression has complexity > RHS expression's complexity
basicLaw :: Law -> Bool
basicLaw (Law _ lhs rhs) = countSymbols lhs > countSymbols rhs
  where 
    countSymbols (Var _) = 1
    countSymbols (Con _ es) = foldr (+) 1 (map countSymbols es)
    countSymbols (Compose es) = foldr (+) 1 (map countSymbols es)

eqn :: Parser (Expr, Expr)
eqn = do
  space
  x <- expr
  token (char '=')
  y <- expr
  return (x, y)

-- Try it out: parseEqn "fst . pair (f,g) = f"  -> (fst . pair(f, g) , f)
parseEqn :: String -> (Expr, Expr)
parseEqn = runParser eqn

-- | Parse a law
law :: Parser Law
law = do
  space
  name <- many (sat (/= ':'))
  token (char ':')
  (lhs, rhs) <- eqn
  return (Law name lhs rhs)

-- NOTE
-- parseLaw "name: left(side) = right.side"  -> name: left side = right . side
-- parseLaw "name: l(side) = r . side"  -> FAILED‼
-- Constants *must* be multi-letter names, in this case, `f` is 1 letter and can't be a constant function (to apply to `side`).
parseLaw :: String -> Law
parseLaw = runParser law

-- | Calculations
type Calculation = (Expr, [Step])

type Step = (LawName, Expr)

-- The conclusion of a calculation is the last expression in it.
-- (x, [(rule1, y1), …, (ruleN,yN)]) -> yN
-- (x, []) -> x
conclusion :: Calculation -> Expr
conclusion (x, steps) = if null steps then x else snd (last steps)

-- Insert an indication if the conclusions are not the same.
link :: Expr -> Expr -> [Step]
link x y = if x == y then [] else [("... ??? ...", y)]

-- Reverse a calculation: 
-- (x, [(r1, y1), …, (rN,yN)]) -> (yN, [(rN, yN-1), …, (r2, y1), (r1, x)])
-- (x, []) -> (x, [])
reverseCalc :: Calculation -> Calculation
reverseCalc (x, ss) = if null ss then (x, ss) else (snd (last ss), zip fsts snds)
  where fsts = reverse (map fst ss)
        snds = reverse (map snd (take (length ss - 1) ss)) ++ [x]

-- (snd (last ss), [ pair | pair <- zip a, a <- reverse (map fst ss), b <- reverse (map snd (take (length ss - 1) ss)) ++ [x]])
--  (snd (last ss), [(a, b) | (pair, i) <- zip ss [0..]] ++ [(fst (head ss), x)])

-- Paste two calculations together; the second being reversed.
-- Insert an indication if the conclusions are not the same.
-- Use `link` and `reverseCalc`
paste :: Calculation -> Calculation -> Calculation
paste l r = (fst l, snd l ++ link x y ++ snd (reverseCalc r))
  where
    (x, y) = (conclusion l, conclusion r)

printCalc :: Calculation -> String
printCalc (x, ss) = "\n  " ++ printExpr x ++ "\n" ++ concatMap printStep ss

printStep :: Step -> String
printStep (why, x) = "=  { " ++ why ++ " }\n  " ++ printExpr x ++ "\n"

