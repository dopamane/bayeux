module Main where

import Bayeux
import Options.Applicative

main :: IO ()
main = app =<< execParser opts

opts :: ParserInfo Cli
opts = info (parseCli <**> helper)
            (mconcat
              [ fullDesc
              , progDesc "Bayeux language /\\ prover"
              , header "bx => command-line interface"
              ])

parseCli :: Parser Cli
parseCli = Cli <$> parseInput

parseInput :: Parser Input
parseInput = parseFileInput <|> parseStdInput

parseFileInput :: Parser Input
parseFileInput = FileInput <$> strOption
  (  long "file"
  <> short 'f'
  <> metavar "FILENAME"
  <> help "Input file" )

parseStdInput :: Parser Input
parseStdInput = flag' StdInput
  (  long "stdin"
  <> help "Read from stdin" )
