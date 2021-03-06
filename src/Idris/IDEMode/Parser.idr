||| Slightly different lexer than the source language because we are more free
||| as to what can be identifiers, and fewer tokens are supported. But otherwise,
||| we can reuse the standard stuff
module Idris.IDEMode.Parser

import Idris.IDEMode.Commands

import Data.List
import Data.Strings
import Parser.Lexer.Source
import Parser.Source
import Text.Lexer
import Text.Parser
import Utils.Either
import Utils.String

%hide Text.Lexer.symbols
%hide Parser.Lexer.Source.symbols

symbols : List String
symbols = ["(", ":", ")"]

ideTokens : TokenMap Token
ideTokens =
    map (\x => (exact x, Symbol)) symbols ++
    [(digits, \x => IntegerLit (cast x)),
     (stringLit, \x => StringLit (stripQuotes x)),
     (identAllowDashes, \x => Ident x),
     (space, Comment)]

idelex : String -> Either (Int, Int, String) (List (TokenData Token))
idelex str
    = case lex ideTokens str of
           -- Add the EndInput token so that we'll have a line and column
           -- number to read when storing spans in the file
           (tok, (l, c, "")) => Right (filter notComment tok ++
                                      [MkToken l c EndInput])
           (_, fail) => Left fail
    where
      notComment : TokenData Token -> Bool
      notComment t = case tok t of
                          Comment _ => False
                          _ => True

sexp : Rule SExp
sexp
    = do symbol ":"; exactIdent "True"
         pure (BoolAtom True)
  <|> do symbol ":"; exactIdent "False"
         pure (BoolAtom False)
  <|> do i <- intLit
         pure (IntegerAtom i)
  <|> do str <- strLit
         pure (StringAtom str)
  <|> do symbol ":"; x <- unqualifiedName
         pure (SymbolAtom x)
  <|> do symbol "("
         xs <- many sexp
         symbol ")"
         pure (SExpList xs)

ideParser : {e : _} -> String -> Grammar (TokenData Token) e ty -> Either (ParseError Token) ty
ideParser str p
    = do toks   <- mapError LexFail $ idelex str
         parsed <- mapError toGenericParsingError $ parse p toks
         Right (fst parsed)


export
parseSExp : String -> Either (ParseError Token) SExp
parseSExp inp
    = ideParser inp (do c <- sexp; eoi; pure c)
