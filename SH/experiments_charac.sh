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

#NPB Charac Variables
NPBC=NPB3.4_Charac
APP_BIN_NPBC=$NPBC/NPB3.4-MPI/bin

#Alya Charac Variables
ALYAC=Alya_Charac
ALYAC_DIR=$ALYAC/Executables/unix
APP_BIN_ALYAC=$ALYAC_DIR/Alya.x
APP_ALYAC_TUFAN=$ALYAC/4_tufan_run/c/c
ALYAC_LOG=$APP_ALYAC_TUFAN.log

#IMB Charac Variables
IMBC=Imbbench_Charac
APP_BIN_IMBC=$IMBC/bin/imb
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

#############################################################################################################
#######################Step 2: Define the Machine Files and Experimental Project#############################
#############################################################################################################

#Define the machine file and experimental project
MACHINEFILE_POWER_OF_2=$MACHINE_FILES/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$MACHINE_FILES/nodes_square_root
MACHINEFILE_FULL=$MACHINE_FILES/nodes_full
PROJECT=$R/experimental_project_charac.csv

#############################################################################################################
#######################Step 3: Read the Experimental Project and Started the Execution Loop##################
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
	runline+="mpiexec "
	runline+="-x SCOREP_EXPERIMENT_DIRECTORY=$TRACE/$apps.$interface "
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
## Alya, IMB
	if [[ $apps == charac_alya || $apps == charac_imb_memory || $apps == charac_imb_CPU ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == charac_bt || $apps == charac_sp ]]; then
		PROCS=144							
		runline+="-np $PROCS -machinefile $MACHINEFILE_SQUARE_ROOT "
	else
		PROCS=128
		runline+="-np $PROCS -machinefile $MACHINEFILE_POWER_OF_2 "
	fi

#Save the output according to the app
	if [[ $apps == charac_imb_memory ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBC $IMB_MEMORY $IMB_MEMORY_PATTERN $IMB_MEMORY_MICROBENCHMARK "
		runline+="2>> $LOGS/apps_charac_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/imb.out)"

	elif [[ $apps == charac_imb_CPU ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMBC $IMB_CPU $IMB_CPU_PATTERN $IMB_CPU_MICROBENCHMARK "
		runline+="2>> $LOGS/apps_charac_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/imb.out)"
	
	elif [[ $apps == charac_alya ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ALYAC BENCHMARKS/$APP_ALYAC_TUFAN "
		runline+="2 >> $LOGS/apps_charac_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/alya.out)"	

	else
		runline+="$BENCHMARKS/$APP_BIN_NPBC/${apps:7:9}.D.x "
		runline+="2>> $LOGS/apps_charac_std_error "
		runline+="&> >(tee -a $LOGS/LOGS_BACKUP/$apps.$interface.log > /tmp/nas.out)"
	fi	

#Execute the experiments
	echo "Executing >> $runline <<"
	eval "$runline < /dev/null"
	
	#Save the output according to the app
	if [[ $apps == charac_imb_memory ]]; then
		TIME=`cat /tmp/imb.out | awk 'NR >159' | awk {'print $8'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC
		$AKY_BUILD/./otf22paje $TRACE/$apps.$interface/traces.otf2 > $TRACE/$apps.$interface/$apps.$interface.trace
		$PAJE_BUILD/./pj_dump $TRACE/$apps.$interface/$apps.$interface.trace | grep ^State > $TRACE/$apps.$interface/$apps.$interface.csv

	elif [[ $apps == charac_imb_CPU ]]; then
		TIME=`cat /tmp/imb.out | awk 'NR >159' | awk {'print $8'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC
		$AKY_BUILD/./otf22paje $TRACE/$apps.$interface/traces.otf2 > $TRACE/$apps.$interface/$apps.$interface.trace
		$PAJE_BUILD/./pj_dump $TRACE/$apps.$interface/$apps.$interface.trace | grep ^State > $TRACE/$apps.$interface/$apps.$interface.csv

	elif [[ $apps == charac_alya ]]; then
		TIME=`cat $BENCHMARKS/$ALYAC_LOG | grep "TOTAL CPU TIME" | awk '{print $4}'`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC
		$AKY_BUILD/./otf22paje $TRACE/$apps.$interface/traces.otf2 > $TRACE/$apps.$interface/$apps.$interface.trace
		$PAJE_BUILD/./pj_dump $TRACE/$apps.$interface/$apps.$interface.trace | grep ^State > $TRACE/$apps.$interface/$apps.$interface.csv
		
	else
		TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_CHARAC
		$AKY_BUILD/./otf22paje $TRACE/$apps.$interface/traces.otf2 > $TRACE/$apps.$interface/$apps.$interface.trace
		$PAJE_BUILD/./pj_dump $TRACE/$apps.$interface/$apps.$interface.trace | grep ^State > $TRACE/$apps.$interface/$apps.$interface.csv
		echo "Done!"
	fi

done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_APPS_CHARAC
exit