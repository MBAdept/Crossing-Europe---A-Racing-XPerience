#!/bin/bash
# scratch: append the ModelFactory smoke test to the protocol
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
P=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/PIPE/pruefprotokoll.txt
if ! grep -q "=== 7 ModelFactory" $P; then
	printf '\n=== 7 ModelFactory ohne Fenster: jedes Set mit Modell in jeder Stufe, MultiMesh-Teile, Fernbild\n' >> $P
	cat $D/probe_factory.log >> $P
fi
tail -24 $P | cut -c1-200
