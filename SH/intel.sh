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
OUTPUT_IMB_EXEC=$LOGS/imb.$START.csv


#################################Intel MPI Benchmarks#############################################
cd $BENCHMARKS
git clone --recursive https://github.com/intel/mpi-benchmarks.git
sed -i 's,mpiicc,mpicc,g' $IMB_SOURCE
sed -i 's,mpiicpc,mpicxx,g' $IMB_SOURCE
cd $IMB; make IMB-MPI1

#Define the machine file and experimental project
echo -e "draco2\ndraco3" > $LOGS/nodes_imb
MACHINEFILE=$LOGS/nodes_imb
PROJECT=$R/intel_mpi_experimental_project_exec.csv
for i in `seq 30`; do shuf -e IMB-MPI1,ib IMB-MPI1,eth IMB-MPI1,ipoib >> $PROJECT ; done
sed -i '1s/^/apps,interface\n/' $PROJECT

#Read the experimental project
tail -n +2 $PROJECT |
while IFS=, read -r apps interface
do

#Clean the values
	export apps=$(echo $apps)
	export interface=$(echo $interface)

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
	runline+="$BENCHMARKS/$APP_BIN_IMB $APP_TEST "
	runline+="2>> $LOGS/errors_imb_exec "
	runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.exec.log > /tmp/intel_mb.out)"
	

#Execute the experiments
	echo "Executing >> $runline <<"
	eval "$runline < /dev/null"

#Save the results
N=`tail -n +35 /tmp/intel_mb.out | awk {'print $1'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' | wc -l`

	for (( i = 0; i < $N; i++ )); do
		echo "$apps,$interface" >> /tmp/for.out
	done
	
	tail -n +35 /tmp/intel_mb.out | awk {'print $1'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/BYTES
    tail -n +35 /tmp/intel_mb.out | awk {'print $3'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/TIME
    tail -n +35 /tmp/intel_mb.out | awk {'print $4'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/Mbytes
    paste -d"," /tmp/for.out /tmp/BYTES /tmp/TIME /tmp/Mbytes >> $OUTPUT_IMB_EXEC
    rm /tmp/for.out; rm /tmp/BYTES; rm /tmp/TIME; rm /tmp/Mbytes
    
    echo "Done!"

done
sed -i '1s/^/apps,interface,bytes,time,mbytes-sec\n/' $OUTPUT_IMB_EXEC
exit
