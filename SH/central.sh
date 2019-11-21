#!/bin/bash
BASE=$HOME/CMP223
salloc -p hype --exclusive --nodelist=hype2,hype3,hype4,hype5 -J JOB -t 72:00:00
ssh -n -f hype2 "sh -c 'cd $HOME/CMP223; nohup ./SH/experiments_exec.sh > $BASE/LOGS/apps_std_out.log 2>&1 &'"