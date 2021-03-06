#!/bin/bash

# Takes a list of missing machines from a URL (ideally auto-populated from your 
# inventory database) and sends an email if they've recently checked in to MunkiReport.
# Be sure to set the variables below. At minimum you must set the listurl and contacts.
# Script assumes the user running it has MySQL select rights via credentials in .my.cnf

# This URL should simply return a list of serial numbers, one per line.
listurl="https://example.com/missing.txt"
# Who should get this alert? If multiple people, separate with commas.
contacts="you@example.com"
# How far back should we look? This should probably match how often 
# you run this script. For example minutes="15" and crontab */15 * * * *
minutes="15"
# Name of MunkiReport database.
database="munkireport"

# Paths to programs we need. Defaults are from CentOS 7. Change as needed.
curl="/usr/bin/curl"
mysql="/bin/mysql"
printf="/bin/printf"
sendmail="/usr/sbin/sendmail"

####################################################################

missinglist=$($curl -s $listurl)

i=0
for singlemac in $missinglist
do
if [ $i -gt 0 ]; then
query+=" OR "
fi
query+="reportdata.serial_number='$singlemac' "
i=$((i+1))
done

query='select machine.computer_name as "Computer Name", '
query+='reportdata.serial_number as "Serial Number", '
query+='FROM_UNIXTIME(reportdata.timestamp) as "Date and Time Seen", '
query+='reportdata.remote_ip as "Reporting IP", '
query+='network.ethernet as "Wi-Fi MAC" from machine, '
query+='reportdata, network where ( '

i=0
for singlemac in $missinglist
do
if [ $i -gt 0 ]; then
query+=" OR "
fi
query+="reportdata.serial_number='$singlemac' "
i=$((i+1))
done

query+=' ) AND FROM_UNIXTIME(reportdata.timestamp) >= now() - INTERVAL '$minutes' MINUTE '
query+='AND machine.serial_number=reportdata.serial_number '
query+='AND machine.serial_number=network.serial_number '
query+='AND ( network.service="Wi-Fi" OR network.service="AirPort" );'
theresult=$($mysql --html $database -e "$query");

if [[ $theresult != "" ]]; then

template="Subject: Missing Mac(s) found in MunkiReport
To: $contacts
Content-Type: text/html
MIME-Version: 1.0

<p>These missing Macs checked in to MunkiReport in the last $minutes minutes. 
If they are no longer missing, please correct their status in inventory.</p>

$theresult
"

$printf "$template" | $sendmail -oi -t

fi