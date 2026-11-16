#!/usr/bin/env bash
# QA-R5 queue 1: the pictures (one heavy job at a time).
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
S=$Q/tools/shots.sh
bash $S new u1_anfahrt u1_innen u1_ausfahrt u1_nacht kb_rampe kb_ende kb_top kb_nacht holtenau b1_koeln somport elbbruecken stein dev
# base: the places without a base picture of R5 (night, top) and two to compare with R5's base pictures
bash $S base u1_nacht kb_top kb_rampe u1_innen
# Steam Deck
PRESET=deck SCREEN=1280x800 SUFFIX=_deck bash $S new kb_nacht u1_innen kb_rampe
PRESET=deck SCREEN=1280x800 SUFFIX=_deck bash $S base kb_nacht u1_innen
echo QUEUE1_DONE
