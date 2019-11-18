#!/bin/bash

#Variable Directories
BASE=$HOME/CMP223
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
TRACE=$LOGS/TRACE
R=$BASE/R
SOFTWARES=$BASE/SOFTWARES

#NPB Variables
NPB=NPB3.4_CHARAC
APP_BIN_NPB=$NPB/NPB3.4-MPI/bin
APP_CONFIG_NPB=$NPB/NPB3.4-MPI/config
APP_COMPILE_NPB=$NPB/NPB3.4-MPI

#Ondes3d Variables
ONDES3D=ondes3dc
APP_BIN_ONDES3D=$ONDES3D/ondes3d
APP_TEST_ONDES3D_SISHUAN=$ONDES3D/SISHUAN-XML
APP_CONFIG_ONDES3D=$APP_TEST_ONDES3D_SISHUAN/options.h
APP_CONFIG_ONDES3D_PRM=$APP_TEST_ONDES3D_SISHUAN/sishuan.prm
APP_SRC_ONDES3D=$ONDES3D/SRC
APP_LOGS_ONDES3D=$ONDES3D/LOGS

#Alya Variables
#ALYA=ALYA_EXEC/Executables/unix
#APP_BIN_ALYA=$ALYA/Alya.x
#APP_CONFIG_ALYA=$ALYA/config.in
#APP_TEST_CASE_B_ALYA=$ALYA/TestCaseB/sphere

#IMB Variables
IMB=IMBBENCH_CHARAC
APP_BIN_IMB=$IMB/bin/imb
IMB_MEMORY=Memory
IMB_MEMORY_PATTERN=8Level 
IMB_MEMORY_MICROBENCHMARK=BST
IMB_CPU=CPU
IMB_CPU_PATTERN=8Level 
IMB_CPU_MICROBENCHMARK=Rand

#Akypuera and Paje Variables
AKY_BUILD=$SOFTWARES/akypuera/build
PAJE_BUILD=$SOFTWARES/pajeng/build

#Other Variables
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_APPS_CHARAC=$LOGS/apps_charac.$START.csv
OUTPUT_APPS_CHARAC_IMB=$LOGS/imb_charac.$START.csv

mkdir -p $SOFTWARES; mkdir -p $TRACE

#ScoreP
cd $SOFTWARES
wget -c https://www.vi-hps.org/cms/upload/packages/scorep/scorep-6.0.tar.gz
tar -zxf scorep-6.0.tar.gz; rm -f scorep-6.0.tar.gz 
cd scorep-6.0; ./configure --prefix=/tmp/install; make; make install

#Akypuera
cd $SOFTWARES
git clone --recursive https://github.com/schnorr/akypuera.git
mkdir -p akypuera/build; cd akypuera/build; 
cmake -DOTF2=ON -DOTF2_PATH=/tmp/install/ -DCMAKE_INSTALL_PREFIX=/tmp/akypuera/ ..
make; make install

#PajeNG
cd $SOFTWARES
git clone --recursive https://github.com/schnorr/pajeng.git; mkdir -p pajeng/build ; cd pajeng/build; cmake .. ; make install

########################################IMB#################################################
cd $BENCHMARKS
git clone --recursive https://github.com/Roloff/ImbBench.git
mv ImbBench IMBBENCH_CHARAC
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' $IMB/Makefile
cd $IMB; mkdir bin; make

########################################Alya################################################
#cd $BENCHMARKS
#wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/Alya.tar.gz
#tar -zxf Alya.tar.gz;rm -rf Alya.tar.gz
#cd $BENCHMARKS/$ALYA; wget -c https://repository.prace-ri.eu/ueabs/ALYA/2.1/TestCaseB.tar.gz
#tar -zxf TestCaseB.tar.gz;rm -rf TestCaseB.tar.gz
#cd $BENCHMARKS/$ALYA; cp configure.in/config_gfortran.in config.in
#sed -i 's,mpif90,mpifort,g' config.in
#./configure -x nastin parall
#cd $BENCHMARKS/$ALYA; make metis4;make

#######################################Ondes3d##############################################
cd $BENCHMARKS
git clone --recursive https://bitbucket.org/fdupros/ondes3d.git
mv ondes3d ondes3dc
sed -i 's,./../,./BENCHMARKS/ondes3dc/,g' $APP_CONFIG_ONDES3D
sed -i 's,./SISHUAN-OUTPUT,./BENCHMARKS/ondes3dc/LOGS,g' $APP_CONFIG_ONDES3D_PRM
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' $APP_SRC_ONDES3D/Makefile
mkdir -p $ONDES3D/LOGS
sed -i 's,./SISHUAN-XML,./BENCHMARKS/ondes3dc/SISHUAN-XML,g' $APP_CONFIG_ONDES3D_PRM
cp $APP_CONFIG_ONDES3D $APP_SRC_ONDES3D; cd $APP_SRC_ONDES3D; make clean; make 

#######################################NPB##################################################
cd $BENCHMARKS
wget -c https://www.nas.nasa.gov/assets/npb/NPB3.4.tar.gz
tar -xzf NPB3.4.tar.gz --transform="s/NPB3.4/NPB3.4_CHARAC/"
rm -rf NPB3.4.tar.gz

for f in $APP_CONFIG_NPB/*.def.template; do
	mv -- "$f" "${f%.def.template}.def"; 
done

sed -i 's,mpif90,/tmp/install/bin/./scorep mpifort,g' $APP_CONFIG_NPB/make.def
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' $APP_CONFIG_NPB/make.def

apps=(bt ep cg mg sp lu is ft)
classes=(D)
echo -n "" > $APP_CONFIG_NPB/suite.def

for (( n = 0; n < 8; n++ )); do
	for (( i = 0; i < 1; i++ )); do
		echo -e ${apps[n]}"\t"${classes[i]} >> $APP_CONFIG_NPB/suite.def
	done
done

cd $APP_COMPILE_NPB; make suite; cd $BASE

#Define the machine file and experimental project
MACHINEFILE_POWER_OF_2=$LOGS/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$LOGS/nodes_square_root
MACHINEFILE_FULL=$LOGS/nodes_full
PROJECT=$R/experimental_project_charac.csv

#Read the experimental project
tail -n +2 $PROJECT |
while IFS=\; read -r name apps interface Blocks
do
#Clean the values
	export name=$(echo $name | sed "s/\"//g")
	export apps=$(echo $apps | sed "s/\"//g")
	export interface=$(echo $interface | sed "s/\"//g")

#Define a single key
	KEY="$name-${apps:0:2}-$interface"
	
	echo $KEY

#Prepare the command for execution
	runline=""
	runline+="mpiexec "
	runline+="-x SCOREP_EXPERIMENT_DIRECTORY=$TRACE/scorep_${apps:0:3}$interface "
    runline+="-x SCOREP_ENABLE_TRACING=TRUE "
    runline+="-x SCOREP_ENABLE_PROFILING=FALSE "
    runline+="--mca btl self,"

#Select interface
	if [[ $interface == ib ]]; then
		runline+="openib --mca btl_openib_if_include mlx5_0:1 "	
	elif [[ $interface == ipoib ]]; then
		runline+="tcp --mca btl_tcp_if_include ib0 "
	else
		runline+="tcp --mca btl_tcp_if_include eno2 "
	fi

#Select app
	if [[ $apps == ondes3d ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == imb_memory ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == imb_CPU ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
#	elif [[ $apps == Alya.x ]]; then
#		PROCS=160
#		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == bt.D.x || $apps == sp.D.x ]]; then
		PROCS=144
		runline+="-np $PROCS -machinefile $MACHINEFILE_SQUARE_ROOT "
	else
		PROCS=128
		runline+="-np $PROCS -machinefile $MACHINEFILE_POWER_OF_2 "
	fi

#Save the output according to the app
	if [[ $apps == ondes3d ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ONDES3D 0 "
		runline+="2>> $LOGS/errors_charac "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.charac.log > /tmp/ondes3d.out)"
	elif [[ $apps == imb_memory ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMB $IMB_MEMORY $IMB_MEMORY_PATTERN $IMB_MEMORY_MICROBENCHMARK "
		runline+="2>> $LOGS/errors_charac "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.charac.log > /tmp/imb.out)"
	elif [[ $apps == imb_CPU ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMB $IMB_CPU $IMB_CPU_PATTERN $IMB_CPU_MICROBENCHMARK "
		runline+="2>> $LOGS/errors_charac "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.charac.log > /tmp/imb.out)"
#	elif [[ $apps == Alya.x ]]; then
#		runline+="$BENCHMARKS/$APP_BIN_ALYA $APP_TEST_CASE_B_ALYA "
#		runline+="2 >> $LOGS/errors_charac "
#		runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:5}$interface.charac.log > /tmp/alya.out)"
	else
		runline+="$BENCHMARKS/$APP_BIN_NPB/$apps "
		runline+="2>> $LOGS/errors_charac "
		runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:3}$interface.charac.log > /tmp/nas.out)"
	fi	

#Execute the experiments
	echo "Running >> $runline <<"
	eval "$runline < /dev/null"

#Save the experiments
	if [[ $apps == ondes3d ]]; then
		TIME=`grep -i "Timing total" /tmp/ondes3d.out | awk {'print $3'} | head -n 1`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC
		$AKY_BUILD/./otf22paje $TRACE/scorep_${apps:0:3}$interface/traces.otf2 > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace
		#$PAJE_BUILD/./pj_dump $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace | grep ^State > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.csv
	elif [[ $apps == imb_memory ]]; then
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_CHARAC_IMB
		rm /tmp/imb_tmp.out
		$AKY_BUILD/./otf22paje $TRACE/scorep_${apps:0:3}$interface/traces.otf2 > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace
		#$PAJE_BUILD/./pj_dump $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace | grep ^State > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.csv
	elif [[ $apps == imb_CPU ]]; then
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_CHARAC_IMB
		rm /tmp/imb_tmp.out
		$AKY_BUILD/./otf22paje $TRACE/scorep_${apps:0:3}$interface/traces.otf2 > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace
		#$PAJE_BUILD/./pj_dump $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace | grep ^State > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.csv	
	#elif [[ $apps == Alya.x ]]; then
		#echo FALTA_FAZER_FUNCIONAR
	else	
		TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
		echo "${apps:0:2},$interface,$TIME" >> $OUTPUT_APPS_CHARAC
		$AKY_BUILD/./otf22paje $TRACE/scorep_${apps:0:3}$interface/traces.otf2 > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace
		#$PAJE_BUILD/./pj_dump $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace | grep ^State > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.csv
	fi	
	echo "Done!"
done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_NPB_CHARAC
sed -i '1s/^/apps,interface,time,rank\n/' $OUTPUT_APPS_CHARAC_IMB
exit