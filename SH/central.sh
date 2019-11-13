#!/bin/bash
salloc -p draco --exclusive --nodelist=draco2,draco3,draco4,draco5 -J JOB -t 72:00:00

ssh -n -f hype2 "sh -c 'cd $HOME/CMP223/SH; nohup ./nas_charac.sh > /dev/null 2>&1 &'"
