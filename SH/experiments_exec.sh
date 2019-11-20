#!/bin/bash

#############################################################################################################
##################################Step 1: Defining the Variables#############################################
#############################################################################################################

#Variable Directories
BASE=$HOME/CMP223
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
R=$BASE/R
LOGS=$BASE/LOGS
SOFTWARES=$BASE/SOFTWARES
TRACE=$LOGS/TRACE
MACHINE_FILES=$BASE/MACHINE_FILES

#NPB Variables
NPBE=NPB3.4_Exec
APP_BIN_NPBE=$NPBE/NPB3.4-MPI/bin
APP_CONFIG_NPBE=$NPBE/NPB3.4-MPI/config
APP_COMPILE_NPBE=$NPBE/NPB3.4-MPI

#NPB Charac Variables
NPBC=NPB3.4_Charac
APP_BIN_NPBC=$NPBC/NPB3.4-MPI/bin
APP_CONFIG_NPBC=$NPBC/NPB3.4-MPI/config
APP_COMPILE_NPBC=$NPBC/NPB3.4-MPI

#Ondes3d Exec Variables
ONDES3DE=Ondes3de
APP_BIN_ONDES3DE=$ONDES3DE/ondes3d
APP_TEST_ONDES3DE_SISHUAN=$ONDES3DE/SISHUAN-XML
APP_CONFIG_ONDES3DE=$APP_TEST_ONDES3D_SISHUAN/options.h
APP_CONFIG_ONDES3DE_PRM=$APP_TEST_ONDES3D_SISHUAN/sishuan.prm
APP_SRC_ONDES3DE=$ONDES3DE/SRC
APP_LOGS_ONDES3DE=$ONDES3DE/LOGS

#Ondes3d Charac Variables
ONDES3DC=Ondes3dc
APP_BIN_ONDES3DC=$ONDES3DC/ondes3d
APP_TEST_ONDES3DC_SISHUAN=$ONDES3DC/SISHUAN-XML
APP_CONFIG_ONDES3DC=$APP_TEST_ONDES3D_SISHUAN/options.h
APP_CONFIG_ONDES3DC_PRM=$APP_TEST_ONDES3D_SISHUAN/sishuan.prm
APP_SRC_ONDES3DC=$ONDES3DC/SRC
APP_LOGS_ONDES3DC=$ONDES3DC/LOGS

#Alya Exec Variables
ALYAE=Alya_Exec
ALYAE_DIR=$ALYAE/Executables/unix
APP_BIN_ALYAE=$ALYA_DIR/Alya.x
APP_CONFIG_ALYAE=$ALYAE/Executables/unix/config.in
APP_ALYAE_TUFAN=$ALYAE/4_tufan_run/c/c
ALYAE_LOG=$APP_ALYA_TUFAN.log

#Alya Charac Variables
ALYAC=Alya_Charac
ALYAC_DIR=$ALYAC/Executables/unix
APP_BIN_ALYAC=$ALYA_DIR/Alya.x
APP_CONFIG_ALYAC=$ALYAC/Executables/unix/config.in
APP_ALYAC_TUFAN=$ALYAC/4_tufan_run/c/c
ALYAC_LOG=$APP_ALYA_TUFAN.log

#IMB Exec Variables
IMBE=Imbbench_Exec
APP_BIN_IMBE=$IMBE/bin/imb
IMB_MEMORY=Memory
IMB_MEMORY_PATTERN=8Level 
IMB_MEMORY_MICROBENCHMARK=BST
IMB_CPU=CPU
IMB_CPU_PATTERN=8Level 
IMB_CPU_MICROBENCHMARK=Rand

#IMB Charac Variables
IMBC=Imbbench_Charac
APP_BIN_IMBC=$IMBC/bin/imb

#Intel MPI Benchmarks Variables
INTEL=mpi-benchmarks
INTEL_SOURCE=$INTEL/src_cpp/Makefile
APP_BIN_INTEL=$INTEL/IMB-MPI1
APP_TEST_INTEL=PingPong

#Akypuera and Paje Variables
AKY_BUILD=$SOFTWARES/akypuera/build
PAJE_BUILD=$SOFTWARES/pajeng/build

#Other Variables
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_APPS_EXEC=$LOGS/apps_exec.$START.csv
OUTPUT_APPS_CHARAC=$LOGS/apps_charac.$START.csv
OUTPUT_APPS_EXEC_IMB=$LOGS/imb_exec.$START.csv
OUTPUT_APPS_CHARAC_IMB=$LOGS/imb_charac.$START.csv
OUTPUT_INTEL_EXEC=$LOGS/intel.$START.csv
PARTITION=(hype1 hype2 hype4 hype5)

#############################################################################################################
#################################Step 2: Collect the System Information######################################
#############################################################################################################

#Executes the system information collector script
for (( i = 0; i < 4; i++ )); do
	ssh ${PARTITION[i]} '/home/users/ammaliszewski/CMP223/SH/./sys_info_collect.sh'
done

#############################################################################################################
#######################Step 3: Create the Folders/Download and Compile the Programs##########################
#############################################################################################################

mkdir -p $BENCHMARKS
mkdir -p $LOGS
mkdir -p $BASE/LOGS/BACKUP
mkdir -p $SOFTWARES 
mkdir -p $TRACE

########################################Score-P#############################################
cd $SOFTWARES
wget -c https://www.vi-hps.org/cms/upload/packages/scorep/scorep-6.0.tar.gz -S -a $LOGS/scorep-6.0.download.log
tar -zxf scorep-6.0.tar.gz; rm -f scorep-6.0.tar.gz 
cd scorep-6.0; ./configure --prefix=/tmp/install; make; make install

########################################Akypuera#############################################
cd $SOFTWARES
git clone --recursive --progress https://github.com/schnorr/akypuera.git 2> $LOGS/akypuera.download.log

mkdir -p akypuera/build; cd akypuera/build; 
cmake -DOTF2=ON -DOTF2_PATH=/tmp/install/ -DCMAKE_INSTALL_PREFIX=/tmp/akypuera/ ..
make; make install

########################################PajeNG#############################################
cd $SOFTWARES
git clone --recursive --progress https://github.com/schnorr/pajeng.git 2> $LOGS/pajeng.download.log
mkdir -p pajeng/build ; cd pajeng/build; cmake .. ; make install

########################################IMB#################################################
#Exec
cd $BENCHMARKS
git clone --recursive --progress https://github.com/Roloff/ImbBench.git 2> $LOGS/ImbBench.download.log
mv ImbBench Imbbench_Exec; cp -r Imbbench_Exec Imbbench_Charac
cd $IMBE; mkdir bin; make

#Charac
cd $BENCHMARKS
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' $IMBC/Makefile
cd $IMBC; mkdir bin; make

########################################Alya################################################
#Exec
cd $BENCHMARKS
git clone --recursive --progress https://gitlab.com/ammaliszewski/alya.git 2> $LOGS/Alya.download.log
mv alya Alya_Exec; cp -r Alya_Exec Alya_Charac
cd $ALYAE_DIR
cp configure.in/config_gfortran.in config.in
sed -i 's,mpif90,mpifort,g' config.in
./configure -x nastin parall
make metis4; make

#Charac
cd $BENCHMARKS; cd $ALYAC_DIR
cp configure.in/config_gfortran.in config.in
sed -i 's,mpif90,/tmp/install/bin/./scorep mpifort,g' config.in
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' config.in
./configure -x nastin parall
make metis4; make

#######################################Ondes3d##############################################
#Exec
cd $BENCHMARKS
git clone --recursive --progress https://bitbucket.org/fdupros/ondes3d.git 2> $LOGS/Ondes3d.download.log
mv ondes3d Ondes3de; cp -r Ondes3de Ondes3dc 
sed -i 's,./../,./BENCHMARKS/ondes3de/,g' $APP_CONFIG_ONDES3DE
sed -i 's,./SISHUAN-OUTPUT,./BENCHMARKS/ondes3de/LOGS,g' $APP_CONFIG_ONDES3DE_PRM
mkdir -p $ONDES3DE/LOGS
sed -i 's,./SISHUAN-XML,./BENCHMARKS/ondes3de/SISHUAN-XML,g' $APP_CONFIG_ONDES3DE_PRM
cp $APP_CONFIG_ONDES3DE $APP_SRC_ONDES3DE; cd $APP_SRC_ONDES3DE; make clean; make 

#Charac
sed -i 's,./../,./BENCHMARKS/ondes3dc/,g' $APP_CONFIG_ONDES3DC
sed -i 's,./SISHUAN-OUTPUT,./BENCHMARKS/ondes3dc/LOGS,g' $APP_CONFIG_ONDES3DC_PRM
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' $APP_SRC_ONDES3DC/Makefile
mkdir -p $ONDES3DC/LOGS
sed -i 's,./SISHUAN-XML,./BENCHMARKS/ondes3dc/SISHUAN-XML,g' $APP_CONFIG_ONDES3D_PRM
cp $APP_CONFIG_ONDES3DC $APP_SRC_ONDES3DC; cd $APP_SRC_ONDES3DC; make clean; make 

#######################################NPB##################################################
#Exec
cd $BENCHMARKS
wget -c https://www.nas.nasa.gov/assets/npb/NPB3.4.tar.gz -S -a $LOGS/NPB3.4.download.log
tar -xzf NPB3.4.tar.gz --transform="s/NPB3.4/NPB3.4_Exec/"; cp -r NPB3.4_Exec NPB3.4_Charac
rm -rf NPB3.4.tar.gz

for f in $APP_CONFIG_NPBE/*.def.template; do
	mv -- "$f" "${f%.def.template}.def"; 
done

sed -i 's,mpif90,mpifort,g' $APP_CONFIG_NPBE/make.def
apps=(bt ep cg mg sp lu is ft)
classes=(D)
echo -n "" > $APP_CONFIG_NPBE/suite.def

for (( n = 0; n < 8; n++ )); do
	for (( i = 0; i < 1; i++ )); do
		echo -e ${apps[n]}"\t"${classes[i]} >> $APP_CONFIG_NPBE/suite.def
	done
done
cd $APP_COMPILE_NPBE; make suite

#Charac
cd $BENCHMARKS
for f in $APP_CONFIG_NPBC/*.def.template; do
	mv -- "$f" "${f%.def.template}.def"; 
done

sed -i 's,mpif90,/tmp/install/bin/./scorep mpifort,g' $APP_CONFIG_NPBC/make.def
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' $APP_CONFIG_NPBC/make.def

apps=(bt ep cg mg sp lu is ft)
classes=(D)
echo -n "" > $APP_CONFIG_NPBC/suite.def

for (( n = 0; n < 8; n++ )); do
	for (( i = 0; i < 1; i++ )); do
		echo -e ${apps[n]}"\t"${classes[i]} >> $APP_CONFIG_NPBC/suite.def
	done
done

cd $APP_COMPILE_NPBC; make suite; cd $BASE

#################################Intel MPI Benchmarks#############################################
cd $BENCHMARKS
git clone --recursive --progress https://github.com/intel/mpi-benchmarks.git 2> mpi-benchmarks.download.log
sed -i 's,mpiicc,mpicc,g' $INTEL_SOURCE
sed -i 's,mpiicpc,mpicxx,g' $INTEL_SOURCE
cd $INTEL; make IMB-MPI1

#############################################################################################################
#######################Step 4: Define the Machine Files and Experimental Project#############################
#############################################################################################################

#Define the machine file and experimental project
MACHINEFILE_POWER_OF_2=$MACHINE_FILES/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$MACHINE_FILES/nodes_square_root
MACHINEFILE_FULL=$MACHINE_FILES/nodes_full
MACHINEFILE_INTEL=$MACHINE_FILES/nodes_intel
PROJECT=$R/experimental_project.csv

#############################################################################################################
#######################Step 5: Read the Experimental Project and Started the Execution Loop##################
#############################################################################################################

#Read the experimental project
tail -n +2 $PROJECT |
while IFS=, read -r number apps interface
do

#Define a single key
	KEY="$name-$apps-$interface"
	echo $KEY

#Prepare the command for execution
	runline=""
	if [[ ${apps:0:4} == exec ]]; then
		runline+="mpiexec --mca btl self, "
	else
		runline+="mpiexec "
		runline+="-x SCOREP_EXPERIMENT_DIRECTORY=$TRACE/$apps.$interface "
    	runline+="-x SCOREP_ENABLE_TRACING=TRUE "
    	runline+="-x SCOREP_ENABLE_PROFILING=FALSE "
    	runline+="--mca btl self,"
	fi

#Select interface
	if [[ $interface == ib ]]; then
		runline+="openib --mca btl_openib_if_include mlx5_0:1 "	
	elif [[ $interface == ipoib ]]; then
		runline+="tcp --mca btl_tcp_if_include ib0 "
	else
		runline+="tcp --mca btl_tcp_if_include eno2 "
	fi

#Select app
#Ondes3d, Alya, IMB
	if [[ ${#apps} == 12 || ${#apps} == 14 || ${#apps} == 15 || 
		${#apps} == 18 || ${#apps} == 11 || ${#apps} == 9 ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
#Intel
	elif [[ ${#apps} == 10 ]]; then
		PROCS=2
		runline+="-np $PROCS -machinefile $MACHINEFILE_INTEL "
	elif [[ ${app:5:7} == bt || ${app:5:7} == sp ]]; then
		PROCS=144
		runline+="-np $PROCS -machinefile $MACHINEFILE_SQUARE_ROOT "
	else
		PROCS=128
		runline+="-np $PROCS -machinefile $MACHINEFILE_POWER_OF_2 "
	fi

#Save the output according to the app
	if [[ $apps == exec_ondes3d ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ONDES3DE 0 "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/ondes3d.out)"
		TIME=`grep -i "Timing total" /tmp/ondes3d.out | awk {'print $3'} | head -n 1`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC

	elif [[ $apps == charac_ondes3d ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ONDES3DC 0 "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/ondes3d.out)"
		TIME=`grep -i "Timing total" /tmp/ondes3d.out | awk {'print $3'} | head -n 1`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC
		$AKY_BUILD/./otf22paje $TRACE/$apps.$interface/traces.otf2 > $TRACE/$apps.$interface/$apps.$interface.trace
		$PAJE_BUILD/./pj_dump $TRACE/$apps.$interface/$apps.$interface.trace | grep ^State > $TRACE/$apps.$interface/$apps$interface.csv
	
	elif [[ $apps == exec_intel ]]; then
		runline+="$BENCHMARKS/$APP_BIN_INTEL $APP_TEST_INTEL "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/intel_mb.out)"
		N=`tail -n +35 /tmp/intel_mb.out | awk {'print $1'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' | wc -l`
		for (( i = 0; i < $N; i++ )); do
			echo "$apps,$interface" >> /tmp/for.out
		done

		tail -n +35 /tmp/intel_mb.out | awk {'print $1'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/BYTES
    	tail -n +35 /tmp/intel_mb.out | awk {'print $3'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/TIME
    	tail -n +35 /tmp/intel_mb.out | awk {'print $4'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/Mbytes
    	paste -d"," /tmp/for.out /tmp/BYTES /tmp/TIME /tmp/Mbytes >> $OUTPUT_INTEL_EXEC
    	rm /tmp/for.out; rm /tmp/BYTES; rm /tmp/TIME; rm /tmp/Mbytes

	elif [[ $apps == exec_imb_memory ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBE $IMB_MEMORY $IMB_MEMORY_PATTERN $IMB_MEMORY_MICROBENCHMARK "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/imb.out)"
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_EXEC_IMB
		rm /tmp/imb_tmp.out

	elif [[ $apps == charac_imb_memory ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBC $IMB_MEMORY $IMB_MEMORY_PATTERN $IMB_MEMORY_MICROBENCHMARK "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/imb.out)"
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_CHARAC_IMB
		rm /tmp/imb_tmp.out
		$AKY_BUILD/./otf22paje $TRACE/$apps.$interface/traces.otf2 > $TRACE/$apps.$interface/$apps.$interface.trace
		$PAJE_BUILD/./pj_dump $TRACE/$apps.$interface/$apps.$interface.trace | grep ^State > $TRACE/$apps.$interface/$apps$interface.csv

	elif [[ $apps == exec_imb_CPU ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBE $IMB_CPU $IMB_CPU_PATTERN $IMB_CPU_MICROBENCHMARK "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/imb.out)"
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_EXEC_IMB
		rm /tmp/imb_tmp.out

	elif [[ $apps == charac_imb_CPU ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBC $IMB_CPU $IMB_CPU_PATTERN $IMB_CPU_MICROBENCHMARK "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/imb.out)"
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_CHARAC_IMB
		rm /tmp/imb_tmp.out
		$AKY_BUILD/./otf22paje $TRACE/$apps.$interface/traces.otf2 > $TRACE/$apps.$interface/$apps.$interface.trace
		$PAJE_BUILD/./pj_dump $TRACE/$apps.$interface/$apps.$interface.trace | grep ^State > $TRACE/$apps.$interface/$apps$interface.csv

	elif [[ $apps == exec_alya ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ALYAE BENCHMARKS/$APP_ALYAE_TUFAN "
		runline+="2 >> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/alya.out)"
		TIME=`cat $BENCHMARKS/$ALYAE_LOG | grep "TOTAL CPU TIME" | awk '{print $4}'`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC

	elif [[ $apps == charac_alya ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ALYAE BENCHMARKS/$APP_ALYAC_TUFAN "
		runline+="2 >> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/alya.out)"
		TIME=`cat $BENCHMARKS/$ALYAC_LOG | grep "TOTAL CPU TIME" | awk '{print $4}'`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC

	elif [[ ${#apps} == 7 ]]; then
		runline+="$BENCHMARKS/$APP_BIN_NPBE/${app:5:7}.x "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/nas.out)"
		TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC
	else
		runline+="$BENCHMARKS/$APP_BIN_NPBC/${app:7:9}.x "
		runline+="2>> $LOGS/app_std_error "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.log > /tmp/nas.out)"
		TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC
	fi	
	echo "Done!"

#Execute the experiments
	echo "Executing >> $runline <<"
	eval "$runline < /dev/null"
	
done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_APPS_EXEC
sed -i '1s/^/apps,interface,time,rank\n/' $OUTPUT_APPS_EXEC_IMB
sed -i '1s/^/apps,interface,bytes,time,mbytes-sec\n/' $OUTPUT_INTEL_EXEC
exit