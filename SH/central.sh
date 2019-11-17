#!/bin/bash
BASE=$HOME/CMP223
salloc -p hype --exclusive --nodelist=hype1,hype2,hype4,hype5 -J JOB -t 72:00:00
ssh -n -f hype1 "sh -c 'cd $HOME/CMP223; nohup ./SH/benchmarks.sh > $BASE/LOGS/scriptlog 2>&1 &'"