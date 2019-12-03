BASE=$HOME/CMP223
CONTROL_FILE_OUTPUT=$BASE/LOGS/SYS_INFO/env_info.org

lstopo $BASE/LOGS/SYS_INFO/$hostname.pdf

##################################################
# Collecting metadata
echo "* MACHINE INFO $hostname:" >> $CONTROL_FILE_OUTPUT

echo "** PEOPLE LOGGED WHEN EXPERIMENT STARTED:" >> $CONTROL_FILE_OUTPUT
who >> $CONTROL_FILE_OUTPUT
echo "############################################" >> $CONTROL_FILE_OUTPUT

echo "** ENVIRONMENT VARIABLES:" >> $CONTROL_FILE_OUTPUT
env >> $CONTROL_FILE_OUTPUT
echo "############################################" >> $CONTROL_FILE_OUTPUT

echo "** HOSTNAME:" >> $CONTROL_FILE_OUTPUT
hostname >> $CONTROL_FILE_OUTPUT
echo "############################################" >> $CONTROL_FILE_OUTPUT

if [[ -n $(command -v lstopo) ]];
then
	echo "** MEMORY HIERARCHY:" >> $CONTROL_FILE_OUTPUT
	lstopo --of console >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [ -f /proc/cpuinfo ];
then
	echo "** CPU INFO:" >> $CONTROL_FILE_OUTPUT
	cat /proc/cpuinfo >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ];
then
	echo "** CPU GOVERNOR:" >> $CONTROL_FILE_OUTPUT
	ONLINECPUS=$(for CPU in $(find /sys/devices/system/cpu/ | grep cpu[0-9]*$); do [[ $(cat $CPU/online) -eq 1 ]] && echo $CPU; done | grep cpu[0-9]*$ | sed 's/.*cpu//')
	for PU in ${ONLINECPUS}; do
		echo -n "CPU frequency for cpu${PU}: " >> $CONTROL_FILE_OUTPUT
		cat /sys/devices/system/cpu/cpu${PU}/cpufreq/scaling_governor >> $CONTROL_FILE_OUTPUT
	done
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ];
then
	echo "** CPU FREQUENCY:" >> $CONTROL_FILE_OUTPUT
	ONLINECPUS=$(for CPU in $(find /sys/devices/system/cpu/ | grep cpu[0-9]*$); do [[ $(cat $CPU/online) -eq 1 ]] && echo $CPU; done | grep cpu[0-9]*$ | sed 's/.*cpu//')
	for PU in ${ONLINECPUS}; do
		echo -n "CPU frequency for cpu${PU}: " >> $CONTROL_FILE_OUTPUT
		cat /sys/devices/system/cpu/cpu${PU}/cpufreq/scaling_cur_freq >> $CONTROL_FILE_OUTPUT
	done
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [ -f /usr/bin/cpufreq-info ];
then
	echo "** CPUFREQ_INFO" >> $CONTROL_FILE_OUTPUT
	cpufreq-info >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [ -f /usr/bin/lspci ];
then
	echo "** LSPCI" >> $CONTROL_FILE_OUTPUT
	lspci >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [ -f /usr/bin/ompi_info ];
then
	echo "** OMPI_INFO" >> $CONTROL_FILE_OUTPUT
	ompi_info --all >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [ -f /sbin/ifconfig ];
then
	echo "** IFCONFIG" >> $CONTROL_FILE_OUTPUT
	/sbin/ifconfig >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [[ -n $(command -v nvidia-smi) ]];
then
	echo "** GPU INFO FROM NVIDIA-SMI:" >> $CONTROL_FILE_OUTPUT
	nvidia-smi -q >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi 

if [ -f /proc/version ];
then
	echo "** LINUX AND GCC VERSIONS:" >> $CONTROL_FILE_OUTPUT
	cat /proc/version >> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

if [[ -n $(command -v module) ]];
then
	echo "** MODULES:" >> $CONTROL_FILE_OUTPUT
	module list 2>> $CONTROL_FILE_OUTPUT
	echo "############################################" >> $CONTROL_FILE_OUTPUT
fi

echo "** TCP PARAMETERS" >> $CONTROL_FILE_OUTPUT
FILES="/proc/sys/net/core/rmem_max \
/proc/sys/net/core/wmem_max \
/proc/sys/net/core/rmem_default \
/proc/sys/net/core/wmem_default \
/proc/sys/net/core/netdev_max_backlog \
/proc/sys/net/ipv4/tcp_rmem \
/proc/sys/net/ipv4/tcp_wmem \
/proc/sys/net/ipv4/tcp_mem"

for FILE in $FILES; do
	echo "cat $FILE"
	cat $FILE
done >> $CONTROL_FILE_OUTPUT