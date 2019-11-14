#!/bin/bash
salloc -p hype --exclusive --nodelist=hype1,hype2,hype3,hype4 -J JOB -t 72:00:00

ssh -n -f hype1 "sh -c 'cd $HOME/CMP223/SH; nohup ./nas_charac.sh > /dev/null 2>&1 &'"