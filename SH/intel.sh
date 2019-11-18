#!/bin/bash

#Variable Directories
BASE=$HOME/CMP223
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
R=$BASE/R

#Intel MPI Benchmarks Variables
IMB=mpi-benchmarks
IMB_SOURCE=$IMB/src_cpp/Makefile
APP_BIN_IMB=$IMB/IMB-MPI1
APP_TEST=PingPong
PROCS=2
#Other Variables
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_IMB_EXEC=$LOGS/IMB.$START.csv


#################################Intel MPI Benchmarks#############################################
cd $BENCHMARKS
git clone --recursive https://github.com/intel/mpi-benchmarks.git
cd $IMB
sed -i 's,mpiicc,mpicc,g' $IMB_SOURCE
sed -i 's,mpiicpc,mpicxx,g' $IMB_SOURCE
make IMB-MPI1

#Define the machine file and experimental project
echo -e "draco2\ndraco3" > $LOGS/imb_nodes
MACHINEFILE=$LOGS/imb_nodes
for i in `seq 30`; do shuf -e IMB-MPI1,ib IMB-MPI1,eth IMB-MPI1,ipoib >> $PROJECT ; done
sed -i '1s/^/apps,interface\n/' $PROJECT
PROJECT=$R/intel_mpi_experimental_project_exec.csv


for i in {1..10}; do mpiexec --mca btl self,tcp --mca btl_tcp_if_include eno2 -np 2 -machinefile nodes IMB-MPI1 PingPong; done

#Read the experimental project
tail -n +2 $PROJECT |
while IFS=\; read -r apps interface
do

#Clean the values
	export apps=$(echo $apps | sed "s/\"//g")
	export interface=$(echo $interface | sed "s/\"//g")

#Define a single key
	KEY="$apps-$interface"
	echo $KEY

#Prepare the command for execution
	runline=""
	runline+="mpiexec -np $PROCS -machinefile $MACHINEFILE --mca btl self,"

#Select interface
	if [[ $interface == ib ]]; then
		runline+="openib --mca btl_openib_if_include mlx5_0:1 "	
	elif [[ $interface == ipoib ]]; then
		runline+="tcp --mca btl_tcp_if_include ib0 "
	else
		runline+="tcp --mca btl_tcp_if_include eno2 "
	fi
	
#Save the output according to the app
	runline+="$BENCHMARKS/APP_BIN_IMB $TEST "
	runline+="2>> $LOGS/errors_imb_exec "
	runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.exec.log > /tmp/intel_mb.out)"
	

#Execute the experiments
	echo "Executing >> $runline <<"
	eval "$runline < /dev/null"

#Save the results
		for (( i = 0; i < 22; i++ )); do
			echo "$apps,$interface" >> /tmp/intel_mb_tmp.out 
		done
	BYTES=`awk {'print $1'} /tmp/intel_mb.out | tail -n +35 | head -n -5`
	TIME=`awk {'print $3'} /tmp/intel_mb.out | tail -n +35 | head -n -5`
	Mbytes=`awk {'print $4'} /tmp/intel_mb.out | tail -n +35 | head -n -5`
	paste -d"," /tmp/intel_mb_tmp.out $BYTES $TIME $Mbytes >> $OUTPUT_IMB
	rm /tmp/imb_tmp.out	
	echo "Done!"

done
sed -i '1s/^/apps,interface,bytes,time,mbytes-sec\n/' $OUTPUT_IMB
exit