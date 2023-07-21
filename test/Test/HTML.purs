module Test.HTML (testHTML) where

import Prelude

import Data.Hyperly (Transformer, transform)
import Data.Hyperly.DOM (getDocumentByNode)

import Data.String.Regex (Regex)
import Data.String.Regex.Unsafe (unsafeRegex)

import Test.Spec (Spec, describe)

import Test.Util
  (assertHypeHTML, giu, itEff)

import Web.DOM (Text)
import Web.DOM.Document (createTextNode)

havingBye :: Regex
havingBye = unsafeRegex "(?:(?:good)?bye|¡adiós|さよう?なら)" giu

translateByes :: Transformer Text
translateByes { node } _ = do
  doc <- getDocumentByNode node
  text <- createTextNode "Au revoir" doc
  pure text

testHTML :: Spec Unit
testHTML = describe "<html>, <head> and <body>" do

  itEff "<body> only" do
    transform
      havingBye
      translateByes
      """<BODY lang="fr">Goodbye! ¡adiós! Bye. <span>さようなら!</span> <em>さよなら.</em></BODY>"""
      >>= assertHypeHTML
      """<body lang="fr">Au revoir! Au revoir! Au revoir. <span>Au revoir!</span> <em>Au revoir.</em></body>"""
  
  itEff "<html> + <body>" do
    transform
      havingBye
      translateByes
      """<html lang="en" class="bye"><body lang="fr">Goodbye! ¡adiós! Bye. <span>さようなら!</span> <em>さよなら.</em></body></html>"""
      >>= assertHypeHTML
      """<html lang="en" class="bye"><head></head><body lang="fr">Au revoir! Au revoir! Au revoir. <span>Au revoir!</span> <em>Au revoir.</em></body></html>"""

  itEff "<html> + <head> + <body>" do
    transform
      havingBye
      translateByes
      """<html class="bye au-revoir"><head><style>.bye { color: #123456; }</style><script>alert('Goodbye.')</script></head><body lang="fr">Goodbye! ¡adiós! Bye. <span>さようなら!</span> <em>さよなら.</em></body></html>"""
      >>= assertHypeHTML
      """<html class="bye au-revoir"><head><style>.bye { color: #123456; }</style><script>alert('Goodbye.')</script></head><body lang="fr">Au revoir! Au revoir! Au revoir. <span>Au revoir!</span> <em>Au revoir.</em></body></html>"""

  itEff "Neither" do
    transform
      havingBye
      translateByes
      """
        <title>adiós, ¡adiós!</title>
        <style>.bye { color: #123456; }</style>
        <script>alert('Goodbye.')</script>

        <p>Goodbye! ¡adiós! Bye. <span>さようなら!</span> <em>さよなら.</em></p>
      """
      >>= assertHypeHTML
      """
        <title>adiós, ¡adiós!</title>
        <style>.bye { color: #123456; }</style>
        <script>alert('Goodbye.')</script>

        <p>Au revoir! Au revoir! Au revoir. <span>Au revoir!</span> <em>Au revoir.</em></p>
      """
