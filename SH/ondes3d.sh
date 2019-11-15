#!/bin/bash

BASE=$HOME/TESTE
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
R=$BASE/R
ONDES3D=$BENCHMARKS/ondes3d
APP_BIN_ONDES3D=$ONDES3D/ondes3d
APP_CONFIG_ONDES3D=$ONDES3D/SISHUAN-XML/options.h
APP_SRC_ONDES3D=$ONDES3D/SRC
APP_TEST_CASE_A=$ONDES3D/SISHUAN-XML
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_ONDES3D_EXEC=$LOGS/ONDES3D_exec.$START.csv
PARTITION=hype

mkdir -p $BENCHMARKS
# Download and compile ONDES3D and 2 Test Case
cd $BENCHMARKS

git clone --recursive https://bitbucket.org/fdupros/ondes3d.git
cp $APP_CONFIG_ONDES3D $APP_SRC_ONDES3D; cd $APP_SRC_ONDES3D; make clean; make; cd $ONDES3D; 
sed -i 's,SISHUAN-OUTPUT,LOGS,g' SISHUAN-XML/sishuan.prm;mkdir -p LOGS;
sed -i 's,./../,./,g' SISHUAN-XML/options.h

exit





