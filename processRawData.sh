#!/bin/sh

set +x

JOB_NUMBER=$1    
STATION=2

RAW_DIR=/data/wipac/ARA/2014/

#Working directory of unzipping raw data
OUTPUT_DIR=/data/user/cbora/Processing/Temp/Job_${JOB_NUMBER}

#Actual directory where l0 files will be saved
L0_DIR=/data/user/cbora/L0_2014/ARA02
LOG_DIR=/data/user/cbora/Processing/Log/Job_${JOB_NUMBER}

#Actual input file
TAR_FILES=/data/user/cbora/Processing/Input/job${JOB_NUMBER}

#binaries
RANDOM_FILTER_BIN=/data/user/cbora/RawProcessing_2015/ProcessingCode/build/randomFilter
ARA_EVENT_PICKER_BIN=/data/user/cbora/RawProcessing_2015/ProcessingCode/build/AraEventPicker
NUM_EVENTS=100

#To log failed event files.
TAR_FAILED=${LOG_DIR}/'Tar_failures'${JOB_NUMBER}'.log'
EVENT_ALL_FAILED=${LOG_DIR}/'Event_all_failures'${JOB_NUMBER}'.log'
EVENT_FAILED=${LOG_DIR}/'Event_failures'${JOB_NUMBER}'.log'

#to keep pedestal runs and small runs
SMALL_RUNS=${LOG_DIR}/small_runs_station${STATION}.txt
PEDESTAL_RUNS=${LOG_DIR}/pedestal_runs_station${STATION}.txt
RUN_FILE_LIST=${LOG_DIR}/runs.txt

#Dummy ped file(we don't really need one for the random filter)
PED_FILE=/home/meures/data_files/ARA03/pedestals/run_003787/pedestalValues.run003787.dat


#////////////////////////////////////////////////////////
#
#
#       Actual data processing begins here
#
#////////////////////////////////////////////////////////

cat $TAR_FILES

# check to see if we have enough files to process
if test `cat $TAR_FILES | wc -l` -lt 1; then
    echo "No FILES to process... EXITING!!!"
    rm ${TAR_FILES}
    return 1
fi

if [[ -d $OUTPUT_DIR ]]; then
    echo $OUTPUT_DIR "exsists"
else
    mkdir ${OUTPUT_DIR}
fi

if [[ -d $LOG_DIR ]]; then
    echo $LOG_DIR "exsists"
else
    mkdir ${LOG_DIR}
fi


#Untar the files

for file in $(cat $TAR_FILES);
do
    if [[ -f $file ]]; then
	
	#Unpack file

	tar -xf $file -C $OUTPUT_DIR
	RUN_NUMBER=`echo $file | awk -v FS="(run_|.flat)" '{print $2}'`
	RUN_DATE=`echo $file | awk -v FS="(SPS-ARA/|SPS-ARA-RAW)" '{print $2}'`
	echo $RUN_NUMBER
	echo $RUN_NUMBER >> $RUN_FILE_LIST
	NEW_FILE=`ls $OUTPUT_DIR/*$RUN_NUMBER.*.tar | head -n 1`
	tar -xf $NEW_FILE -C $OUTPUT_DIR

	rm ${NEW_FILE}
	rm ${OUTPUT_DIR}/*.xml

	#/////////////////////////////////////
	#
	# Filter out pedestal files
	#
	#////////////////////////////////////
	
	GZ=${OUTPUT_DIR}/run_${RUN_NUMBER}/event
	RUN_SIZE=$( du -k -s ${OUTPUT_DIR}/run_${RUN_NUMBER} | cut -f 1)

	if [[ -d $GZ ]]; then
	    if [[ $RUN_SIZE -lt 4000 ]]; then
		# small runs
		echo $RUN_NUMBER $RUN_SIZE >> ${SMALL_RUNS}
		continue
	    fi
	else
	    #pedestal runs
	    echo $RUN_NUMBER $RUN_SIZE >> ${PEDESTAL_RUNS}
	    continue
	fi

	#///////////////////////////////////////////////////////////////////////////////////////////
	#
        #
	#        To save disk space, we process a RUN fully(until we a have a .root file) \
	#                     before we move on to the next run
	#
	#///////////////////////////////////////////////////////////////////////////////////////

	# All untared data
	RUN_DIR=${OUTPUT_DIR}/run_${RUN_NUMBER}
	EVENT_FILE_LIST=`mktemp event.XXXXXX`
	for event in ${RUN_DIR}/event/ev_*/*; 
	do
	    if [[ -f $event ]]; then
		echo $event >> ${EVENT_FILE_LIST}
	    fi
	done

	ONE_IN_TEN_DIR=${OUTPUT_DIR}/OneInTen
	if [[ -d ${ONE_IN_TEN_DIR} ]]; then
	    echo ""
	else
	    echo "One in ten directory doesn't exist"
	    mkdir ${ONE_IN_TEN_DIR}
	fi
	    
	#=====================================================
	#
	#              Filtering data
	#
	#=====================================================

	MONITOR_FILE=${LOG_DIR}/monitoringThis${RUN_NUMBER}.root
	
	if test `cat ${EVENT_FILE_LIST} | wc -l` -gt 0; then
	    ${RANDOM_FILTER_BIN} ${EVENT_FILE_LIST} ${ONE_IN_TEN_DIR} ${RUN_NUMBER} ${MONITOR_FILE} ${NUM_EVENTS} ${PED_FILE}
	    rm ${EVENT_FILE_LIST}
	    echo "Done event File"
	else
	    rm ${EVENT_FILE_LIST}
	    echo "No event Files"
	    echo $file "No event files 100" >> ${EVENT_ALL_FAILED}
	fi
	
	#Ara event picker stuff
	FILE_LIST=`mktemp event$RUN_NUMBER.XXXXXX`
	for eventfile in ${ONE_IN_TEN_DIR}/run_${RUN_NUMBER}/event/ev_*/*;
	do
	    if [[ -f $eventfile ]]; then
		echo $eventfile >> ${FILE_LIST}
	    fi
	done
	
	OUT_DIR=${OUTPUT_DIR}/Picked

	if [[ -d ${OUT_DIR} ]]; then
	    echo ""
	else
	    echo "One in ten directory doesn't exist"
	    mkdir ${OUT_DIR}
	fi


	if test `cat ${FILE_LIST} | wc -l` -gt 0; then
	    
	    ${ARA_EVENT_PICKER_BIN} ${FILE_LIST} ${OUT_DIR} ${RUN_NUMBER}
	    rm ${FILE_LIST}
	    echo "done event file"
	else
	    rm ${FILE_LIST}
	    echo "no event file"
	fi

	cp -rf ${RUN_DIR}/eventHk ${OUT_DIR}/run_${RUN_NUMBER}/
	cp -rf ${RUN_DIR}/sensorHk ${OUT_DIR}/run_${RUN_NUMBER}/
	cp -rf ${RUN_DIR}/monitorHk ${OUT_DIR}/run_${RUN_NUMBER}/
	

	rm -rf ${RUN_DIR}
	#============================================================
	#
	#               Producing .root files
	#
	#============================================================

	RAW_DIR=${OUT_DIR}/run_${RUN_NUMBER}

	ROOT_DIR=${L0_DIR}/${RUN_DATE}/run${RUN_NUMBER}

	if [[ -d ${ROOT_DIR} ]]; then
	    echo $ROOT_DIR "exists"
	else
	    mkdir -p ${ROOT_DIR}
	fi
	    
	EVENT_FILE=${ROOT_DIR}/event${RUN_NUMBER}.root
	SENSOR_HK_FILE=${ROOT_DIR}/sensorHk${RUN_NUMBER}.root
	EVENT_HK_FILE=${ROOT_DIR}/eventHk${RUN_NUMBER}.root


	echo "Starting Event File"
	EVENT_FILE_LIST=`mktemp event.XXXX`
	for file in ${RAW_DIR}/event/ev_*/*; 
	do
	    if [[ -f $file ]]; then
		echo $file >> ${EVENT_FILE_LIST}
	    fi
	done

	if  test `cat ${EVENT_FILE_LIST} | wc -l` -gt 0 ; then
	    ${ARA_UTIL_INSTALL_DIR}/bin/makeAtriEventTree ${EVENT_FILE_LIST} ${EVENT_FILE} ${RUN_NUMBER}
	    rm ${EVENT_FILE_LIST}
	    echo "Done Event File"
	else
	    rm ${EVENT_FILE_LIST}
	    echo "No event files"
	    echo $file "No event files" >> ${EVENT_FAILED}
	fi

	echo "Starting Sensor Hk File"
	SENSOR_HK_FILE_LIST=`mktemp sensor.XXXX`
	for file in ${RAW_DIR}/sensorHk/sensorHk_*/*; 
	do
	    if [[ -f $file ]]; then
		echo $file >> ${SENSOR_HK_FILE_LIST}
	    fi
	done

	if  test `cat ${SENSOR_HK_FILE_LIST} | wc -l` -gt 0 ; then
	    ${ARA_UTIL_INSTALL_DIR}/bin/makeAtriSensorHkTree ${SENSOR_HK_FILE_LIST} ${SENSOR_HK_FILE} ${RUN_NUMBER}
	    rm ${SENSOR_HK_FILE_LIST}
	    echo "Done Sensor Hk File"
	else
	    rm ${SENSOR_HK_FILE_LIST}
	    echo "No sensor hk files"
	fi


	echo "Starting Event Hk File"
	EVENT_HK_FILE_LIST=`mktemp event.XXXX`
	for file in ${RAW_DIR}/eventHk/eventHk_*/*; 
	do
	    if [[ -f $file ]]; then
		echo $file >> ${EVENT_HK_FILE_LIST}
	    fi
	done


	if  test `cat ${EVENT_HK_FILE_LIST} | wc -l` -gt 0 ; then
	    ${ARA_UTIL_INSTALL_DIR}/bin/makeAtriEventHkTree ${EVENT_HK_FILE_LIST} ${EVENT_HK_FILE} ${RUN_NUMBER}
	    rm ${EVENT_HK_FILE_LIST}
	    echo "Done Event Hk File"
	else
	    rm ${EVENT_HK_FILE_LIST}
	    echo "No event hk files"
	fi

	echo "RUN NUMBER ............." ${RUN_NUMBER}
	#clear
	rm -rf ${ONE_IN_TEN_DIR}
        rm -rf ${OUT_DIR}
    else
	echo $file >> ${TAR_FAILED}
    fi    
done

rm $TAR_FILES