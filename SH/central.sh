#!/bin/bash
salloc -p hype --exclusive --nodelist=hype1,hype2,hype3,hype4 -J JOB -t 72:00:00

ssh -n -f hype1 "sh -c 'cd $HOME/SMPE_1920/SH; nohup ./nas.batch > /dev/null 2>&1 &'"
