#!/bin/bash -x

#########################################
# Script to setup and run an SSH Tunnel #
# Written by Adam Olgin, 1/29/15 		#
# Last updated on 2/5 by Adam Olgin    #
#########################################

# This is a more complete version of tunnel_script.sh
# and will act similar to a gui-less SSH Tunnel Manager

ARG="$1" 		# whatever cmd line argument is passed with it. Anything past the first is ignored for now
SSHP="22"		# the port to SSH with (22 by default)
WRK_DTY="" 		# the uglier output that ssh will end up using
WRK_CLN="" 		# the cleaner output the user will see
POSTRUN="Your connection has ended. Thank you for using this script. Goodbye!"
WARNING="IMPORTANT: Upon logging in, it will appear like nothing has happened. DON'T WORRY! That just means you are connected. No output will show up upon connecting successfully."
DIR="${BASH_SOURCE[0]}" # the location of this script
DIR=${DIR%\/tunnel_mgr.sh} # just grab the path from it, not the actual filename
CONFIG_FILE="$DIR/conf/configurations.csv"	# The relative path to the configurations file
STOPPING="Press Ctrl+C or close this window to exit this session."

clear

# wipe the config file and exit
if [ "$ARG" == "-c" ]; then
	echo "Deleting your $CONFIG_FILE file..."
	rm $CONFIG_FILE
	exit
fi

# if the configurations file doesn't exist, create one
if [ ! -e $CONFIG_FILE ]; then
	if [ ! -d "conf" ]; then
		mkdir $DIR/conf
	fi
	echo "No $CONFIG_FILE found. Creating a new one..."
	touch $CONFIG_FILE
	echo "NAME,SERV,U_NAME,WRK_DTY,WRK_CLN" > $CONFIG_FILE
fi

# if no args are given
if [ -z $ARG ]; then
	# Prompt for each of the required fields
	# Errors will be thrown by the ssh program if they are given in the wrong format
	echo "Server to connect to?"
	read SERV
	echo "Bridge Username?"
	read U_NAME	# in order to prevent accidentally using the environment var USER

	# Set the params for the loop
	echo "Number of workstations on this tunnel?"
	read NUM_WRK
	CTR=1 	# for displaying the workstation number they are typing in
	
	# Let's loop!
	while [ $CTR -le $NUM_WRK ]
	do
		echo "Workstation $CTR IP?"
		read WRK
		echo "Forward from Local Port #? (Recommended: any unused port 5000+)"
		read LPORT
		echo "Forward to Remote Port #?"
		read RPORT
		WRK_DTY="$WRK_DTY -L $LPORT/$WRK/$RPORT"
		WRK_CLN="$WRK_CLN$LPORT:$WRK:$RPORT	"
		CTR=$[$CTR+1] 		# decrement the counter
		echo
	done

	echo "Would you like to save this configuration for future use? (y|n)"
	read ANS
	if [[ "$ANS" == "y" || "$ANS" == "Yes" || "$ANS" == "Y" || "$ANS" == "yes" ]]; then
		
		# make sure the name isn't already taken
		while true; do
			echo "Please name this configuration: "
			read NAME
			if [[ -z $(grep -F "$NAME" $CONFIG_FILE) ]]; then
				# exit the loop if the grep didn't find it
				break
			else
				# if the grep found, re-prompt
				clear 	# clear the terminal so this is more noticeable and looks better
				echo -e "There is an existing configuration with that name.\nPlease pick another.\n"
			fi
		done

		# write the config to a file named as specified
		echo "$NAME,$SERV,$U_NAME,$WRK_DTY,$WRK_CLN" >> $CONFIG_FILE

		echo -e "\nConfiguration '$NAME' has been added to the local $CONFIG_FILE file."
		echo "To run this script in the future using that configuration, execute 'bash tunnel_manager.sh $NAME'"
		echo -e "To delete a configuration, open up the $CONFIG_FILE and remove the line with your configuration.\n"
	else
		echo "Your configuration will not be saved."
	fi

	# Pre-run message
	clear
	echo "SSH connection to '$SERV' via port $SSHP with login: '$U_NAME'"
	echo -e "Tunneling to the following machine(s):\n$WRK_CLN\n\n$WARNING"
	echo "$STOPPING"

	# Run it
	ssh -N -p $SSHP -c 3des $U_NAME@$SERV $WRK_DTY # NOW CONNECTING
	echo -e "$POSTRUN\n"
	sleep 2

# asking for help/usage, then exit
elif [ "$ARG" == "-h" ]; then
	cat $DIR/usage
	echo
	exit

# list the configs in a formatted, easy to read manner
elif [ "$ARG" == "-l" ]; then       
	CTR=0 # for skipping over the field names and displaying total num. of configs
	while IFS=',' read NAME SERV U_NAME WRK_DTY WRK_CLN CMD
	do
		# offset the categories
		if [ $CTR -ne 0 ]; then
			echo "------------------------"
			echo "Configuration $CTR"
			echo "Name: $NAME"
			echo "Server: $SERV"
			echo "Login: $U_NAME"
			echo "Workstations: $WRK_CLN"
			echo -e "------------------------\n"
		fi
		CTR=$[$CTR+1]      
	done < $CONFIG_FILE
	echo -e "Total Configurations: $[$CTR-1]\n"	# CTR is one less because it is including the new line at eof
	unset IFS
	exit

# if the name is in the file, import the fields and use that config
elif [[ -n $(grep -F "$ARG" $CONFIG_FILE) ]]; then
	while IFS=',' read NAME SERV U_NAME WRK_DTY WRK_CLN        
	do
		# grab the required vars from the config file
		# Not the most efficient way, but it will work for now
		# configurations.csv should not be a very large file anyways
		if [ "$ARG" == "$NAME" ]; then
			NAME=$NAME
			SERV=$SERV
			U_NAME=$U_NAME
			WRK_DTY=$WRK_DTY
			WRK_CLN=$WRK_CLN
			break
		fi
	done < $CONFIG_FILE

	# Pre-run message
	clear
	echo "SSH connection to '$SERV' via port $SSHP with login: '$U_NAME'"
	echo -e "Tunneling to the following machine(s):\n $WRK_CLN\n\n$WARNING"
	echo "$STOPPING"

	# And let's connect
	ssh -N -p $SSHP -c 3des $U_NAME@$SERV $WRK_DTY
	echo "$POSTRUN"
	echo
	sleep 2
else 
	# no config was found, or something incorrect was entered,
	# error message and exit
	echo "Error: Not a recognized argument or configuration name."
	echo "Please try re-running this script with the -h flag for help."
	echo -e "usage: tunnel_manager.sh [name] [-h] [-l] [-c]\n"
	exit
fi
