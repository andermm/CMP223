#!/bin/bash

BASE=$HOME/TESTE
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
R=$BASE/R
ALYA=$BENCHMARKS/Alya/Executables/unix
APP_BIN_ALYA=$ALYA/Alya.x
APP_CONFIG_ALYA=$ALYA/config.in
APP_TEST_CASE_A=
APP_TEST_CASE_B=
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_ALYA_EXEC=$LOGS/alya_exec.$START.csv
PARTITION=hype


# Download and compile Alya and 2 Test Case
cd $BENCHMARKS

wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/Alya.tar.gz;tar -zxf Alya.tar.gz;rm -rf Alya.tar.gz
cd $ALYA; wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/TestCaseA.tar.gz;tar -zxf TestCaseA.tar.gz;rm -rf TestCaseA.tar.gz
cd $ALYA; wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/TestCaseB.tar.gz;tar -zxf TestCaseB.tar.gz;rm -rf TestCaseB.tar.gz

cd $ALYA; cp configure.in/config_gfortran.in config.in
sed -i 's,mpif90,mpifort,g' $APP_CONFIG_ALYA
./configure -x nastin parall

##Compile Alya
cd $ALYA; make metis4;make;cd $BASE

mkdir -p $BASE/LOGS/BACKUP

exit