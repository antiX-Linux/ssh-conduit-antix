#!/bin/bash


# ***** Library ********************************************************

# Access the suite library
source /usr/local/lib/ssh-conduit/lib-ssh-conduit-suite



# ***** Settings used solely by this script ****************************

# Capture the name of the script including file extension
PROGNAME=${0##*/}

# Set the version number
PROGVERSION=1.1



# ***** Functions used solely by this script ***************************

main()
{
   : 'Run the main trunk of the script'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Runs an admin centre task chosen by the user and reports the outcome'
   :
   : Example
   : ' function-name'
   :
   : Note
   : 'none'
   :
   : Requires
   : ' lib-ssh-conduit-suite yad'

   # ----- Present a menu of tasks and perform whichever is selected ---
   
   while [[ $ADMIN_TASK = "" ]]
   do
      # Select an admin task
      ADMIN_TASK=$(choose-admin-task)
      
      # Detect the admin task selected and run the corresponding task
      case $ADMIN_TASK in
         A:)   # Show status of ssh server was selected
               status-of-ssh-server
               ;;
         B:)   # Show ssh connections was selected
               ssh-connections
               ;;
         C:)   # Show recent authorized ssh sessions was selected
               recent-authorized-ssh-sessions
               ;;
         D:)   # Show sshfs mount connections was selected
               sshfs-mount-connections
               ;;
         E:)   # Show status of vnc server was selected
               status-of-vnc-server
               ;;
         F:)   # Change vnc password was selected
               change-vnc-password
               ;;
         G:)   # Toggle auto start of the vnc server at boot up was selected
               toggle-auto-start-of-vnc-server-at-boot-up
               ;;
         H:)   # Start vnc server for current log-in session only was selected
               ssh-conduit-x11vnc.sh server
               ;;
         I:)   # Stop all x11vnc servers was selected
               gksu --message "$LIB_MESSAGE_GKSU" "killall x11vnc"
               ;;
         *)    # Otherwise
               exit
               ;;
      esac
      
      # When there is an admin task message to show
      if [[ $MESSAGE_TO_SHOW != "" ]]; then
      
         # Title message to display
         MESSAGE="\n<b><big> Info</big></b> \n\n"
      
         # Display the task feedback message
         printf '%b' "$MESSAGE_TO_SHOW"                 \
         | yad --center                                 \
               --width=550                              \
               --height=350                             \
               --title="$LIB_WINDOW_TITLE"              \
               --borders="$LIB_BORDER_SIZE"             \
               --window-icon="$LIB_APP"                 \
               --image-on-top                           \
               --image="$LIB_INFO"                      \
               --text-align="$LIB_TEXT_ALIGNMENT"       \
               --text="$MESSAGE"                        \
               --buttons-layout="$LIB_BUTTONS_POSITION" \
               --button="$LIB_CANCEL"                   \
               --text-info                              \
               --margins=3 
      fi
      
      # Empty the message to show in preparation for the next loop
      MESSAGE_TO_SHOW=
   
      # Force the admin task menu to display again
      ADMIN_TASK=
   done

   
   
   # ---- Quit ---------------------------------------------------------
   
   exit
}



choose-admin-task()
{
   : 'Ask user to select which admin task to perform'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' returns the value of column 1 for the item selected in the list'
   :
   : Example
   : ' function-name'
   :
   : Note
   : 'none'
   :
   : Requires
   : ' lib-ssh-conduit-suite yad'
   
   local RETURN_VALUE
   
   # Question to display
   MESSAGE="\n<b><big> Which one?</big></b> \n\n"
   
   # Text to display in the menu for each column in the header row
   HEADER_COL1="Index"
   HEADER_COL2="Action"
   
   # Text to display in menu rows 1-n, columns 1,2
   ROW1_COL1=A
   ROW1_COL2="Show the status of the local SSH server"
   ROW2_COL1=B
   ROW2_COL2="Show inbound SSH connections to this system"
   ROW3_COL1=C
   ROW3_COL2="Show recent SSH sessions authorized by this system"
   ROW4_COL1=D
   ROW4_COL2="Show users with mount connections served from this system"
   ROW5_COL1=E
   ROW5_COL2="Show the status of the SSH-Conduit VNC server"
   ROW6_COL1=F
   ROW6_COL2="Change the password the VNC server requires to open a session"
   ROW7_COL1=G
   ROW7_COL2="Toggle auto start of the VNC server for next boot up"
   ROW8_COL1=H
   ROW8_COL2="Start the VNC server for the current log-in session only"
   ROW9_COL1=I
   ROW9_COL2="Stop all X11VNC servers"
   
   # Display the menu
   while [[ $ITEM_SELECTED = "" ]]
   do
      ITEM_SELECTED=$(yad --center                                 \
                          --width=650                              \
                          --height=450                             \
                          --title="$LIB_WINDOW_TITLE"              \
                          --borders="$LIB_BORDER_SIZE"             \
                          --window-icon="$LIB_APP"                 \
                          --image-on-top                           \
                          --image="$LIB_APP"                       \
                          --text-align="$LIB_TEXT_ALIGNMENT"       \
                          --text="$MESSAGE"                        \
                          --buttons-layout="$LIB_BUTTONS_POSITION" \
                          --button="$LIB_CANCEL"                   \
                          --button="$LIB_OK"                       \
                          --list                                   \
                          --no-rules-hint                          \
                          --separator=":"                          \
                          --column $HEADER_COL1                    \
                          --column $HEADER_COL2                    \
                          --print-column="1"                       \
                          --hide-column="1"                        \
                          "$ROW1_COL1" "$ROW1_COL2"                \
                          "$ROW2_COL1" "$ROW2_COL2"                \
                          "$ROW3_COL1" "$ROW3_COL2"                \
                          "$ROW4_COL1" "$ROW4_COL2"                \
                          "$ROW5_COL1" "$ROW5_COL2"                \
                          "$ROW6_COL1" "$ROW6_COL2"                \
                          "$ROW7_COL1" "$ROW7_COL2"                \
                          "$ROW8_COL1" "$ROW8_COL2"                \
                          "$ROW9_COL1" "$ROW9_COL2")
      
      # Continue or quit based on the outcome of the previous command
      lib_continue-or-quit $?
   done
      
   # Return the value of column 1 of the selected menu item
   RETURN_VALUE=$ITEM_SELECTED
   echo $RETURN_VALUE
   
   # Force the menu to display again
   ITEM_SELECTED=
}



status-of-ssh-server()
{
   : 'Report whether the local ssh server is running'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns the status of the openssh server daemon'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' awk ps'
   
   # Capture whether ssh daemon is running
   STATUS_SSH_DAEMON=$(ps aux | awk '/sshd/')
        
   # When ssh daemon is running
   [[ $STATUS_SSH_DAEMON != "" ]] \
   && MESSAGE_TO_SHOW="SSH server daemon is running"

   # When ssh daemon is not running
   [[ $STATUS_SSH_DAEMON = "" ]] \
   && MESSAGE_TO_SHOW="SSH server daemon is not running"
}



ssh-connections()
{
   : 'Report inbound ssh connections to this local system'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns remote and local ip addresses, user account name'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' awk gksu lib-ssh-conduit-suite netstat'
   
   # Capture a list of all active tcp connections to this system
   ACTIVE_TCP_CONNECTIONS=$(gksu --message "$LIB_MESSAGE_GKSU" \
                                 "netstat --tcp -4             \
                                          --numeric-hosts      \
                                          --program            \
                                          --wide")
              
   # When gksu authenticated the capture of active tcp connections
   if [[ $? = 0 ]]; then
               
      # Capture a list of the ssh connections established to this system
      MESSAGE_SSH_ESTABLISHED=$(echo "$ACTIVE_TCP_CONNECTIONS"     \
                                | awk '/ESTABLISHED.*sshd:/        \
                                      { print $4"   "$5"   "$8 }')
               
      # When an ssh connection is established to this system
      [[ $MESSAGE_SSH_ESTABLISHED != "" ]] \
      && MESSAGE_TO_SHOW="$MESSAGE_SSH_ESTABLISHED"
               
      # When an ssh connection is not established to this system
      [[ $MESSAGE_SSH_ESTABLISHED = "" ]] \
      && MESSAGE_TO_SHOW="No connection via SSH is established to this system"
   fi
}



recent-authorized-ssh-sessions()
{
   : 'Reports inbound ssh connections recently authorized by this system'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns date, time, user account name, each ssh session opened/closed'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' awk gksu lib-ssh-conduit-suite'
   
   # Create an empty array to hold the names of the auth log files
   RECENT_SSH_SESSIONS=()
               
   # Handle in turn uncompressed auth log files
   for AUTH_LOG in /var/log/auth.{log.1,log}
   do
      # When the log file is present add its name to the array
      [[ -f $AUTH_LOG ]] && RECENT_SSH_SESSIONS+=( $AUTH_LOG )
   done
               
   # Capture the ssh session details from the logs named in the array filtering out unwanted fields
   RECENT_SSH_SESSIONS=$(gksu --message "$LIB_MESSAGE_GKSU" \
                         awk '/sshd/ && /opened|closed/ && !/sudo/ { $4=$5=$6=$12=$13="" ; print $0 }' \
                             "${RECENT_SSH_SESSIONS[@]}")
               
   # When gksu authenticated the capture of ssh session details
   if [[ $? = 0 ]]; then
                  
      # When at least one ssh session has been authorized
      [[ $RECENT_SSH_SESSIONS != "" ]] \
      && MESSAGE_TO_SHOW="$RECENT_SSH_SESSIONS"
                  
      # When no ssh session authorization has been recorded in the log
      [[ $RECENT_SSH_SESSIONS = "" ]] \
      && MESSAGE_TO_SHOW="No SSH sessions have been authorized recently"
   fi
}



sshfs-mount-connections()
{
   : 'Reports users with mount connections served from this system'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns process id number and user account name'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' awk ps'
   
   # Capture info about sshfs connections to this system
   MESSAGE_SSHFS_ESTABLISHED_1=$(ps -eo pid,comm,user \
                                 | awk '/sftp/ { print $1"   "$3 }')

   # Create a rider message re sftp
   MESSAGE_SSHFS_ESTABLISHED_2="Note: SFTP connections also might be listed"
               
   # Concatenate the message for sshfs and rider for sftp
   MESSAGE_SSHFS_ESTABLISHED="$MESSAGE_SSHFS_ESTABLISHED_1      \
                               \n\n$MESSAGE_SSHFS_ESTABLISHED_2"
               
   # When an sshfs connection is established to this system
   [[ $MESSAGE_SSHFS_ESTABLISHED_1 != "" ]] \
   && MESSAGE_TO_SHOW="$MESSAGE_SSHFS_ESTABLISHED"

   # When an sshfs connection is not established to this system
   [[ $MESSAGE_SSHFS_ESTABLISHED_1 = "" ]] \
   && MESSAGE_TO_SHOW="No connection via SSHFS is established to this system"
}



status-of-vnc-server()
{
   : 'Report whether the local vnc server is running'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns the status of the local x11vnc server'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' awk ps'
   
   # Capture whether ssh-conduit vnc server is running
   STATUS_VNC_SERVER=$(ps aux | awk '/x11vnc.*ssh-conduit/' \
                              | awk '!/awk/')

   # When vnc server is running
   [[ $STATUS_VNC_SERVER != "" ]] \
   && MESSAGE_TO_SHOW="X11VNC server is running"

   # When vnc server daemon is not running
   [[ $STATUS_VNC_SERVER = "" ]] \
   && MESSAGE_TO_SHOW="X11VNC server is not running"
}



toggle-auto-start-of-vnc-server-at-boot-up()
{
   : 'Toggle vnc server to automatically start/not start at boot up'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Reverses the current state of automatically starting x11vnc'
   : ' Returns whether x11vnc will/will not start automatically at boot up'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' awk gksu ls update-rc.d'
   
   # Capture the auto start setting before perfoming a toggle
   VNC_SERVER_AUTOSTART_ANTE=$(ls -1lh /etc/rc5.d                \
                               | awk '/ssh-conduit-vnc-server/   \
                                     { print substr($9,0,1) }')

   # When start automatically during boot up is enabled toggle it to disabled
   [[ $VNC_SERVER_AUTOSTART_ANTE = S ]]  \
   && gksu --message "$LIB_MESSAGE_GKSU" \
           "update-rc.d ssh-conduit-vnc-server disable"

   # When start automatically during boot up is disabled toggle it to enabled
   [[ $VNC_SERVER_AUTOSTART_ANTE = K ]]  \
   && gksu --message "$LIB_MESSAGE_GKSU" \
           "update-rc.d ssh-conduit-vnc-server enable"

   # Capture the auto start setting after perfoming a toggle
   VNC_SERVER_AUTOSTART_POST=$(ls -1lh /etc/rc5.d                \
                               | awk '/ssh-conduit-vnc-server/   \
                                     { print substr($9,0,1) }')
               
   # When the auto start setting was changed to enable at boot up
   [[ $VNC_SERVER_AUTOSTART_POST = S ]] \
   && MESSAGE_TO_SHOW="The VNC server will start automatically at next boot up"
               
   # When the auto start setting was changed to disable at boot up
   [[ $VNC_SERVER_AUTOSTART_POST = K ]] \
   && MESSAGE_TO_SHOW="The VNC server will not start automatically at next boot up"
}



change-vnc-password()
{
   : 'Change the password required by x11vnc to grant a vnc session'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Displays help and info'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' ssh-conduit-x11vnc.sh'
   
   # Call the appropriate script
   ssh-conduit-x11vnc.sh password
}



usage()
{
   : 'Show a description of the script usage when started from CLI'
   :
   : Parameters
   : ' -h|--help'
   :
   : Result
   : ' Displays help and info'
   :
   : Example
   : ' ssh-conduit-admin-centre.sh --help'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' cat'

   # Display the following block
cat << end-of-messageblock

$PROGNAME version $PROGVERSION
Show menu of SSH-Conduit local admin tasks and report outcome of task.

Usage: 
   $PROGNAME [options]

Options:
   -h, --help         Show this output

Summary:
   Provides a means of monitoring and changing SSH-Conduit actions.
      
Configuration:
   None for $PROGNAME
   Each suite component provides its own configuration files
  
Environment:
   The script works in a GUI (X) environment. 

Requires:
   awk, bash, gksu, ls, netstat, ps, update-rc.d, yad, 
   ssh-conduit-x11vnc.sh
   lib-ssh-conduit-suite
   Each suite executable script and the library list their own requirements.

See also:
   ssh-conduit.sh

end-of-messageblock
   exit
}   



# ***** Start the script ***********************************************
case $1 in
   "")            # Begin the main trunk of the script
                  main
                  ;;
   --help|-h)     # Show info and help
                  usage
                  ;;
   *)             # Otherwise
                  exit 1        
                  ;;
esac
