#!/usr/bin/env bash
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
while pgrep -f "KRITIK-5a2/batch1.sh" > /dev/null; do sleep 20; done
$K/batch2.sh > $K/logs/batch2.out 2>&1
$K/ab_all.sh $K/ab "pa:high:12 am:high:12 br:high:12 ly:high:12 be:high:12 pa:high:22 am:high:22 be:high:22 br:medium:19.5 ly_out:high:12 am_out:high:12"
