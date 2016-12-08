#!/bin/ksh
###################################################
# Author : Sebastien Allamand
# Skill Center Identity
# Date: 09/2010
###################################################

#######################################
# Default Port and MCO to use for test
# Note : this can be overrided in Tests .conf file using the specific keywork :
# ##URLTEST=<ip or dns>:<port>
#######################################
IP=localhost
PORT=80

#Default MCO to use (use different tags files)
#MCO=com

#Default Plateform to use (use different tags files)
if [[ $PLATEFORME = "" ]]; then
    PLATEFORME=DEV
fi

#TEAM="MY"

PATH_TAGS="$BASE_PATH/../tags"

TESTNAME="" # init

DIR_SCRIPT=`pwd`

#######################################
# TAG File Creation
#######################################

#convert utf8 to latin for some specific tests
function checkTagFile
{
    PWDCURRENT=`pwd`
    cd $PATH_TAGS

    if [ ! -f TAGS_FILE_${PLATEFORME} ]; then
	echo -e $R"You must defines your tags in file named "`pwd`"/TAGS_FILE_${PLATEFORME}"$N
	exit 1
    fi

    grep "\---" TAGS_FILE_${PLATEFORME}
    if [ $? -eq 0 ]
    then
	echo $R"The string --- is forbiden in tags files"$N
	exit 1
    fi
    cd $PWDCURRENT

    FINAL_TAGS_FILE="tags/TAGS_FILE_${PLATEFORME}"
    return 0
}


function executeTest
{
    echo -e $G"$D $x"$N | tee -a $TEST_DETAILED | tee -a $TEST_RESULT

    TESTNAME=`cat $x | grep "#TestName#" | cut -d' ' -f2-`
    echo $TESTNAME | tee -a $TEST_DETAILED | tee -a $TEST_RESULT


    #If a test as the KeyWork (DEACTIVATED) in the line containing #TestName# then it will be not executed
    DEACTIVATED=`echo $TESTNAME | tee -a $TEST_DETAILED | tee -a $TEST_RESULT | grep "(DEACTIVATED)"`
    MANUAL=`echo $TESTNAME | grep "MANUAL"`

    #If (DEACTIVATED) not found, we execute the test
    if [[ ! $DEACTIVATED = "" ]]; then
	echo -e $BLEU"=> $D $x"$NORMAL" $ROUGE DEACTIVATED $NORMAL ($TESTNAME)" | tee -a $GLOBAL_RESULT
	return
    fi
	#./tools/launchwt.sh localhost $PORT $x $FINAL_TAGS_FILE | tee -a $TEST_DETAILED | grep Validation | tee -a $TEST_RESULT

    if [[ ! $MANUAL = "" ]]; then
	echo -e $BLEU"=> $D $x"$NORMAL" $BLEU MANUAL (NOT RUN) $NORMAL ($TESTNAME)" | tee -a $GLOBAL_RESULT
	return
    fi

    #Passage par defaut sur TB2

#	if [[ -f /usr/lib/perl5/vendor_perl/5.8.3/i386-linux-thread-multi/Time/HiRes.pm ]]; then
	    echo -e $BLUE"./tests/tools/wt_check_v2.pl -H $IP -P $PORT -I $x -T $FINAL_TAGS_FILE -d $RUN_DISTANT"$NORMAL   

	    ./tests/tools/wt_check_v2.pl -H $IP -P $PORT -I $x -T $FINAL_TAGS_FILE -d $RUN_DISTANT > /tmp/check_$TIMESTAMP
	    wtresult=$?
	    #echo "wt_check.pl is '$wtresult'";
	    
	    #sauvegarde des resultat des tests
	    STEPS_RES=`cat /tmp/check_$TIMESTAMP | grep "Result Step"`
	    cat /tmp/check_$TIMESTAMP | tee -a $TEST_DETAILED | grep -a Validation | tee -a $TEST_RESULT | tee $TMP_RESULT
            rm -f /tmp/check_$TIMESTAMP

	    if [[ $wtresult -ne 1 ]]; then
		echo -e $ROUGE"ERROR Le script c'est mal execute"$NORMAL | tee -a $GLOBAL_RESULT;
		TMP="Connexion  ERROR  to enabler -- check targeted Host:Port"
	    else
		echo "Le script c'est bien execute";
		TMP=`grep " ERROR " $TEST_RESULT`
	    fi


	    echo "Final check";


	if  [[ $TMP = "" ]]; then
	    #si vide ya pas eu d'erreurs on affiche OK
	    if [[ $MANUAL = "" ]]; then
		echo -e $BLEU"=> $D $x"$NORMAL" $VERT OK $NORMAL ($TESTNAME)" | tee -a $GLOBAL_RESULT
		echo -e "$STEPS_RES" >> $GLOBAL_RESULT
	    else
		echo -e $BLEU"=> $D $x"$NORMAL" $BLEU MANUAL(OK) $NORMAL ($TESTNAME)" | tee -a $GLOBAL_RESULT
		echo -e "$STEPS_RES" >> $GLOBAL_RESULT
	    fi
	else
	    #il y a eu des erreurs
		if [[ $MANUAL = "" ]]; then
		    echo -e $BLEU"=> $D $x"$NORMAL" $ROUGE KO $NORMAL ($TESTNAME)" | tee -a $GLOBAL_RESULT
		    echo -e "$STEPS_RES" >> $GLOBAL_RESULT
		else
		    echo -e $BLEU"=> $D $x"$NORMAL" $BLEU MANUAL(KO) $NORMAL ($TESTNAME)" | tee -a $GLOBAL_RESULT
		    echo -e "$STEPS_RES" >> $GLOBAL_RESULT
		fi
	fi

	    echo "End Execute Test";
}
