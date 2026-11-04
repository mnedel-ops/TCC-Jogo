#!/bin/sh
# Run from the repo root, after `git apply cleanup.patch`
git rm -f tcc-jogo/tcc-combat01.exe tcc-jogo/tcc-combat01.console.exe tcc-jogo/tcc-combat01.pck \
         tcc-jogo/tcc-jogo.exe tcc-jogo/tcc-jogo.console.exe tcc-jogo/tcc-jogo.pck \
         "concept/muleke/muleke-concept.kra~"
