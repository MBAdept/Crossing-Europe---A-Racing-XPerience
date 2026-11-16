#!/usr/bin/env bash
# AS2R: one round of the review's comparison renders (jobs/round/*.json -> out/tiles/<batch>), one batch after the other
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik
cd "$K" || exit 1
python3 bin/jobs_all.py > /dev/null
python3 bin/jobs_x.py > /dev/null
python3 bin/jobs_round.py
for b in ${*:-t x p}; do
	echo "== batch $b $(date +%T)"
	"$K/run_jobs.sh" "$K/jobs/round/$b.json" "$K/out/tiles/$b"
done
echo "== done $(date +%T)"
