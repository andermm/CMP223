#!/bin/bash

#Variable Directories
BASE=$HOME/CMP223
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
R=$BASE/R

#NPB Variables
NPB=NPB3.4_EXEC
APP_BIN_NPB=$NPB/NPB3.4-MPI/bin
APP_CONFIG_NPB=$NPB/NPB3.4-MPI/config
APP_COMPILE_NPB=$NPB/NPB3.4-MPI

#Ondes3d Variables
ONDES3D=ondes3de
APP_BIN_ONDES3D=$ONDES3D/ondes3d
APP_TEST_ONDES3D_SISHUAN=$ONDES3D/SISHUAN-XML
APP_CONFIG_ONDES3D=$APP_TEST_ONDES3D_SISHUAN/options.h
APP_CONFIG_ONDES3D_PRM=$APP_TEST_ONDES3D_SISHUAN/sishuan.prm
APP_SRC_ONDES3D=$ONDES3D/SRC
APP_LOGS_ONDES3D=$ONDES3D/LOGS

#Alya Variables
ALYA=ALYA_EXEC
ALYA_DIR=$ALYA/Executables/unix
APP_BIN_ALYA=$ALYA_DIR/Alya.x
APP_CONFIG_ALYA=$ALYA/Executables/unix/config.in
APP_ALYA_TUFAN=$ALYA/4_tufan_run/c
ALYA_LOG=$APP_ALYA_TUFAN/c.log

#IMB Variables
IMB=IMBBENCH_EXEC
APP_BIN_IMB=$IMB/bin/imb
IMB_MEMORY=Memory
IMB_MEMORY_PATTERN=8Level 
IMB_MEMORY_MICROBENCHMARK=BST
IMB_CPU=CPU
IMB_CPU_PATTERN=8Level 
IMB_CPU_MICROBENCHMARK=Rand

#Intel MPI Benchmarks Variables
INTEL=mpi-benchmarks
INTEL_SOURCE=$INTEL/src_cpp/Makefile
APP_BIN_INTEL=$INTEL/IMB-MPI1
APP_TEST_INTEL=PingPong

#Other Variables
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_APPS_EXEC=$LOGS/apps_exec.$START.csv
OUTPUT_APPS_EXEC_IMB=$LOGS/imb_exec.$START.csv
OUTPUT_INTEL_EXEC=$LOGS/intel.$START.csv

PARTITION=(hype1 hype2 hype4 hype5)

#Executes the system information collector script
for (( i = 0; i < 4; i++ )); do
	ssh ${PARTITION[i]} '/home/users/ammaliszewski/CMP223/SH/./sys_info_collect.sh'
done

mkdir -p $BENCHMARKS
mkdir -p $BASE/LOGS/BACKUP

########################################IMB#################################################
cd $BENCHMARKS
git clone --recursive https://github.com/Roloff/ImbBench.git
mv ImbBench IMBBENCH_EXEC
cd $IMB; mkdir bin; make

########################################Alya################################################
cd $BENCHMARKS
git clone --recursive https://gitlab.com/ammaliszewski/alya.git
mv alya ALYA_EXEC
cd $ALYA_DIR
cp configure.in/config_gfortran.in config.in
sed -i 's,mpif90,mpifort,g' config.in
./configure -x nastin parall
make metis4 -j 20; make -j 20

#######################################Ondes3d##############################################
cd $BENCHMARKS
git clone --recursive https://bitbucket.org/fdupros/ondes3d.git
mv ondes3d ondes3de
sed -i 's,./../,./BENCHMARKS/ondes3de/,g' $APP_CONFIG_ONDES3D
sed -i 's,./SISHUAN-OUTPUT,./BENCHMARKS/ondes3de/LOGS,g' $APP_CONFIG_ONDES3D_PRM
mkdir -p $ONDES3D/LOGS
sed -i 's,./SISHUAN-XML,./BENCHMARKS/ondes3de/SISHUAN-XML,g' $APP_CONFIG_ONDES3D_PRM
cp $APP_CONFIG_ONDES3D $APP_SRC_ONDES3D; cd $APP_SRC_ONDES3D; make clean; make 

#######################################NPB##################################################
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

for (( n = 0; n < 8; n++ )); do
	for (( i = 0; i < 1; i++ )); do
		echo -e ${apps[n]}"\t"${classes[i]} >> $APP_CONFIG_NPB/suite.def
	done
done
cd $APP_COMPILE_NPB; make suite; cd $BASE

#################################Intel MPI Benchmarks#############################################
cd $BENCHMARKS
git clone --recursive https://github.com/intel/mpi-benchmarks.git
sed -i 's,mpiicc,mpicc,g' $INTEL_SOURCE
sed -i 's,mpiicpc,mpicxx,g' $INTEL_SOURCE
cd $INTEL; make IMB-MPI1

#Define the machine file and experimental project
MACHINEFILE_POWER_OF_2=$LOGS/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$LOGS/nodes_square_root
MACHINEFILE_FULL=$LOGS/nodes_full
echo -e "hype1\nhype2" > $LOGS/nodes_intel
MACHINEFILE_INTEL=$LOGS/nodes_intel
PROJECT=$R/experimental_project_exec.csv

#Read the experimental project
tail -n +2 $PROJECT |
while IFS=\; read -r name apps interface Blocks
do

#Clean the values
	export name=$(echo $name | sed "s/\"//g")
	export apps=$(echo $apps | sed "s/\"//g")
	export interface=$(echo $interface | sed "s/\"//g")

#Define a single key
	KEY="$name-$apps-$interface"
	echo $KEY

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
	if [[ $apps == ondes3d ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == intel ]]; then
		PROCS=2
		runline+="-np $PROCS -machinefile $MACHINEFILE_INTEL "
	elif [[ $apps == imb_memory ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == imb_CPU ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
	elif [[ $apps == Alya.x ]]; then
		PROCS=160
		runline+="-np $PROCS -machinefile $MACHINEFILE_FULL "
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
		runline+="2>> $LOGS/errors_exec "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.exec.log > /tmp/ondes3d.out)"
	elif [[ $apps == intel ]]; then
		runline+="$BENCHMARKS/$APP_BIN_INTEL $APP_TEST_INTEL "
		runline+="2>> $LOGS/errors_exec "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.exec.log > /tmp/intel_mb.out)"
	elif [[ $apps == imb_memory ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMB $IMB_MEMORY $IMB_MEMORY_PATTERN $IMB_MEMORY_MICROBENCHMARK "
		runline+="2>> $LOGS/errors_exec "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.exec.log > /tmp/imb.out)"
	elif [[ $apps == imb_CPU ]]; then
		runline+="$BENCHMARKS/$APP_BIN_IMB $IMB_CPU $IMB_CPU_PATTERN $IMB_CPU_MICROBENCHMARK "
		runline+="2>> $LOGS/errors_exec "
		runline+="&> >(tee -a $LOGS/BACKUP/$apps.$interface.exec.log > /tmp/imb.out)"
	elif [[ $apps == Alya.x ]]; then
		runline+="$BENCHMARKS/$APP_BIN_ALYA $APP_ALYA_TUFAN "
		runline+="2 >> $LOGS/errors_exec "
		runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:4}$interface.exec.log > /tmp/alya.out)"
	else
		runline+="$BENCHMARKS/$APP_BIN_NPB/$apps "
		runline+="2>> $LOGS/errors_exec "
		runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:3}$interface.exec.log > /tmp/nas.out)"
	fi	

#Execute the experiments
	echo "Executing >> $runline <<"
	eval "$runline < /dev/null"

#Save the results
	if [[ $apps == ondes3d ]]; then
		TIME=`grep -i "Timing total" /tmp/ondes3d.out | awk {'print $3'} | head -n 1`
		echo "$apps,$interface,$TIME" >> $OUTPUT_APPS_EXEC
	elif [[ $apps == intel ]]; then
		N=`tail -n +35 /tmp/intel_mb.out | awk {'print $1'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' | wc -l`
		for (( i = 0; i < $N; i++ )); do
			echo "$apps,$interface" >> /tmp/for.out
		done

	tail -n +35 /tmp/intel_mb.out | awk {'print $1'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/BYTES
    tail -n +35 /tmp/intel_mb.out | awk {'print $3'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/TIME
    tail -n +35 /tmp/intel_mb.out | awk {'print $4'} | grep -v '[^ 0.0-9.0]' | sed '/^[[:space:]]*$/d' > /tmp/Mbytes
    paste -d"," /tmp/for.out /tmp/BYTES /tmp/TIME /tmp/Mbytes >> $OUTPUT_INTEL_EXEC
    rm /tmp/for.out; rm /tmp/BYTES; rm /tmp/TIME; rm /tmp/Mbytes
	
	elif [[ $apps == imb_memory ]]; then
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_EXEC_IMB
		rm /tmp/imb_tmp.out
	elif [[ $apps == imb_CPU ]]; then
		for (( i = 0; i < 160; i++ )); do
			echo "$apps,$interface" >> /tmp/imb_tmp.out
		done
		paste -d, /tmp/imb_tmp.out <(awk '{print $8","$4}' /tmp/imb.out) >> $OUTPUT_APPS_EXEC_IMB
		rm /tmp/imb_tmp.out	
	elif [[ $apps == Alya.x ]]; then
		TIME=`cat $ALYA_LOG | grep "TOTAL CPU TIME" | awk '{print $4}'`
		echo "${apps:0:4},$interface,$TIME" >> $OUTPUT_APPS_EXEC
	else	
		TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
		echo "${apps:0:2},$interface,$TIME" >> $OUTPUT_APPS_EXEC
	fi	
	echo "Done!"
done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_APPS_EXEC
sed -i '1s/^/apps,interface,time,rank\n/' $OUTPUT_APPS_EXEC_IMB
sed -i '1s/^/apps,interface,bytes,time,mbytes-sec\n/' $OUTPUT_INTEL_EXEC


#Calls the characterization benchmark script
cd $BASE; nohup ./SH/benchmarks_charac.sh > $BASE/LOGS/script_charac_log 2>&1 &
exit