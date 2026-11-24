#!/bin/bash
# R7D: S1 and S3 again on the final head (e8c6f07) – to compare with the earlier head pictures (band fade in the shader)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D
O=$S/shots/head2
for p in S1 S3; do
	[ -f $O/${p}_high_modern_00.png ] && continue
	$S/sh/shot.sh head $O high 3 $p >> $S/logs/head2.log 2>&1
done
echo "HEAD2 DONE $(date +%T)" >> $S/logs/head2.log
