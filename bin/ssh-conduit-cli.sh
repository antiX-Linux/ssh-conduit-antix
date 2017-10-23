#!/bin/bash



# ***** Library ********************************************************

# Access the suite library
source /usr/local/lib/ssh-conduit/lib-ssh-conduit-suite



# ***** Settings used solely by this script ****************************

# Capture the name of the script including file extension
PROGNAME=${0##*/}

# Set the version number
PROGVERSION=1.1

# Location of the cli profiles directory
PROFILE_DIR=${HOME}/.config/ssh-conduit/cli/profiles

# Name of the cli profile template file
PROFILE_TEMPLATE_FILE=ssh-conduit_template_profile.cli

# Location of the cli user configurable settings directory
CONFIG_DIR=${HOME}/.config/ssh-conduit/cli

# Name of the cli user configurable settings file
CONFIG_FILE=cli.conf

# Temporary file to hold transient output
TEMP_FILE_1=$(mktemp -q)



# ***** Remove anything that might be left over upon exit **************

trap clean-up EXIT



# ***** Functions used solely by this script ***************************

main()
{
   : 'Run the main trunk of the script'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Connects ssh using a profile or ad hoc mode'
   : ' Disconnects an established ssh connection'
   :
   : Example
   : ' function-name'
   :
   : Note
   : 'none'
   :
   : Requires
   : ' lib-ssh-conduit-suite'

   # ----- User configurable settings ----------------------------------
   
   # Ensure user editable files exist in the user home file structure
   lib_provide-file-from-skel $PROFILE_DIR $PROFILE_TEMPLATE_FILE
   lib_provide-file-from-skel $CONFIG_DIR $CONFIG_FILE
   
   # Rename the profile template file
   lib_remove_underscores_from_file_name $PROFILE_DIR $PROFILE_TEMPLATE_FILE
   
   # Obtain the config values
   lib_source-file-or-issue-error-message $CONFIG_DIR $CONFIG_FILE
   
   # Prevent the timeout countdown period being set to an empty value
   COUNTDOWN=$(lib_fallback-timeout $COUNTDOWN)
   
   # Prevent the feedback time period being set to an empty value
   FEEDBACK_TIME=$(fallback-feedback-time $FEEDBACK_TIME)
      
      
   # ----- Automatic mode (preferred profile) --------------------------
   
   # When a preferred profile is specified
   if [[ $PREFERRED_PROFILE != "" ]]; then
   
      # Offer a chance to opt out of automatically using a preferred profile
      lib_opportunity-to-decline-preferred-profile 
      
      case $? in
         0)  # Preferred was selected
             # Ensure the preferred profile is used by retaining its current value unchanged
             # Ensure the disconnect window will not be shown
             CLI_STOP=FALSE
             ;;
         1)  # Cancel was selected
             # Quit taking no further action
             exit 1
             ;;
         2)  # Disconnect was selected
             # Ensure the disconnect window will be shown
             CLI_STOP=TRUE
             ;;
         3)  # Ad hoc was selected
             # Ensure the preferred profile is not used
             PREFERRED_PROFILE=
             ;;
         70) # Preferred was selected via timeout
             # Ensure the preferred profile is used by retaining its current value unchanged
             # Ensure the disconnect window will not be shown
             CLI_STOP=FALSE
             ;;
         *)  # Otherwise
             exit 1        
             ;;
      esac
   fi
   
   
   # When a preferred profile is to be used
   if [[ $PREFERRED_PROFILE != "" ]]; then
   
      # Assign the preferred profile file name as the one to use
      PROFILE_FILE="$PREFERRED_PROFILE"
      
      # Obtain the profile values
      lib_source-file-or-issue-error-message $PROFILE_DIR "$PROFILE_FILE"
   fi
   
   
   
   # ----- Manual mode (ad hoc) ----------------------------------------
   
   # When a preferred profile is not to be used
   if [[ $PREFERRED_PROFILE = "" ]]; then
   
      # Ensure guidance is available to the user
      create-help-file
   
      # Provide a way for the user to input their choices
      manual-control
   fi
   
   
   # ----- Connect to the remote network and open an ssh session -------
   
   # When start a cli connection is requested
   if [[ $CLI_STOP = FALSE ]]; then
   
      # Assemble the individual components into a command to start an ssh connection
      construct-the-start-ssh-command
      
      # Open an ssh session
      start-ssh-connection
   fi
   
   
   # ----- Disconnect from the remote network and close a cli session --
   
   # When stop a cli session is requested
   if [[ $CLI_STOP = TRUE ]]; then
   
      # Close the cli connection
      stop-ssh-connection
   fi
      
   
   # ---- Quit ---------------------------------------------------------
   
   exit
}



manual-control()
{
   : 'Ask user to choose one of the following ad hoc tasks:'
   : '  manually input connection details'
   : '  select an existing profile'
   : '  select disconnect an established ssh session'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Sets $IP_ADDRESS $PORT_NUMBER $ACCOUNT_NAME $PARAMETERS $REMOTE_COMMAND'
   : ' for later use to control connecting a cli session with manually input values'
   : ' Sets $PROFILE_FILE'
   : ' for later use to control connecting a cli session with a manually selected profile'
   : ' Sets $CLI_STOP'
   : ' for later use to control disconnecting a cli session'
   : ' Sets $SELECT_PROFILE'
   : ' to enable/disable (grey-out) browsing for a profile in this yad window'
   : ' Sets $SELECT_DISCONNECT'
   : ' to enable/disable (grey-out) closing a cli session window'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' lib-ssh-conduit-suite yad'

   # Re-show the following yad window if any of the variables:
   # ip address, account name
   # are empty or indicating a user entered value is mandatory
   while [[ $IP_ADDRESS = "" ]]   || [[ $IP_ADDRESS = "$FIELD_INFO_1" ]]  || \
         [[ $ACCOUNT_NAME = "" ]] || [[ $ACCOUNT_NAME = "$FIELD_INFO_1" ]]
   do
      # Decide whether the capability to manually select a profile is greyed-out
      SELECT_PROFILE=$(lib_enable-or-disable-browsing-to-select-a-profile-manually)

      # Decide whether the capability to disconnect a cli session is greyed-out
      SELECT_DISCONNECT=$(lib_set-checkbox-state-by-command-string-order "$PREFERRED_TERMINAL.*\-T.*SSH-Conduit.*\-e.*sh.*\-c.*ssh")
      
      
      # Message to display at the top of the ad hoc action window
      MESSAGE_1="\n<b><big> Make or break a CLI connection</big></b>\n"
         
      
      # Guidance that a value for a field is mandatory in the ad hoc action window
      FIELD_INFO_1="Required for method-1"
      
      # Field 01 assignments
      LABEL_01="<b>\nMethod-1</b>"
      TYPE_01="LBL"
      VALUE_01=""
      
      # Field 02 assignments
      LABEL_02="IP Address"
      TYPE_02=""
      VALUE_02="$FIELD_INFO_1"
      
      # Field 03 assignments
      LABEL_03="Port Number"
      TYPE_03=""
      VALUE_03=""
      
      # Field 04 assignments
      LABEL_04="Account Name"
      TYPE_04=""
      VALUE_04="$FIELD_INFO_1"
      
      # Field 05 assignments
      LABEL_05="Parameters"
      TYPE_05=""
      VALUE_05=""
      
      # Field 06 assignments
      LABEL_06="Remote Command"
      TYPE_06=""
      VALUE_06=""
      
      # Field 07 assignments
      LABEL_07="\n<b>Method-2</b>"
      TYPE_07="LBL"
      VALUE_07=""
      
      # Field 08 assignments
      LABEL_08="Select an existing profile"
      TYPE_08="FL"
      VALUE_08="$SELECT_PROFILE"
      
      # Field 09 assignments
      LABEL_09="\n<b>Disconnect</b>"
      TYPE_09="LBL"
      VALUE_09=""
      
      # Field 10 assignments
      LABEL_10="Select a CLI connection"
      TYPE_10="CHK"
      VALUE_10="$SELECT_DISCONNECT"
      
      # Field 11 assignments
      LABEL_11=""
      TYPE_11="LBL"
      VALUE_11=""
            
      # Message to display at the top of the help cli window
      MESSAGE_2="\n<b><big> Help CLI</big></b>\n"


      # Display the form to enable the user to specify what to connect
      AD_HOC_ACTION=$(yad --center                                                           \
                          --width=520                                                        \
                          --height=420                                                       \
                          --title="$LIB_WINDOW_TITLE"                                        \
                          --borders="$LIB_BORDER_SIZE"                                       \
                          --window-icon="$LIB_APP"                                           \
                          --image-on-top                                                     \
                          --image="$LIB_APP"                                                 \
                          --text-align="$LIB_TEXT_ALIGNMENT"                                 \
                          --text="$MESSAGE_1"                                                \
                          --buttons-layout="$LIB_BUTTONS_POSITION"                           \
                          --button="$LIB_OK"                                                 \
                          --button="$LIB_CANCEL"                                             \
                          --button="$LIB_HELP":"yad --width=850                              \
                                                    --height=700                             \
                                                    --title="$LIB_WINDOW_TITLE"              \
                                                    --borders="$LIB_BORDER_SIZE"             \
                                                    --image="$LIB_INFO"                      \
                                                    --image-on-top                           \
                                                    --text='$MESSAGE_2'                      \
                                                    --buttons-layout="$LIB_BUTTONS_POSITION" \
                                                    --button="$LIB_CLOSE_1"                  \
                                                    --skip-taskbar                           \
                                                    --text-info                              \
                                                    --filename=$HELP_CLI_FILE"               \
                          --form                                                             \
                          --field="$LABEL_01":"$TYPE_01" "$VALUE_01"                         \
                          --field="$LABEL_02":"$TYPE_02" "$VALUE_02"                         \
                          --field="$LABEL_03":"$TYPE_03" "$VALUE_03"                         \
                          --field="$LABEL_04":"$TYPE_04" "$VALUE_04"                         \
                          --field="$LABEL_05":"$TYPE_05" "$VALUE_05"                         \
                          --field="$LABEL_06":"$TYPE_06" "$VALUE_06"                         \
                          --field="$LABEL_07":"$TYPE_07" "$VALUE_07"                         \
                          --field="$LABEL_08":"$TYPE_08" "$VALUE_08"                         \
                          --field="$LABEL_09":"$TYPE_09" "$VALUE_09"                         \
                          --field="$LABEL_10":"$TYPE_10" "$VALUE_10"                         \
                          --field="$LABEL_11":"$TYPE_11" "$VALUE_11")

      # Continue or quit based on how the preceding yad window was closed
      lib_continue-or-quit $?
      

      # Assign the value(s) entered by the user
      # Note: when method-1 is used most of these values are employed
      IP_ADDRESS=$(lib_get-value-of-field "2" "|" "$AD_HOC_ACTION")
      PORT_NUMBER=$(lib_get-value-of-field "3" "|" "$AD_HOC_ACTION")
      ACCOUNT_NAME=$(lib_get-value-of-field "4" "|" "$AD_HOC_ACTION")
      PARAMETERS=$(lib_get-value-of-field "5" "|" "$AD_HOC_ACTION")
      REMOTE_COMMAND=$(lib_get-value-of-field "6" "|" "$AD_HOC_ACTION")
      SELECTED_PROFILE=$(lib_get-value-of-field "8" "|" "$AD_HOC_ACTION")
      CLI_STOP=$(lib_get-value-of-field "10" "|" "$AD_HOC_ACTION")
      
      
      # When the user selected a profile ensure it is used
      # Note: $selected_profile will always have one of the following values
      #       $profile_dir/* or @disabled@ or the actual name of the profile file
      #       so the test is for the presence of a regular file exclusively
      [[ -f "$SELECTED_PROFILE" ]] && USE_MANUALLY_SELECTED_PROFILE=TRUE
            
      # When a manually selected profile is to be used
      if [[ $USE_MANUALLY_SELECTED_PROFILE = TRUE ]]; then
        
         # Capture the file name of the profile from its full path
         PROFILE_FILE=$(lib_get-value-of-last-field "/" "$SELECTED_PROFILE")
         
         # Capture the values from the profile file
         lib_source-file-or-issue-error-message $PROFILE_DIR "$PROFILE_FILE"
      fi
      
      # When the user selected disconnect cease re-showing the yad window
      [[ $CLI_STOP = TRUE ]] && break 1
   done
}



create-help-file() 
{
   : 'Provide optional help to user when employing manual-control (ad-hoc)'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Writes help text to a temporary file'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' cat mktemp'

   # When the temporay help file is not present
   if [[ ! -e $HELP_CLI_FILE ]]; then
     
      # Create a temporary file to hold the help text
      HELP_CLI_FILE=$(mktemp -q)
     
      # Write the help cli text to its temporary file
cat <<-end-of-messageblock > $HELP_CLI_FILE

  TO START A CLI CONNECTION
  
  Use either
  Method-1   Manually input the details
  Method-2   Browse for and select an existing profile
  
  
  METHOD-1
  
  IP Address
  When connecting within a LAN specify the LAN IP address of the remote system
  When connecting across the internet specify the public IP address of the remote firewall
    
  Port Number
  Port number forwarded by the remote firewall to the remote system
  This is usually not needed when both systems are in the same LAN
  
  Account Name
  The user name of an existing account on the remote SSH server system
  This will be used to log in to it
  
  Parameters
  These are optional and adjust the way the SSH encrpyted tunnel behaves
  Example
     -C -t -o ServerAliveInterval=15 -o ServerAliveCountMax=3 
  
  Remote Command
  This is optional and runs on the remote system after a connection has been authorized
  Example
     tmux new-session -A -s alpha 'mc\ \-x'
  
  
  METHOD-2
  
  Select an existing profile
  Browse to choose an existing, fully defined profile
  This is available only when an ssh-conduit CLI profile presently exists
  
  
  TO STOP A CLI CONNECTION
  
  Closing a CLI connection should be performed in its terminal window 
  Selecting "Disconnect a CLI" will only display advice on how to close the connection

end-of-messageblock
   fi
}



fallback-feedback-time()
{
   : 'Provides a fallback value in case the user misconfiged feedback-time value'
   :
   : Parameters
   : ' arg1   $FEEDBACK_TIME   i.e. the var holding the current feedback-time value'
   :
   : Result
   : ' returns the fallback value when the feedback-time period is set to an empty value'
   : ' otherwise returns the user preferred value when it is set to a non empty value'
   :
   : Example
   : ' FEEDBACK_TIME=$(fallback-feedback-time $FEEDBACK_TIME)'
   :
   : Note
   : ' FEEDBACK_TIME period should be stipulated in the app conf file'
   : ' $FEEDBACK_TIME should be set in the calling script'
   :
   : Requires
   : ' none'
   
   local RETURN_VALUE
   
   case $1 in
      "")   # Set a fallback period
            RETURN_VALUE=3
            ;;
      *)    # Retain the value unchanged
            RETURN_VALUE=$FEEDBACK_TIME
            ;;
   esac

   echo "$RETURN_VALUE"
}



construct-the-start-ssh-command() 
{
   : 'Handle unassigned values used in the start command'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Sets the text to be shown in the terminal window title bar'
   : ' Sets the remote port number to connect to when required'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' none'

      
   # When a port number is specified prepend the port flag to the value
   [[ $PORT_NUMBER != "" ]] && PORT_NUMBER="-p ${PORT_NUMBER}"

   # Text to show in the title bar of the terminal
   TERMINAL_TITLE_BAR="$LIB_WINDOW_TITLE  ${ACCOUNT_NAME}@${IP_ADDRESS}"
}



start-ssh-connection()
{
   : 'Starts an ssh session with the remote server'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Opens a terminal which displays the outcome of the connection attempt'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' terminal|x-terminal-emulator sh sleep'

   # Start ssh session and report the outcome in the terminal window
   $PREFERRED_TERMINAL -T "$TERMINAL_TITLE_BAR"                    \
                       -e sh -c "ssh $PORT_NUMBER                  \
                                     $PARAMETERS                   \
                                     ${ACCOUNT_NAME}@${IP_ADDRESS} \
                                     $REMOTE_COMMAND               \
                                ; sleep $FEEDBACK_TIME"            &
}



stop-ssh-connection()
{
   : 'Advise the user to close the connection via its terminal'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Displays an information window then exits '
   :
   : Example
   : ' function_name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' yad'
       
   # Advice message to display
   MESSAGE="\n Closing a CLI connection should be \
            \n performed in its terminal window  \
            \n \
            \n"

   # Display the advice message
   yad --center                                   \
       --width=0                                  \
       --height=0                                 \
       --title="$LIB_WINDOW_TITLE"                \
       --borders="$LIB_BORDER_SIZE"               \
       --image-on-top                             \
       --image="$LIB_INFO"                        \
       --text-align="$LIB_TEXT_ALIGNMENT"         \
       --text="$MESSAGE"                          \
       --buttons-layout="$LIB_BUTTONS_POSITION"   \
       --button="$LIB_CLOSE"

   exit 1
}



clean-up() 
{
   : 'Remove anything that might be left over upon exit'
   :
   : Parameters
   : ' EXIT'
   :
   : Result
   : ' Temporary files removed'
   :
   : Example
   : ' trap clean_up EXIT'
   :
   : Note
   : ' add to the list anything that might be left over when exiting'
   : Requires
   : ' rm'

   # Remove temporary files
   rm -rf $TEMP_FILE_1
   rm -rf $HELP_CLI_FILE
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
   : ' ssh-conduit-sshuttle.sh --help'
   :
   : Note
   : ' none'
   : Requires
   : ' cat'

   # Display the following block
cat << end-of-messageblock

$PROGNAME version $PROGVERSION
Creates an SSH encrypted connection between two systems and provides a
command line interface to the remote system.

Usage: 
   $PROGNAME [options]

Options:
   -h, --help   Show this output

Summary:
   Before access to the remote system is granted, an encrypted tunnel is
   automatically created between it and the local system.  The tunnel is
   then used to log-in the local system user to the remote system. After
   a successful log-in, the local user can run commands on the remote
   system. The session is secured by passing all traffic within the
   encrypted SSH tunnel.
   
   Creating the tunnel and accessing the reomte system are controlled by 
   the local system user. An operator is not required at the remote
   system location.
   
   Optionally, one or more profiles may be created.  Each profile points
   to a different remote system.  In this way a range of remote systems
   can be defined and easily connected as desired.
   
   During launch, any or none of the profiles may be chosen before a 
   connection is made.  Any one of the profiles can optionally be
   designated as the preferred profile.  In that case it is automatically
   loaded and connected at launch time.  An ad hoc mode is also available
   during launch to enable an on-the-fly connection to a remote system.
   
   For convenience a template profile is provided that may be copied and
   edited as required.
   
   For cases where a different terminal emulator is wanted to the one 
   used via x-terminal-emulator, a preferred choice may be specified.
   
Configuration:
   Profiles
   /home/USERNAME/.config/ssh-conduit/cli/profiles/your-filename.cli
   
   User specified configuration
   /home/USERNAME/.config/ssh-conduit/cli/cli.conf
  
Environment:
   The script works in a GUI (X) environment.

Requires:
   Requires:
   bash, cat, mktemp, openssh-client, rm, sh, sleep
   terminal|x-terminal-emulator, yad
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
