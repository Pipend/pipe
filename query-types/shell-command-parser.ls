{Obj, Str, id, any, concat-map, drop, each, empty, filter, find, foldr1, foldl, map, maximum, minimum, obj-to-pairs, pairs-to-obj, sort, sum, tail, take, unique} = require \prelude-ls

is-digit = (c) -> 48 <= (c.char-code-at 0) <= 57
 
is-space = (c) -> code = c.char-code-at 0 ; [9, 10, 32] |> any (== code)

is-lower-letter = (c) -> 
    return false if !c
    code = c.char-code-at 0 ; code >= 97 and code <= 122

is-upper-letter = (c) -> code = c.char-code-at 0 ; code >= 65 and code <= 90
 
funor = (f, g) --> (s) ->
    f s or g s

# the argument of parse-digit, parse-pint and parse-decimal must be a valid parsable string
parse-signed-number = (parser, cs) -->
  [sign, cs] = match cs.0
    | "-" => [-1, tail cs]
    | "+" => [1, tail cs]
    | _   => [1, cs]
 
  sign * (parser cs)
 
parse-digit = (c) -> (c.char-code-at 0) - 48
 
parse-pint = (cs) -> match cs
  | ""  => 0
  | _   => (parse-digit cs.0) * (10^(cs.length - 1)) + parse-pint (tail cs)
 
parse-int = parse-signed-number parse-pint
 
parse-pdecimal = (cs) -> 
  [hs, ds] = cs.split "."
  (parse-pint hs) + (fix (next) -> (i, cs) -> match cs
    | "" => 0
    | _  => (parse-digit cs.0) * (10^(-1 * i)) + next i+1, (tail cs))(1, ds)
 
parse-decimal = parse-signed-number parse-pdecimal
 
# alias Parser a = (String -> [(a, String)])
 
# executes parser p on string s
# parse :: Parser a -> String -> [(a, String)]
parse = (p, s) --> p s
 
# parser monad unit
# unit :: a -> Parser a
unit = (v) -> (s) -> [[v, s]]
 
# parser monad bind
# bind :: Parser a -> (a -> Parser b) -> Parser b
bind = (p, f) --> (s) ->
  (parse p, s)
    |> concat-map ([a, r]:list) -> 
      if (empty list) then [] else parse (f a), r
 
 
# tries parser p if failed tries q
# por :: Parser a -> Parser a -> Parser a
por = (p, q) --> (s) ->
  r = parse p, s
  r = parse q, s if empty r
  r
 
# runs parser p 0+ times
# many :: Parser a -> Parser [a]
many = (p) ->
  (many1 p) `por` (unit [])
 
# runs parser p 1+ times
# many1 :: Parser a -> Parser [a]
many1 = (q) ->
  a <- bind q
  as <- bind <| many q
  unit <| if ('String' == typeof! a) then (a + as) else ([a] ++ as)
 
# matches the first character of string s
# item :: Parser Char
item = (s) -> match s
  | "" => []
  | _  => [[s.0, tail s]]
 
# always fails (equal to mzero)
# failure :: Parser a
failure = (_) -> []
 
# checks and returns the character if the it matches the predicate f, returns failure otherwise
# sat :: (Char -> Bool) -> Parser Char
sat = (f) ->
  c <- bind item
  if (f c) then (unit c) else failure
 
# is character a digit
# digit :: Parser Cjar
digit = sat is-digit
 
# is the string a series of digits
# digits :: Parser String
digits = many1 digit
 
# checks if the character is matching the given character
# char :: Char -> Parser Char
char = sat . (==)

# matches every char but the given
# not-char :: Char -> Parser Char
not-char = sat . (!=)

# matches every char but the given ones
# not-chars :: [Char] -> Parser Char
not-chars = (xs) -> sat (-> it not in xs)

# matches lower case or capital case letters
# letter :: Parser Char
letter = sat <| is-lower-letter `funor` is-upper-letter
 
# checks if the string is matching the given string
# note here: "" == [] and c + cs == c ++ cs
# string :: String -> Parser String
string = (s) -> match s
  | "" => unit ""
  | _  => 
    c  <- bind <| char s.0
    cs <- bind <| string (tail s)
    unit (c + cs)
 
# is it a series of spaces
# space :: Parser String
space = many <| sat is-space

space1 = many1 <| sat is-space
 
 
signed-numeral = (parser) ->
  ((char '-') `bind` (-> parser) `bind` (unit . ('-' +))) `por` parser
 
 
integer = signed-numeral digits
 
# is it a decimal
# decimal :: Parser String
pdecimal = do ->
  hs <- bind digits
  _ <- bind <| char '.'
  ds <- bind digits
  unit <| hs + "." + ds
 
decimal = signed-numeral pdecimal

 
# signed decimal or digit
# number :: Parser String
number = decimal `por` integer


un-signed-number-with-units = do ->
  n <- bind number
  u <- bind letter
  unit <| n + u
 
# token: "token   "
# token :: Parser a -> Parser a
token = (p) ->
  a <- bind p
  _ <- bind space
  unit a
  
 
word = do ->
  l <- bind letter
  ds <- bind <| many (
    n <- bind <| not-chars [' ', '\n', '\r', '>', '<', '|']
    unit n
  )
  unit l + ds
  
  
non-quoted-string = do ->
    many <| (do ->
        _ <- bind <| string '\\"'
        not-chars [\", '`'] # disable sub commands
    ) `por` (not-chars [\", '`'])
    
quoted-string = do ->
    _ <- bind <| char \"
    str <- bind non-quoted-string
    _ <- bind <| char \"
    unit "\"#str\""
    #unit str
    
any-string = quoted-string `por` non-quoted-string


split-by-space = do ->
    arr <- bind <| many <| do ->
        str <- bind <| many <| not-char ' '
        _ <- bind <| many1 <| char ' '
        unit [str]
    l <- bind <| many <| not-char ' '
    unit <| arr ++ [l] |> concat-map id |> concat-map id
    
 
# symb: a token that is matching the given string
# symb :: String -> Parser String
symb = token . string
 
# parses a series infix operator op.
# it ends with the last lhs (that is the rhs of the last operator in the chain)
# chainl1 :: Parser a -> Parser (a -> a -> a) -> Parser a
chainl1 = (p, op) -->
  a <- bind p
  rest = (a) -> (do ->
    f <- bind <| op
    b <- bind p
    rest (a `f` b)) `por` (unit a)
  rest a
  
# decimals and integers have different parsers
# fnumber :: Parser Number
fnumber = (token decimal `bind` (unit . parse-decimal)) `por` (token integer `bind` (unit . parse-int))

one-letter-shell-opt = do ->
    _ <- bind <| char '-'
    name <- bind letter
    unit [{name}]
    
many-one-letter-shell-opt = do ->
    [{name:l}] <- bind one-letter-shell-opt
    name <- bind (many1 letter)
    unit <| ((l + name).split '') |> map (-> name: it)
    
many-one-letter-shell-opt-with-value = do ->
    names <- bind token many-one-letter-shell-opt
    value <- bind (quoted-string `por` word `por` un-signed-number-with-units `por` number)
    unit <| (initial names) ++ [{name: (last names).name, value: value}]

shell-opt = do ->
    _ <- bind <| string '--'
    name <- bind word
    unit [{name}]
    

shell-opt-with-value = do ->
    [{name}] <- bind token (one-letter-shell-opt `por` shell-opt)
    value <- bind (quoted-string `por` word `por` un-signed-number-with-units `por` number)
    unit [{name, value}]
    
many-shell-opts = do ->
    args <- bind <| many <| do ->
        token (many-one-letter-shell-opt-with-value `por` many-one-letter-shell-opt `por` shell-opt-with-value `por` one-letter-shell-opt `por` shell-opt)
    unit <| concat-map id, args
    
shell-command = do ->
    cmd <- bind token word
    args <- bind (many <| do ->
        (do ->
            s <- bind <| token <| quoted-string `por` (many1 <| (not-chars [' ', '-', '`']))
            unit [opt: s]
        ) `por` (token (many-one-letter-shell-opt-with-value `por` many-one-letter-shell-opt `por` shell-opt-with-value `por` one-letter-shell-opt `por` shell-opt))
    )
    unit {cmd, args}

module.exports = {shell-command, parse}