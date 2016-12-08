#!/bin/ksh
###################################################
# Author : Sebastien Allamand
# Date: 09/2010
###################################################

##################################################################
#
# We can Create here Dynamics Tags to use in our tests scenarios
#
##################################################################

#Computing Current Date
DATE_NOW=`date +%Y%m%d%H%M%S`
echo "#NOW=$DATE_NOW"
echo "<DATE_NOW>=$DATE_NOW"


DATE_ISSUEINSTANT=`date +%Y-%m-%dT%H%%3A%M%%3A%SZ`
echo "#NOW=$DATE_ISSUEINSTANT"

DATE_TIMESTAMPNORTHAPI=`date --date="-2 hour" +%Y-%m-%dT%H:%M:%S.732Z`
echo "<DATE_TIMESTAMPNORTHAPI>=$DATE_TIMESTAMPNORTHAPI"

DATE_NOW_DAY=`date --date "+3 day" +%Y%m%d`

DATE_EXPIRES_NOWPLUS6MOIS=`date --date="+16070400 sec" "+%a, %d-%b-%Y"` 

