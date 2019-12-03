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
LOGS_DOWNLOAD=$LOGS/LOGS_DOWNLOAD
LOGS_BACKUP_SRC_CODE=$LOGS/LOGS_BACKUP_SRC_CODE

#NPB Variables
NPBE=NPB3.4_Exec
APP_BIN_NPBE=$NPBE/NPB3.4-MPI/bin
APP_CONFIG_NPBE=$NPBE/NPB3.4-MPI/config
APP_COMPILE_NPBE=$NPBE/NPB3.4-MPI

#NPB Charac Variables
NPBC=NPB3.4_Charac
APP_CONFIG_NPBC=$NPBC/NPB3.4-MPI/config
APP_COMPILE_NPBC=$NPBC/NPB3.4-MPI

#Alya Exec Variables
ALYAE=Alya_Exec
ALYAE_DIR=$ALYAE/Executables/unix
APP_BIN_ALYAE=$ALYAE_DIR/Alya.x
APP_CONFIG_ALYAE=$ALYAE/Executables/unix/config.in
APP_ALYAE_TUFAN=$ALYAE/4_tufan_run/c/c
ALYAE_LOG=$APP_ALYAE_TUFAN.log

#Alya Charac Variables
ALYAC=Alya_Charac
ALYAC_DIR=$ALYAC/Executables/unix

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

#Intel MPI Benchmarks Variables
INTEL=mpi-benchmarks
INTEL_SOURCE=$INTEL/src_cpp/Makefile
APP_BIN_INTEL=$INTEL/IMB-MPI1
APP_TEST_INTEL=PingPong

#Other Variables
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_APPS_EXEC=$LOGS/apps_exec.$START.csv
OUTPUT_INTEL_EXEC=$LOGS/intel.$START.csv
CONTROL_FILE_OUTPUT=$BASE/LOGS/env_info.org
PARTITION=(hype2 hype3 hype4 hype5)

#############################################################################################################
#######################Step 2: Create the Folders/Download and Compile the Programs##########################
#############################################################################################################

mkdir -p $BENCHMARKS
mkdir -p $LOGS
mkdir -p $BASE/LOGS/LOGS_BACKUP
mkdir -p $LOGS_DOWNLOAD
mkdir -p $LOGS_BACKUP_SRC_CODE
mkdir -p $SOFTWARES 
mkdir -p $TRACE

#############################################################################################################
#################################Step 3: Collect the System Information######################################
#############################################################################################################

echo "#+TITLE: System Information" >> $CONTROL_FILE_OUTPUT
echo "#+DATE: $(eval date)" >> $CONTROL_FILE_OUTPUT
echo "#+AUTHOR: $(eval whoami)" >> $CONTROL_FILE_OUTPUT
echo "#+MACHINE: $(eval hostname)" >> $CONTROL_FILE_OUTPUT
echo "#+FILE: $(eval basename $CONTROL_FILE_OUTPUT)" >> $CONTROL_FILE_OUTPUT
echo "" >> $CONTROL_FILE_OUTPUT

#Executes the system information collector script
for (( i = 0; i < 4; i++ )); do
	ssh ${PARTITION[i]} '/home/users/ammaliszewski/CMP223/SH/./sys_info_collect.sh'
done

########################################Score-P#############################################
cd $SOFTWARES
wget -c https://www.vi-hps.org/cms/upload/packages/scorep/scorep-6.0.tar.gz -S -a $LOGS_DOWNLOAD/scorep-6.0.download.log
tar -zxf scorep-6.0.tar.gz; mv scorep-6.0.tar.gz $LOGS_BACKUP_SRC_CODE
cd scorep-6.0; ./configure --prefix=/tmp/install; make; make install

########################################Akypuera#############################################
cd $SOFTWARES
git clone --recursive --progress https://github.com/schnorr/akypuera.git 2> $LOGS_DOWNLOAD/akypuera.download.log
cp -r akypuera $LOGS_BACKUP_SRC_CODE
mkdir -p akypuera/build; cd akypuera/build; 
cmake -DOTF2=ON -DOTF2_PATH=/tmp/install/ -DCMAKE_INSTALL_PREFIX=/tmp/akypuera/ ..
make; make install

########################################PajeNG#############################################
cd $SOFTWARES
git clone --recursive --progress https://github.com/schnorr/pajeng.git 2> $LOGS_DOWNLOAD/pajeng.download.log
cp -r pajeng $LOGS_BACKUP_SRC_CODE
mkdir -p pajeng/build ; cd pajeng/build; cmake .. ; make install

########################################IMB#################################################
#Exec
cd $BENCHMARKS
git clone --recursive --progress https://github.com/Roloff/ImbBench.git 2> $LOGS_DOWNLOAD/ImbBench.download.log
cp -r ImbBench $LOGS_BACKUP_SRC_CODE
mv ImbBench Imbbench_Exec; cp -r Imbbench_Exec Imbbench_Charac
cd $IMBE; mkdir bin; make

#Charac
cd $BENCHMARKS
sed -i 's,mpicc,/tmp/install/bin/./scorep mpicc,g' $IMBC/Makefile
cd $IMBC; mkdir bin; make

########################################Alya################################################
#Exec
cd $BENCHMARKS
git clone --recursive --progress https://gitlab.com/ammaliszewski/alya.git 2> $LOGS_DOWNLOAD/Alya.download.log
cp -r Alya $LOGS_BACKUP_SRC_CODE
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

#######################################NPB##################################################
#Exec
cd $BENCHMARKS
wget -c https://www.nas.nasa.gov/assets/npb/NPB3.4.tar.gz -S -a $LOGS_DOWNLOAD/NPB3.4.download.log
cp -r NPB3.4.tar.gz $LOGS_BACKUP_SRC_CODE
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

cd $APP_COMPILE_NPBC; make suite

#################################Intel MPI Benchmarks#############################################
cd $BENCHMARKS
git clone --recursive --progress https://github.com/intel/mpi-benchmarks.git 2> $LOGS_DOWNLOAD/mpi-benchmarks.download.log
cp -r mpi-benchmarks $LOGS_BACKUP_SRC_CODE
sed -i 's,mpiicc,mpicc,g' $INTEL_SOURCE
sed -i 's,mpiicpc,mpicxx,g' $INTEL_SOURCE
cd $INTEL; make IMB-MPI1
cd $BASE
#############################################################################################################
#######################Step 4: Define the Machine Files and Experimental Project#############################
#############################################################################################################

#Define the machine file and experimental project
MACHINEFILE_POWER_OF_2=$MACHINE_FILES/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$MACHINE_FILES/nodes_square_root
MACHINEFILE_FULL=$MACHINE_FILES/nodes_full
MACHINEFILE_INTEL=$MACHINE_FILES/nodes_intel
PROJECT=$R/experimental_project_exec.csv

#############################################################################################################
#######################Step 5: Read the Experimental Project and Started the Execution Loop##################
#############################################################################################################

#Read the experimental project
tail -n +2 $PROJECT |
while IFS=, read -r apps interface number
do

#Define a single key
	KEY="$number-$apps-$interface"
	echo ""
	echo $KEY
	echo ""

#Prepare the command for execution
	runline=""
	runline+="mpiexec --mca btl self,"
	
#Select interface
	if [[ $interface == ib ]]; then
		runline+="openib --mca btl_openib_if_include mlx5_0:1 "	
	elif [[ $interface == ipoib ]]; then
		runline+="tcp --mca btl_tcp_if_include ib0 "
	else
		runline+="tcp --mca btl_tcp_if_include eno2 "
	fi

#Select app
##Alya, IMB
	if [[ $apps == exec_alya || $apps == exec_imb_memory || $apps == exec_imb_CPU ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == exec_intel ]]; then
		PROCS=2
		runline+="-np $PROCS -machinefile $MACHINEFILE_INTEL "
	elif [[ $apps == exec_bt || $apps == exec_sp ]]; then
		PROCS=144							
		runline+="-np $PROCS -machinefile $MACHINEFILE_SQUARE_ROOT "
	else
		PROCS=128
		runline+="-np $PROCS -machinefile $MACHINEFILE_POWER_OF_2 "
	fi

#Save the output according to the app
	if [[ $apps == exec_intel ]]; then
		runline+="$BENCHMARKS/$APP_BIN_INTEL $APP_TEST_INTEL "
		runline+="2>> $LOGS/apps_exec_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/intel_mb.out)"

	elif [[ $apps == exec_imb_memory ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBE $IMB_MEMORY $IMB_MEMORY_PATTERN $IMB_MEMORY_MICROBENCHMARK "
		runline+="2>> $LOGS/apps_exec_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/imb.out)"

	elif [[ $apps == exec_imb_CPU ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBE $IMB_CPU $IMB_CPU_PATTERN $IMB_CPU_MICROBENCHMARK "
		runline+="2>> $LOGS/apps_exec_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/imb.out)"

	elif [[ $apps == exec_alya ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ALYAE BENCHMARKS/$APP_ALYAE_TUFAN "
		runline+="2 >> $LOGS/apps_exec_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/alya.out)"
	
	else
		runline+="$BENCHMARKS/$APP_BIN_NPBE/${apps:5:7}.D.x "
		runline+="2>> $LOGS/apps_exec_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/nas.out)"	
	fi	

#Execute the experiments
	echo "Executing >> $runline <<"
	eval "$runline < /dev/null"
	
	#Save the output according to the app
	if [[ $apps == exec_intel ]]; then
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
		TIME=`cat /tmp/imb.out | awk 'NR >159' | awk {'print $8'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC

	elif [[ $apps == exec_imb_CPU ]]; then
		TIME=`cat /tmp/imb.out | awk 'NR >159' | awk {'print $8'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC
		
	elif [[ $apps == exec_alya ]]; then
		TIME=`cat $BENCHMARKS/$ALYAE_LOG | grep "TOTAL CPU TIME" | awk '{print $4}'`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC
	
	else
		TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC
	fi

	echo "Done!"
done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_APPS_EXEC
sed -i '1s/^/apps,interface,bytes,time,mbytes-sec\n/' $OUTPUT_INTEL_EXEC

#############################################################################################################
##########################Step 6: Call the Experiment Characterization Script################################
#############################################################################################################
cd $BASE; nohup ./SH/experiments_charac.sh > $BASE/charac_script_std_out-err.log 2>&1 &

exit