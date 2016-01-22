#!/bin/sh

CONDOR_LOG=Logs/System/

FILE_LIST=`mktemp failures.XXXXXX`

grep -l held ${CONDOR_LOG}log.* > ${FILE_LIST}

JOB_NUMBERS=`mktemp jobNumbers.XXXXXX`

for file in $(cat ${FILE_LIST});
do
    echo $file
    JOB=`echo $file | awk -v FS="(${CONDOR_LOG}log.|.log)" '{print $2}'`
    echo $JOB >> "${JOB_NUMBERS}"
done
echo done
rm $FILE_LIST

INPUT=./Input/
INPUT_FILE_LIST=`mktemp resubmittion.XXXXXX`
for file in $(cat ${JOB_NUMBERS});
do
    INPUT_FILE=${INPUT}job${file}.txt
    echo $INPUT_FILE >> ${INPUT_FILE_LIST}
done
rm $JOB_NUMBERS

REPROCESS='reprocess.txt'
for file in $(cat ${INPUT_FILE_LIST});
do 
    cat $file >> $REPROCESS
done

rm ${INPUT_FILE_LIST}

