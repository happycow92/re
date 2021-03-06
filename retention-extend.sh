#!/bin/bash
# This Script performs a display of retention for required clients backed up by VDP
# This Script also performs an edit of the retention period for the client
# The retention can only be increased and cannot be decreased
# This is updated version, v1.5.0, of the retention script
# For Bugs reach out to gsuhas@vmware.com

clear

# Title Display

echo -e "***************************************************************\n"
echo -e "           This Script Is Written By Suhas G Savkoor           \n"
echo -e "		        gsuhas@vmware.com			\n"
echo -e "***************************************************************\n"


printf "The clients Protected by VDP are\n"
echo --------------------------------

# Defining Variables
vCenterName=$(cat /usr/local/vdr/etc/vcenterinfo.cfg | grep vcenter-hostname | cut -d '=' -f 2)

# Listing clients
clients=$(mccli client show --recursive=true | grep /$vCenterName/VirtualMachines | sed -r 's/([ \t]+[^ \t]*){4}$//')
echo "$clients"

echo # New Line

# Downloading Proxycp.jar
printf "Downloading proxycp.jar\n"
File="proxycp.jar"
if [ -f $File ]
then
    printf "Proxycp.jar is present. Not downloading again\n"
else
    wget https://www.dropbox.com/s/4l3qfif0wmcijeo/proxycp.jar?dl=0 -O /root/proxycp.jar -q
    printf "\nDownload done\n"
fi

echo # New Line

# Function to convert dates

function dateConvert
{
	after=$(date -d "$backupDate -1 day" | awk '{print $6"-"$2"-"$3}')
	before=$(date -d "$backupDate +1 day" | awk '{print $6"-"$2"-"$3}')
	name=$(date -d "$backupDate +1 day" | awk '{print $2}')
	arr="JAN F Mar Apr May Jun Jul Aug Sep Oct Nov Dec"

    for X in $arr
    do
        if [ "$X" != "$name" ]
        then
            monthValue=`expr $monthValue + 1`
        else
            monthValue=`expr $monthValue + 1`
            break
        fi
    done

	afterYY=$(sed 's/'"$name"'/'"$monthValue"'/g' <<< $after)
	beforeYY=$(sed 's/'"$name"'/'"$monthValue"'/g' <<< $before)
}

echo -e "\nClient names are case sensitive\n"

# Case Statement to Display and/or Modify retention
# Loop Until False. 

value="Y"
while [ "$value" != "N" ]
do
	printf "1. Display Retention for clients\n"
	printf "2. Modify Retention for clients\n"
	echo --------------------------------
	read -p "Choose your option : " choice
	echo # New Line

case $choice in
    1)	# Choice for display retention
    read -p "Enter your client name: " cName		
	trueClient=$(echo $clients | grep -o $cName)
		
	if [ "$trueClient" == "$cName" ]
	then
		read -p "After which date would you like to list the backups (YY-MM-DD): " afterDate
		read -p "And before Which Date would you like to list the backups (YY-MM-DD): " beforeDate
		java -jar proxycp.jar --listbackups --client /$vCenterName/VirtualMachines/$cName --after "$afterDate" --before "$beforeDate" &> /root/proxycp-output.txt
		awk '/Operation/{y=1;next}y' proxycp-output.txt |grep / | awk '{print $2 "\t""\t"$3 "\t" $5}' > temp.txt
		if [ -s "temp.txt" ]
		then
			printf "\nRetention for $cName between $afterDate and $beforeDate is\n"
			echo -e "Label Num \tBackup Date \tExpiry Date"; echo -------------------------------------------;cat temp.txt
			printf "\n\n"

			read -p "Do you want to run this again? Y/N: " value
			echo # New Line
		else
			printf "\nNo Backups available for $cName in the specified time stamp between $afterDate to $beforeDate\n\n"
			read -p "Do you want to run this again? Y/N: " value
			echo # New Line
		fi
	else
		printf "\nClient $cName does not exist\n"
		read -p "Do you want to run this again? Y/N: " value
		echo # New Line
	fi
    ;;
    2)	# Choice for editing/extending retention
    read -p "Which Client You Want To Edit?: " cName
	trueClient=$(echo $clients | grep -o $cName)
	if [ "$trueClient" == "$cName" ]
	then
		read -p "Enter the Label Number To extend retention for: " labelNum
		varLoop=$(cat temp.txt  | awk '{print $1}' | tr '\n' ' ')
		trueLabel=$(echo $varLoop | grep -o $labelNum)
		if [ "$trueLabel" == "$labelNum" ] 
		then
			backupDate=$(awk -v lbl=$labelNum '$1 == lbl{ print $2 }' temp.txt)

			read -p "Enter the new expiry date in YYYY-MM-DD: " expiry
			dateConvert
			echo # New Line
			printf "Modifying Retention for client $cName for backup # $labelNum\n"
			java -jar proxycp.jar --modifybackups  --setexpirydate "$expiry" --client /$vCenterName/VirtualMachines/$cName --after "$afterYY" --before "$beforeYY" &> /root/proxycp-output-modify.txt

			printf "Updated Retention for $cName with Backup Label # $labelNum is\n\n"
			awk '/Operation/{y=1;next}y' proxycp-output-modify.txt | grep / | awk '{print $2 "\t""\t"$3 "\t" $8}' > temp_2.txt
			echo -e "Label Num \tBackup Date \tExpiry Date"; echo -------------------------------------------;cat temp_2.txt
	
			printf "\n\n"
			read -p "Do you want to run this again? Y/N: " value
		else
			printf "\nThe label number $labelNum does not exist\n"
			read -p "Do you want to run this again? Y/N: " value
		fi
	else
		printf "\nClient $cName does not exist\n"
		read -p "Do you want to run this again? Y/N: " value
		echo # New Line
	fi			
	;;
    ?)
    printf "\nIncorrect Choice "
	read -p "Try again? Y/N: " value
	echo # New Line
    ;;
esac
done

rm proxycp-output.txt &> /dev/null
rm proxycp-output-modify.txt &> /dev/null
rm temp.txt &> /dev/null
rm temp_2.txt &> /dev/null

