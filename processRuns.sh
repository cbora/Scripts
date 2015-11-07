#!/bin/sh

set +x
    
#*********************************************
#	Quick 1 in 10 filter based processing
#
#*********************************************

OUTPUT_DIR=/data/user/cbora/RawProcessing_2015/Test/Output
RAW_DIR=/data/wipac/ARA/2014/
STATION=2
NUMBER=$1
TAR_FILES=`mktemp LIST_ARA0$STATION.XXXXXX`

#To log failed event files.
TAR_FAILED='Tar_failures.log'
EVENT_ALL_FAILED='Event_all_failures.log'
EVENT_FAILED='Event_failures.log'


find $RAW_DIR -name *ARA0$STATION*.tar | head -n $NUMBER > $TAR_FILES

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


#Untar the files

for file in $(cat $TAR_FILES);
do
    if [[ -f $file ]]; then


	tar -xvf $file -C $OUTPUT_DIR
	RUN_NUMBER=`echo $file | awk -v FS="(run_|.flat)" '{print $2}'`
	RUN_DATE=`echo $file | awk -v FS="(SPS-ARA/|SPS-ARA-RAW)"`
	echo $RUN_NUMBER
	echo $RUN_NUMBER >> $RUN_FILE_LIST
	NEW_FILE=`ls $OUTPUT_DIR/*$RUN_NUMBER.*.tar | head -n 1`
	tar -xf $NEW_FILE -C $OUTPUT_DIR

	rm ${NEW_FILE}
	rm ${OUTPUT_DIR}*.xml

	#///////////////////////////////////////////////////////////////////////////////////////////
	#
        #
	#        To save disk space, we process a RUN fully(until we a have a .root file) \
	#                     before we move on to the next run
	#
	#///////////////////////////////////////////////////////////////////////////////////////

	# One in Ten

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

	if  test `cat ${EVENT_FILE_LIST} | wc -l` -gt 0 ; then
	    ${ARA_UTIL_INSTALL_DIR}/bin/quickOneInTenFilter ${EVENT_FILE_LIST} ${ONE_IN_TEN_DIR} ${RUN_NUMBER}}
	    rm ${EVENT_FILE_LIST}
	    echo "Done Event File"
	else
	    rm ${EVENT_FILE_LIST}
	    echo "No event files"
	    echo $file "No event files 100" >> ${EVENT_ALL_FAILED}
	fi

	rm -rf ${RUN_DIR}
	
	#============================================================
	#
	#               Producing .root files
	#
	#============================================================
	RAW_DIR=${ONE_IN_TEN_DIR}/run_${RUN_NUMBER}

	ROOT_DIR=${OUTPUT_DIR}/${RUN_DATE}/run${RUN_NUMBER}

	if [[ -d ${ROOT_DIR} ]]; then
	    echo $ROOT_DIR "exists"
	else
	    mkdir ${ROOT_DIR}
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
    else
	echo $file >> ${TAR_FAILED}
    fi    
done

rm $TAR_FILES
