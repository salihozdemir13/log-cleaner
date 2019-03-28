#!/usr/bin/env bash
# Author: Salih Ozdemir | 2018

# Stop script when an unexpected error occurs.
set -o errexit
set -o pipefail

# Specify App Path and Properties File
LogCleanerPath=/path/to/LogCleaner
propertiesFile=$LogCleanerPath/app.properties

# Set Global Variables
diskThresholdTemp=$(cat $propertiesFile | awk -F"=" '{print $2}' | awk "NR==1")
maxFileAgeInDays=$(cat $propertiesFile | awk -F"=" '{print $2}' | awk "NR==2")
logPathLocations=$(cat $propertiesFile | awk -F"=" '{print $2}' | awk "NR==3" | tr ',' ' ')
fileExtensions=$(cat $propertiesFile | awk -F"=" '{print $2}' | awk "NR==4" | tr ',' ' ')
monitoringMountDisks=$(cat $propertiesFile | awk -F"=" '{print $2}' | awk "NR==5" | tr ',' ' ')
mailTOs=$(cat $propertiesFile | awk -F"=" '{print $2}' | awk "NR==6")
domain="$(hostname)"

TIMESTAMP="[`date`]"
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>$LogCleanerPath/log/LOGCLEANER.log 2>&1

if [ -f "$propertiesFile" ]
then
	printf "$TIMESTAMP [INFO] [Properties file found] \n"

	monitoringMountDisksCount=$(echo $monitoringMountDisks | awk '{print NF}')
        count=1
        while [ $count -le $monitoringMountDisksCount ]
        do
                monitoringMountDisk=$(echo $monitoringMountDisks | awk '{print $'$count'}')
                
		diskThreshold=$(cat $propertiesFile | awk -F"=" '{print $2}' | awk "NR==1" | tr '%' ' ')
		diskUsageBS=$(df $monitoringMountDisk | grep $monitoringMountDisk | awk '{print $5}')
	        diskUsage=$(echo $diskUsageBS | tr '%' ' ')

        	echo "$TIMESTAMP [INFO] [$monitoringMountDisk disk usage --> $diskUsageBS]"
        	if [ $diskUsage -gt $diskThreshold ]
        	then
               	        printf "$TIMESTAMP [WARN] [!! LogCleaner is triggered, going to clean log files !!] \n"
                	printf "$TIMESTAMP [INFO] [Extensions to be cleaned --> $fileExtensions] \n"

			cp $LogCleanerPath/LogCleanerMailTemplate.html $LogCleanerPath/LogCleanerMail.html
			> $LogCleanerPath/searchResult.txt
			
			fileExtensionCount=$(echo $fileExtensions | awk '{print NF}')
        		for((i=1; i<=$fileExtensionCount; i+=1));
        		do
				find $logPathLocations -type f -iname $(echo $fileExtensions | awk '{print $'$i'}') -mtime +$maxFileAgeInDays >> $LogCleanerPath/searchResult.txt
                		#find $logPathLocations -type f -iname '$(echo $fileExtensions | awk '{print $'$i'}')' -mtime +$maxFileAgeInDays -exec rm {} \;  to remove log files
        		done
			
			awk 'BEGIN { print "<tbody>" }
     			{ print "<tr><td height=""\"20\""" color=""\"rgb(102,102,102)\""" align=""\"left\""" style=""\"word-break:break-all; word-wrap: break-word; border-bottom: 1px solid 			     rgb(153,153,153); border-left: 1px solid rgb(153,153,153); border-right: 1px solid rgb(153,153,153); color: rgb(102,102,102);font-size: 12px; font-family: Helvetica, 			      sans-serif; mso-line-height-rule: exactly; line-height: 20px;\""">" $1 "</td></tr>" }
     			END   { print "</tbody>" }' $LogCleanerPath/searchResult.txt > $LogCleanerPath/listOfContent.html

			title="LogCleaner Message : "
                        message="Status Report"
			totalLogFileCount=$(cat $LogCleanerPath/searchResult.txt | wc -l)
			tbody=$(cat $LogCleanerPath/listOfContent.html)
			diskUsageAS=$(df $monitoringMountDisk | grep $monitoringMountDisk | awk '{print $5}')

			perl -p -i -e "s/TITLE/$title/g" $LogCleanerPath/LogCleanerMail.html
			perl -p -i -e "s/MESSAGE/$message/g" $LogCleanerPath/LogCleanerMail.html
			perl -p -i -e "s/DOMAIN/$domain/g" $LogCleanerPath/LogCleanerMail.html
			perl -p -i -e "s/THRESHOLD/$diskThresholdTemp/g" $LogCleanerPath/LogCleanerMail.html
			perl -p -i -e "s/BDISKUSAGE/$diskUsageBS/g" $LogCleanerPath/LogCleanerMail.html
			perl -p -i -e "s/ADISKUSAGE/$diskUsageAS/g" $LogCleanerPath/LogCleanerMail.html	
			perl -p -i -e "s/TOTAL_COUNT/$totalLogFileCount/g" $LogCleanerPath/LogCleanerMail.html
			perl -p -i -e "s/TIMESTAMP/$(date +"%d.%m.%Y - %T")/g" $LogCleanerPath/LogCleanerMail.html

			perl -p -i -e "s#MOUNTDISK#$monitoringMountDisk#g" $LogCleanerPath/LogCleanerMail.html
			perl -p -i -e "s#LOG_FILES#${tbody}#g" $LogCleanerPath/LogCleanerMail.html

	       		printf "$TIMESTAMP [FINE] [$monitoringMountDisk disk usage is reduced] \n"
			printf "$TIMESTAMP [INFO] [Sending report mail to:$mailTOs for $monitoringMountDisk] \n"
              		
		      `(echo "Subject: LogCleaner Status Report - # $domain # $monitoringMountDisk disk status"
               		echo "Content-Type: text/html charset=iso-8859-9"
               		cat $LogCleanerPath/LogCleanerMail.html
                        ) | sendmail -t -f blabla-noreply@bla.com $mailTOs`
 
		else	
			printf "$TIMESTAMP [FINE] [No need to clean log files] \n"
        	fi
                count=$(( count+1 ))
        done

	printf "$TIMESTAMP [DONE] [!! LogCleaner executed successfully !!] \n"
	exit 0
else
	printf "$TIMESTAMP [ERROR] [LogClenaner executed: !! Properties file not found !!] \n"
	exit 1
fi
