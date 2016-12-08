#!/bin/bash
###################################################################
# Author : Sebastien Allamand
# Skill Center Identity
# Date: 09/2010
# Modified: 01/2013 - Sebastien Allamand - Better Report
# 
###################################################################

CMD_LINE="$0 $*"

PLATEFORME=""
DYNAMIC_TAG_POS=1

ici=`dirname $0`

. ./tools/utils.sh

#Cleanup results directory
if [ ! -d $ici/results/ ]
then
	mkdir -p $ici/results/
fi
cd $ici/results # ou alors 2>&1 /dev/null
find .  -maxdepth 2 -type d -name "result_*" ! -mmin -20 -exec rm -fr {} \; &> /dev/null
find .  -maxdepth 2 -type f -name "Global_result_*" ! -mmin -20 -exec rm -fr {} \; &> /dev/null
cd -
if [ ! -d $ici/results/html/ ]
then
	mkdir -p $ici/results/html
fi

###### Read options
while getopts ":d:t:p:" o
do case $o in
        d)  DIR_TEST=$OPTARG
            ;;
        :)  echo "-$OPTARG can take a directory name in conf/*";
            exit 1;
	    ;;
        t)  TEST=$OPTARG
            ;;
        :)  echo "-$OPTARG can take a extract of filename name in conf/*/*.conf";
            exit 1;
	    ;;
        p)  PLATEFORME=$OPTARG
            ;;
        :)  echo "l'option -$OPTARG peux prendre les valeurs DEV, PROD";
            exit 1;
	    ;;
        \?) echo -e $BLEU"usage: $0 -t <test_number> -d <test_directory> [ -p <filtre_tag_plateforme> ]"$NORMAL
	    echo " <test_number> : the number(or keyworkd) of the Test or 'ALL' keyword to launch all tests"
	    echo " <test_directory> : is the directory (without conf/) where we want launch the tests in it (or ALL to launch all of thems)"
	    echo " <filtre_tag_plateforme> : the optional filter can be used to select the tags accoring to a specific plateforme (DEV/PROD)"
	    exit 1;
            ;;
    esac
done
shift `expr $OPTIND - 1`
cd `dirname $0`

#######################################
# CHECKING INPUTS
#######################################
if [[ -z $DIR_TEST ]]; then
    echo $B"-d xxx is not define so execute all tests"
    DIR_TEST=ALL
fi
if [[ -z $TEST ]]; then
    echo $B"-t xxx is not define so execute all tests"
    TEST=ALL
fi

#############################################
# If DIR_TEST is ALL
# select Test Directories to uses
# Do not select directory starting with _ !!!
#############################################
if [[ $DIR_TEST = "ALL" ]]; then
    DIR_TEST=""
    for x in `ls ../conf/`
    do
      if [[ $x != _* && -d "../conf/$x" ]]; then
          DIR_TEST="$DIR_TEST $x"
      fi
    done
fi

echo -e $B"Validation : Working with Test '$TEST' in directories : '$DIR_TEST' "$N

TEST_NAME=`basename ${DIR_TEST}`
TEST_NAME=`echo ${TEST}_${TEST_NAME}`  

#Definition of base PATH (tests directory)
BASE_PATH=`pwd`
. ./tools/configuration.sh
cd ../
PATH_CURRENT=`pwd`

#GLOBAL_RESULT=tests/results/Global_result_${TEST_NAME}.txt
GLOBAL_RESULT=tests/results/Global_result_${TEST_NAME}.txt
rm -f $GLOBAL_RESULT

echo -e $G"You're executing : $CMD_LINE"$N | tee -a $GLOBAL_RESULT


#Clean up previous result
#rm -rf tests/results/result_${TEST_NAME}/${D}/*
#rm -rf tests/results/result_${TEST_NAME}
#mkdir -p tests/results/result_${TEST_NAME}/${D}


for D in $DIR_TEST
do

#purge des fichiers
  rm -f conf/$D/*~   
  rm -f conf/$D/.*~
  rm -f conf/$D/#*#
  rm -f conf/$D/.#*#

  echo -e $B"working on test : $TEST in directory $D from $DIR_TEST"$N | tee -a $GLOBAL_RESULT

  #Backuping old Tests results
  if [[ ! -d tests/results/result_${TEST_NAME}/${D} ]]; then
      mkdir -p  tests/results/result_${TEST_NAME}/${D}
      #mkdir -p  /tmp/tests/result_${TEST_NAME}/${D}
  fi
  TEST_RESULT=tests/results/result_${TEST_NAME}/${D}/result.txt
  TEST_DETAILED=tests/results/result_${TEST_NAME}/${D}/detailed.log

  #Clean up previous result
  mkdir -p tests/results/result_${TEST_NAME}/${D}
  rm -rf tests/results/result_${TEST_NAME}/${D}/*

  #Create the TAG file needed for the current test
  checkTagFile

  #If Test is ALL we have to execute all tests in the Test Directory
  if [[ $TEST = "ALL" ]]; then
      #for x in `ls conf/$D/*.conf | grep "$FILTRE"`
      for x in `ls conf/$D/*.conf`
      do
	  executeTest #$x is the test path and file
      done
      
  else
      
      for x in `ls conf/$D/* | grep $TEST`
      do
	      executeTest #$x is the test path and file
      done
  fi
    
done

echo ""
echo "--- DETAILED LOG is ---"
#echo `echo $TEST_DETAILED|sed "s/^tests\///g"`
echo `echo Detailed Test log : $TEST_DETAILED`
echo `echo $GLOBAL_RESULT`
echo "-----------------------"


echo -e $CYAN"#######################################################"
echo -e "Test Report $GLOBAL_RESULT:"
echo "#######################################################"
echo -e "$N"
cat $GLOBAL_RESULT


# Check Test Status
NBTOT=0
NBTOT_OK=0
NBTOT_KO=0
for D in $DIR_TEST
  do
    NB=`grep 'request =' tests/results/result_${TEST_NAME}/${D}/detailed.log | wc -l`
    NBTOT=$((NBTOT+NB))
    NB_OK=`grep '32m OK ' tests/results/result_${TEST_NAME}/${D}/detailed.log | wc -l`
    NBTOT_OK=$((NBTOT_OK+NB_OK))
    NB_KO=`grep '31m ERROR ' tests/results/result_${TEST_NAME}/${D}/detailed.log | wc -l`
    NBTOT_KO=$((NBTOT_KO+NB_KO))
    echo -e "$D : Nb test : $NB\t Nb Check OK: $NB_OK\t Nb Checks KO : $NB_KO" . "Detailed Test log : results/result_${TEST_NAME}/${D}/detailed.log" | tee -a $GLOBAL_RESULT  
done
echo -e $G"Number of request tested $NBTOT \t Nb Check OK: $NBTOT_OK\t Nb Checks KO : $NBTOT_KO:"$N | tee -a $GLOBAL_RESULT

if [ $NBTOT_KO -ne "0" ]
then
    #       echo "pas bon"
    err=1
else
    #       echo "tro bon"
    err=0
fi

#si on a eu un pb avec la socket, alors c un KO
if [[ $wtresult -ne 1 ]]; then
    err=1
fi


#if detailed log doesn't exist means that tests isn't running properly, so exit 1
if [ ! -f tests/results/result_${TEST_NAME}/${D}/detailed.log ]
then
    err=1
fi





exit $err



