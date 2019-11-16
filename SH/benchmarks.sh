#!/bin/bash

BASE=$HOME/CMP223
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
R=$BASE/R
NPB=$BENCHMARKS/NPB3.4_EXEC
APP_BIN_NPB=$NPB/NPB3.4-MPI/bin
APP_CONFIG_NPB=$NPB/NPB3.4-MPI/config
APP_COMPILE_NPB=$NPB/NPB3.4-MPI
ONDES3D=$BENCHMARKS/ondes3d
APP_BIN_ONDES3D=$ONDES3D/ondes3d
APP_CONFIG_ONDES3D=$ONDES3D/SISHUAN-XML/options.h
APP_SRC_ONDES3D=$ONDES3D/SRC
APP_TEST_CASE_A=$ONDES3D/SISHUAN-XML
ALYA=$BENCHMARKS/Alya/Executables/unix
APP_BIN_ALYA=$ALYA/Alya.x
APP_CONFIG_ALYA=$ALYA/config.in
APP_TEST_CASE_B=$ALYA/TestCaseB/sphere
IMB=$BENCHMARKS/ImbBench
APP_BIN_IMB=$IMB/bin/imb
IMB_MEMORY=(Memory 8Level BST)
IMB_CPU=(CPU 8Level Rand)
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_APPS_EXEC=$LOGS/apps_exec.$START.csv
OUTPUT_APPS_EXEC_IMB=$LOGS/imb_exec.$START.csv
PARTITION=hype

############################################################################################
#Executes the system information collector script
############################################################################################
for (( i = 1; i < 5; i++ )); do
	ssh $PARTITION${i} '$SCRIPTS/./sys_info_collect.sh'
done

mkdir -p $BENCHMARKS;cd $BENCHMARKS; 
mkdir -p $BASE/LOGS/BACKUP

############################################################################################
########################################IMB#################################################
############################################################################################
git clone --recursive https://github.com/Roloff/ImbBench.git
cd $IMB; mkdir bin; make
############################################################################################
########################################Alya################################################
############################################################################################
cd $BENCHMARKS
wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/Alya.tar.gz
tar -zxf Alya.tar.gz;rm -rf Alya.tar.gz
cd $ALYA; wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/TestCaseA.tar.gz
tar -zxf TestCaseA.tar.gz;rm -rf TestCaseA.tar.gz
cd $ALYA; wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/TestCaseB.tar.gz
tar -zxf TestCaseB.tar.gz;rm -rf TestCaseB.tar.gz

cd $ALYA; cp configure.in/config_gfortran.in config.in
sed -i 's,mpif90,mpifort,g' $APP_CONFIG_ALYA
./configure -x nastin parall
cd $ALYA; make metis4;make;cd $BASE
############################################################################################
#######################################Ondes3d##############################################
############################################################################################
git clone --recursive https://bitbucket.org/fdupros/ondes3d.git
sed -i 's,./../,./,g' SISHUAN-XML/options.h
cp $APP_CONFIG_ONDES3D $APP_SRC_ONDES3D; cd $APP_SRC_ONDES3D; make clean; make; cd $ONDES3D; 
sed -i 's,SISHUAN-OUTPUT,LOGS,g' SISHUAN-XML/sishuan.prm;mkdir -p LOGS;

############################################################################################
#######################################NPB##################################################
############################################################################################
cd $BENCHMARKS
wget -c https://www.nas.nasa.gov/assets/npb/NPB3.4.tar.gz
tar -xzf NPB3.4.tar.gz --transform="s/NPB3.4/NPB3.4_EXEC/"
rm -rf NPB3.4.tar.gz

for f in $APP_CONFIG_NPB/*.def.template; do
	mv -- "$f" "${f%.def.template}.def"; 
done

sed -i 's,mpif90,mpifort,g' $APP_CONFIG_NPB/make.def

apps=(bt ep cg mg sp lu is ft)
classes=(D)
echo -n "" > $APP_CONFIG_NPB/suite.def

#Insert app and class in suite.def
for (( n = 0; n < 8; n++ )); do
	for (( i = 0; i < 1; i++ )); do
		echo -e ${apps[n]}"\t"${classes[i]} >> $APP_CONFIG_NPB/suite.def
	done
done

cd $APP_COMPILE_NPB; make suite; cd $BASE

############################################################################################
#Define the machine file and experimental project
############################################################################################

MACHINEFILE_POWER_OF_2=$LOGS/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$LOGS/nodes_square_root
MACHINEFILE_ONDES3D=$LOGS/nodes_ondes3d
MACHINEFILE_ALYA=$MACHINEFILE_ONDES3D
MACHINEFILE_IMB=$MACHINEFILE_ONDES3D
PROJECT=$R/experimental_project.csv

############################################################################################
#Read the experimental project
############################################################################################
tail -n +2 $PROJECT |
while IFS=\; read -r name apps interface Blocks
do

############################################################################################
#Clean the values
############################################################################################
	export name=$(echo $name | sed "s/\"//g")
	export apps=$(echo $apps | sed "s/\"//g")
	export interface=$(echo $interface | sed "s/\"//g")

############################################################################################
#Define a single key
############################################################################################
	KEY="$name-$apps-$interface"
	
	echo $KEY

############################################################################################
#Prepare the command for execution
############################################################################################
	runline=""
	runline+="mpiexec --mca btl self,"

	if [[ $interface == ib ]]; then
		runline+="openib --mca btl_openib_if_include mlx5_0:1 "	
	elif [[ $interface == ipoib ]]; then
		runline+="tcp --mca btl_tcp_if_include ib0 "
	elif [[ $interface == eth ]]; then
		runline+="tcp --mca btl_tcp_if_include eno2 "
	fi

	if [[ $apps == ondes3d ]]; then
		PROCS=180
		runline+="-np $PROCS -machinefile $MACHINEFILE_ONDES3D "
	elif [[ $apps == imb_* ]]; then
		PROCS=180
		runline+="-np $PROCS -machinefile $MACHINEFILE_IMB "
	elif [[ $apps == Alya.x ]]; then
		PROCS=180
		runline+="-np $PROCS -machinefile $MACHINEFILE_ALYA "
	elif [[ $apps == bt.D.x || $apps == sp.D.x ]]; then
		PROCS=121
		runline+="-np $PROCS -machinefile $MACHINEFILE_SQUARE_ROOT "
	else
		PROCS=128
		runline+="-np $PROCS -machinefile $MACHINEFILE_POWER_OF_2 "
	fi

	if [[ $apps == ondes3d ]]; then
		runline+="$APP_BIN_ONDES3D $APP_TEST_CASE_B "
		runline+="2>> $LOGS/errors "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/ondes3d.out)"
	elif [[ $apps == imb_memory ]]; then
		runline+="$APP_BIN_IMB $IMB_MEMORY "
		runline+="2>> $LOGS/errors "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/imb_memory.out)"
	elif [[ $apps == imb_CPU ]]; then
		runline+="$APP_BIN_IMB $IMB_CPU "
		runline+="2>> $LOGS/errors "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/imb_CPU.out)"
	elif [[ $apps == Alya.x ]]; then
		runline+="$APP_BIN_ALYA "
		runline+="2>> $LOGS/errors "
		runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:5}$interface.log > /tmp/alya.out)"
	else
		runline+="$APP_BIN_NPB/$apps "
		runline+="2>> $LOGS/errors "
		runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:3}$interface.log > /tmp/nas.out)"
	fi	
	
	##Execute the experiments
	echo "Running >> $runline <<"
	eval "$runline < /dev/null"

	if [[ $apps == ondes3d ]]; then
		TIME=`grep -i "Timing total" /tmp/ondes3d.out | awk {'print $3'} | head -n 1`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC
	elif [[ $apps == imb_memory ]]; then
		TIME=`cat /tmp/imb_memory.out | awk '{print $8","$4}'`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC_IMB
	elif [[ $apps == imb_CPU ]]; then
		TIME=`cat /tmp/imb_memory.out | awk '{print $8","$4}'`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC_IMB
	elif [[ $apps == Alya.x ]]; then
		echo FALTA_FAZER_FUNCIONAR
	else	
		TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
		echo "${apps:0:2},$interface,$TIME" >> $OUTPUT_APPS_EXEC
	fi	
	echo "Done!"

done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_APPS_EXEC
sed -i '1s/^/apps,interface,time,rank\n/' $OUTPUT_APPS_EXEC_IMB
exit