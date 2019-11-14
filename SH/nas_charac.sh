#!/bin/bash

BASE=$HOME/CMP223
SCRIPTS=$BASE/SH
BENCHMARKS=$BASE/BENCHMARKS
LOGS=$BASE/LOGS
TRACE=$LOGS/TRACE
R=$BASE/R
NPB_CHARAC=$BENCHMARKS/NPB3.4_CHARAC
APP_BIN_NPB=$NPB_CHARAC/NPB3.4-MPI/bin
APP_CONFIG_NPB=$NPB_CHARAC/NPB3.4-MPI/config
APP_COMPILE_NPB=$NPB_CHARAC/NPB3.4-MPI
START=`date +"%d-%m-%Y.%Hh%Mm%Ss"`
OUTPUT_NPB_CHARAC=$LOGS/npb_charac.$START.csv
DoE=$BASE/R/DoE_npb_charac.R
AKY_BUILD=$BENCHMARKS/akypuera/build
PAJE_BUILD=$BENCHMARKS/pajeng/build
PARTITION=draco

mkdir -p $BENCHMARKS $TRACE
#Download and install ScoreP
cd $BENCHMARKS
wget -c https://www.vi-hps.org/cms/upload/packages/scorep/scorep-6.0.tar.gz
tar -zxf scorep-6.0.tar.gz; rm -f scorep-6.0.tar.gz 
cd scorep-6.0; ./configure --prefix=/tmp/install; make; make install

#Download and install Akypueira
cd $BENCHMARKS
git clone --recursive https://github.com/schnorr/akypuera.git
mkdir -p akypuera/build; cd akypuera/build; 
cmake -DOTF2=ON -DOTF2_PATH=/tmp/install/ -DCMAKE_INSTALL_PREFIX=/tmp/akypuera/ ..
make; make install

#Download and install PajeNG
cd $BENCHMARKS
git clone --recursive https://github.com/schnorr/pajeng.git
mkdir -p pajeng/build ; cd pajeng/build; cmake .. ; make install

#Download and compile NPB
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

#Insert app and class in suite.def
for (( n = 0; n < 8; n++ )); do
	for (( i = 0; i < 1; i++ )); do
		echo -e ${apps[n]}"\t"${classes[i]} >> $APP_CONFIG_NPB/suite.def
	done
done

##Compile NPB
cd $APP_COMPILE_NPB; make suite; cd $BASE

mkdir -p $LOGS/BACKUP

##Define the machine file for MPI
MACHINEFILE_POWER_OF_2=$LOGS/nodes_power_of_2
MACHINEFILE_SQUARE_ROOT=$LOGS/nodes_square_root

#Generate the experimental project
#Rscript $DoE
PROJECT=$R/experimental_project_npb_charac.csv

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
	runline+="mpirun "
	runline+="-x SCOREP_EXPERIMENT_DIRECTORY=$TRACE/scorep_${apps:0:3}$interface "
    runline+="-x SCOREP_ENABLE_TRACING=TRUE "
    runline+="-x SCOREP_ENABLE_PROFILING=FALSE "
    runline+="--mca btl self,"

	if [[  == ib ]]; then
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
	runline+="$APP_BIN_NPB/$apps "
	runline+="2>> $LOGS/nas_trace.err "
	runline+="&> >(tee -a $LOGS/BACKUP/${apps:0:3}$interface_trace.log > /tmp/nas.out)"
	
	##Execute the experiments
	echo "Running >> $runline <<"
	eval "$runline < /dev/null"

	TIME=`grep -i "Time in seconds" /tmp/nas.out | awk {'print $5'}`
	echo "${apps:0:2},$interface,$TIME" >> $OUTPUT_NPB_CHARAC
	$AKY_BUILD/./otf22paje $TRACE/scorep_${apps:0:3}$interface/traces.otf2 > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace
	$PAJE_BUILD/./pj_dump $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.trace | grep ^State > $TRACE/scorep_${apps:0:3}$interface/${apps:0:2}.csv
	echo "Done!"
done
sed -i '1s/^/apps,interface,time\n/' $OUTPUT_NPB_CHARAC
exit

#$HOME/Desktop/EXP/akypuera/build/./otf22paje traces.otf2 > otf2.trace

#pj_dump otf2.trace | grep ^State > rastro.csv

#IpoIB
#mpirun -np 128 --mca btl self,tcp --mca btl_tcp_if_include ib0 \
#-machinefile /home/users/ammaliszewski/SMPE_1920/LOGS/nodes_power_of_2 \
#/home/users/ammaliszewski/SMPE_1920/NPB3.4/NPB3.4-MPI/bin/ft.C.x

#Ethernet
#mpirun -np 128 --mca btl self,tcp --mca btl_tcp_if_include eno2 \
#-machinefile /home/users/ammaliszewski/SMPE_1920/LOGS/nodes_power_of_2 \
#/home/users/ammaliszewski/SMPE_1920/NPB3.4/NPB3.4-MPI/bin/ft.D.x

mpirun -x SCOREP_EXPERIMENT_DIRECTORY=/home/users/ammaliszewski/CMP223/LOGS/TRACE/scorep_mg.eth
-x SCOREP_ENABLE_TRACING=TRUE 
-x SCOREP_ENABLE_PROFILING=FALSE --mca btl self,tcp --mca btl_tcp_if_include eno2 -np 128 -machinefile
/home/users/ammaliszewski/CMP223/LOGS/nodes_power_of_2
/home/users/ammaliszewski/CMP223/BENCHMARKS/NPB3.4_CHARAC/NPB3.4-MPI/bin/mg.D.x
2>> /home/users/ammaliszewski/CMP223/LOGS/nas.err_trace &> >(tee -a
/home/users/ammaliszewski/CMP223/LOGS/BACKUP/mg.eth_trace.log > /tmp/nas.out)

#Infiniband
#mpirun -np 128 --mca btl self,openib \
#-machinefile /home/users/ammaliszewski/SMPE_1920/LOGS/nodes_power_of_2 \
#--mca btl_openib_if_include mlx5_0:1 /home/users/ammaliszewski/SMPE_1920/NPB3.4/NPB3.4-MPI/bin/ft.D.x

