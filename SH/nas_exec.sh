#!/bin/bash

BASE=$HOME/CMP223
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
R=$BASE/R
NPB_EXEC=$BENCHMARKS/NPB3.4_EXEC
APP_BIN_NPB=$NPB_EXEC/NPB3.4-MPI/bin
APP_CONFIG_NPB=$NPB_EXEC/NPB3.4-MPI/config
APP_COMPILE_NPB=$NPB_EXEC/NPB3.4-MPI
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_NPB_EXEC=$LOGS/npb_exec.$START.csv
DoE=$BASE/R/DoE_npb_exec.R
PARTITION=hype

#1 - Executes the system information collector script

for (( i = 1; i < 5; i++ )); do
	ssh $PARTITION${i} '$SCRIPTS/./sys_info_collect.sh'
done

#2 - Download and compile NPB
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

##Compile NPB
cd $APP_COMPILE_NPB; make suite; cd $BASE

mkdir -p $BASE/LOGS/BACKUP

##Define the machine file for MPI
MACHINEFILE_POWER_OF_2=$LOGS/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$LOGS/nodes_square_root

#Generate the experimental project
#Rscript $DoE

#Check if the experimental project is provided
PROJECT=$R/experimental_project_npb_exec.csv

#2 - Read the experimental project
tail -n +2 $PROJECT |
while IFS=\; read -r name apps interface Blocks
do
	#Clean the values
	export name=$(echo $name | sed "s/\"//g")
	export apps=$(echo $apps | sed "s/\"//g")
	export interface=$(echo $interface | sed "s/\"//g")

	##Define a single key
	KEY="$name-${apps:0:2}-$interface"
	
	echo $KEY

	##Prepare the command for execution
	runline=""
	runline+="mpirun --mca btl self,"

	if [[ $interface == ib ]]; then
		runline+="openib --mca btl_openib_if_include mlx5_0:1 "	
	fi

	if [[ $interface == ipoib ]]; then
		runline+="tcp --mca btl_tcp_if_include ib0 "
	fi

	if [[ $interface == eth ]]; then
		runline+="tcp --mca btl_tcp_if_include eno2 "
	fi

	if [[ $apps == bt.D.x || $apps == sp.D.x ]]; then
		PROCS=121
		runline+="-np $PROCS -machinefile $MACHINEFILE_SQUARE_ROOT "
	else 
		PROCS=128
		runline+="-np $PROCS -machinefile $MACHINEFILE_POWER_OF_2 "
	fi
	runline+="$PROGRAM_BIN/$apps "
	runline+="2>> $LOGS/nas.err "
	runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:3}$interface.log > /tmp/nas.out)"
	
	##Execute the experiments
	echo "Running >> $runline <<"
	eval "$runline < /dev/null"

	TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
	echo "${apps:0:2},$interface,$TIME" >> $OUTPUT_NPB_EXEC
	echo "Done!"
done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_NPB_EXEC
exit