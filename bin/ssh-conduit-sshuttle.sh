#!/bin/bash



# ***** Library ********************************************************

# Access the suite library
source /usr/local/lib/ssh-conduit/lib-ssh-conduit-suite



# ***** Settings used solely by this script ****************************

# Capture the name of the script including file extension
PROGNAME=${0##*/}

# Set the version number
PROGVERSION=1.1

# Location of the sshuttle profiles directory
PROFILE_DIR=${HOME}/.config/ssh-conduit/sshuttle/profiles

# Name of the sshuttle profile template file
PROFILE_TEMPLATE_FILE=ssh-conduit_template_profile.sshuttle

# Location of the sshuttle user configurable settings directory
CONFIG_DIR=${HOME}/.config/ssh-conduit/sshuttle

# Name of the sshuttle user configurable settings file
CONFIG_FILE=sshuttle.conf

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
   : ' Connects a vpn using a profile or ad hoc mode'
   : ' Disconnects an established vpn connection'
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
   lib_provide-file-from-skel $PROFILE_DIR "$PROFILE_TEMPLATE_FILE"
   lib_provide-file-from-skel $CONFIG_DIR "$CONFIG_FILE"
   
   # Rename the profile template file
   lib_remove_underscores_from_file_name $PROFILE_DIR $PROFILE_TEMPLATE_FILE
   
   # Obtain the config values
   lib_source-file-or-issue-error-message $CONFIG_DIR "$CONFIG_FILE"
   
   # Indicate the config values have been obtained
   # Note this is used whenever the script is started from the taskbar icon
   CONFIG_FILE_VALUES_SOURCED=TRUE
   
   # Prevent the timeout countdown period being set to an empty value
   COUNTDOWN=$(lib_fallback-timeout $COUNTDOWN)
   
      
   # ----- Automatic mode (preferred profile) --------------------------
   
   # When a preferred profile is specified
   if [[ $PREFERRED_PROFILE != "" ]]; then
   
      # Offer a chance to opt out of automatically using a preferred profile
      lib_opportunity-to-decline-preferred-profile 
      
      case $? in
         0)  # Preferred was selected
             # Ensure the preferred profile is used by retaining its current value unchanged
             # Ensure the disconnect window will not be shown
             VPN_STOP=FALSE
             ;;
         1)  # Cancel was selected
             # Quit taking no further action
             exit 1
             ;;
         2)  # Disconnect was selected
             # Ensure the disconnect window will be shown
             VPN_STOP=TRUE
             ;;
         3)  # Ad hoc was selected
             # Ensure the preferred profile is not used
             PREFERRED_PROFILE=
             ;;
         70) # Preferred was selected via timeout
             # Ensure the preferred profile is used by retaining its current value unchanged
             # Ensure the disconnect window will not be shown
             VPN_STOP=FALSE
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
   
   
   # ----- Connect to the remote network and open a vpn session --------
   
   # When start a vpn connection is requested
   if [[ $VPN_STOP = FALSE ]]; then
   
      # Assemble the individual components into a command to start a vpn connection
      construct-the-start-vpn-command
      
      # Open a vpn session
      start-vpn-connection
   fi
   
   
   # ----- Show icon in taskbar tray -----------------------------------
   
   # When the user specified display an icon while a vpn is established
   if [[ $TRAY_ICON = true ]] && [[ $VPN_ESTABLISHED = TRUE ]]; then
   
      # Add an icon to the taskbar tray
      show-tray-icon
   fi
   
   
   # ----- Disconnect from the remote network and close a vpn session --
   
   # When stop a vpn session is requested
   if [[ $VPN_STOP = TRUE ]]; then
   
      # Close the vpn connection
      stop-vpn-connection
      
      # Remove the icon from the taskbar tray
      remove-tray-icon
   fi
   
   
   # ---- Quit ---------------------------------------------------------
   
   exit
}



manual-control()
{
   : 'Ask user to choose one of the following ad hoc tasks:'
   : '  manually input connection details'
   : '  select an existing profile'
   : '  select disconnect an established vpn'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Sets $IP_ADDRESS $PORT_NUMBER $ACCOUNT_NAME $VPN_MODE $SUBNET_RANGE $PARAMETERS'
   : ' for later use to control connecting a vpn with manually input values'
   : ' Sets $PROFILE_FILE'
   : ' for later use to control connecting a vpn with a manually selected profile'
   : ' Sets $VPN_STOP'
   : ' for later use to control disconnecting a vpn'
   : ' Sets $SELECT_PROFILE'
   : ' to enable/disable (grey-out) browsing for a profile in this yad window'
   : ' Sets $SELECT_DISCONNECT'
   : ' to enable/disable (grey-out) closing a vpn in this yad window'
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
   # ip address, port number, account name
   # are empty or indicating a user entered value is mandatory
   while [[ $IP_ADDRESS = "" ]]   || [[ $IP_ADDRESS = "$FIELD_INFO_1" ]]  || \
         [[ $PORT_NUMBER = "" ]]  || [[ $PORT_NUMBER = "$FIELD_INFO_1" ]] || \
         [[ $ACCOUNT_NAME = "" ]] || [[ $ACCOUNT_NAME = "$FIELD_INFO_1" ]]
   do
      # Decide whether the capability to manually select a profile is greyed-out
      SELECT_PROFILE=$(lib_enable-or-disable-browsing-to-select-a-profile-manually)

      # Decide whether the capability to disconnect a vpn is greyed-out
      SELECT_DISCONNECT=$(lib_set-checkbox-state-by-command-string-order 'sshuttle.*ssh-conduit-vpn')
      
      
      # Message to display at the top of the ad hoc action window
      MESSAGE_1="\n<b><big> Make or break a VPN connection</big></b>\n"
         
      
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
      VALUE_03="$FIELD_INFO_1"
      
      # Field 04 assignments
      LABEL_04="Account Name"
      TYPE_04=""
      VALUE_04="$FIELD_INFO_1"
      
      # Field 05 assignments
      LABEL_05="VPN Mode"
      TYPE_05="CB"
      VALUE_05="^system-to-site!site-to-site!manual"
      
      # Field 06 assignments
      LABEL_06="Subnet Range"
      TYPE_06=""
      VALUE_06=""
      
      # Field 07 assignments
      LABEL_07="Parameters"
      TYPE_07=""
      VALUE_07=""
      
      # Field 08 assignments
      LABEL_08="\n<b>Method-2</b>"
      TYPE_08="LBL"
      VALUE_08=""
      
      # Field 09 assignments
      LABEL_09="Select an existing profile"
      TYPE_09="FL"
      VALUE_09="$SELECT_PROFILE"
      
      # Field 10 assignments
      LABEL_10="\n<b>Disconnect</b>"
      TYPE_10="LBL"
      VALUE_10=""
      
      # Field 11 assignments
      LABEL_11="Select a VPN connection"
      TYPE_11="CHK"
      VALUE_11="$SELECT_DISCONNECT"
      
      # Field 12 assignments
      LABEL_12=""
      TYPE_12="LBL"
      VALUE_12=""
            
      # Message to display at the top of the help vpn window
      MESSAGE_2="\n<b><big> Help VPN</big></b>\n"


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
                                                    --filename=$HELP_VPN_FILE"               \
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
                          --field="$LABEL_11":"$TYPE_11" "$VALUE_11"                         \
                          --field="$LABEL_12":"$TYPE_12" "$VALUE_12")

      # Continue or quit based on how the preceding yad window was closed
      lib_continue-or-quit $?
      

      # Assign the value(s) entered by the user
      # Note: when method-1 is used most of these values are employed
      IP_ADDRESS=$(lib_get-value-of-field "2" "|" "$AD_HOC_ACTION")
      PORT_NUMBER=$(lib_get-value-of-field "3" "|" "$AD_HOC_ACTION")
      ACCOUNT_NAME=$(lib_get-value-of-field "4" "|" "$AD_HOC_ACTION")
      VPN_MODE=$(lib_get-value-of-field "5" "|" "$AD_HOC_ACTION")
      SUBNET_RANGE=$(lib_get-value-of-field "6" "|" "$AD_HOC_ACTION")
      PARAMETERS=$(lib_get-value-of-field "7" "|" "$AD_HOC_ACTION")
      SELECTED_PROFILE=$(lib_get-value-of-field "9" "|" "$AD_HOC_ACTION")
      VPN_STOP=$(lib_get-value-of-field "11" "|" "$AD_HOC_ACTION")
      
      # When the user opted to manually specify the vpn connection and omitted a subnet range
      if [[ $VPN_MODE = manual ]] && [[ $SUBNET_RANGE = "" ]]; then
      
         # Ensure a required variable has an empty value to force the ad hoc window to be re-shown
         ACCOUNT_NAME=""
      fi
      
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
      [[ $VPN_STOP = TRUE ]] && break 1
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
   if [[ ! -e $HELP_VPN_FILE ]]; then
     
      # Create a temporary file to hold the help text
      HELP_VPN_FILE=$(mktemp -q)
     
      # Write the help vpn text to its temporary file
cat <<-end-of-messageblock > $HELP_VPN_FILE

  TO START A VPN CONNECTION
  
  Use either
  Method-1   Manually input the details
  Method-2   Browse for and select an existing profile
  
  
  METHOD-1
  
  IP Address
  Usually the address to contact is the public IP address of the remote firewall
  
  Port Number
  The port the remote firewall forwards to the remote SSH server system
  
  Account Name
  The user name of an existing account on the remote SSH server system
  
  VPN Mode
  Choose one of the following modes
  
     system-to-site
     The remote network handles everything including web browsing and DNS queries
     This mode is equivalent to being physically present at the remote site
     Typical use; connecting from an untrusted location to a trusted network
  
     site-to-site
     The local network handles everything including web browsing and DNS queries
     The remote network provides access to its resources
     This mode is equivalent to a bridge between two discrete networks
     Typical use; connecting a trusted network to another trusted network
  
     manual
     Define your own mode
  
  Subnet Range
  This defines what will be routed within the VPN connection
  Leave this value empty when using a predefined mode
  Provide a value when using manual mode
  Examples
     0.0.0.0/0   route everything
     192.168.1.0/24   route all addresses within a 255.255.255.0 netmask
     192.168.1.7   route a single IP address
  
  Parameters
  These adjust the way both the VPN and SSH encrpyted tunnel behave
  Stipulating switches is:
     Optional for a predefined mode, and usually not needed
     Mandatory for manual mode, and required for all settings not specified above
  In all modes these switches are automatically used and should not be used again
     --daemon
     --pidfile
     --verbose
  Any SSH specific switches must be enclosed in single quotes
  Example
     --no-latency-control -e 'ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=3'
 
  
  METHOD-2
  
  Select an existing profile
  Browse to choose an existing, fully defined profile
  This is available only when an ssh-conduit VPN profile presently exists
  
  
  TO STOP A VPN CONNECTION
  
  Select "Disconnect a VPN"
  This is available only when an ssh-conduit VPN connection is currently established

end-of-messageblock
   fi
}



construct-the-start-vpn-command() 
{
   : 'Assemble the individual components into a command to start a vpn connection'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Sets $VPN_PID_FILE'
   : ' for later use in closing an established vpn session and connection'
   : ' Sets $VPN_START'
   : ' for later use to specify the commands for each mode, system-to-site, site-to-site, manual'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' setsid sshuttle'

   # Location and name of the file containing the process id of the vpn connection
   VPN_PID_FILE="/tmp/ssh-conduit-vpn.$IP_ADDRESS.$VPN_MODE.pid"

   # Assemble the start command elements that are common to all modes
   VPN_START="setsid --wait sshuttle --daemon --pidfile=$VPN_PID_FILE --verbose"
   
   # Handle the start command elements that are not common to all modes 
   case $VPN_MODE in
      system-to-site)  # Ensure dns queries are made via the remote network
                       VPN_START="$VPN_START --dns"
                     
                       # When the user stipulated switches append them to the start command
                       [[ $PARAMETERS != "" ]] && VPN_START="$VPN_START $PARAMETERS"
                     
                       # Ensure the appropriate subnet range is specified to route everything
                       SUBNET_RANGE=0.0.0.0/0
                       ;;
      site-to-site)    # When the user stipulated switches append them to the start command
                       [[ $PARAMETERS != "" ]] && VPN_START="$VPN_START $PARAMETERS"
                     
                       # Ensure the appropriate subnet range is specified to bridge sites
                       SUBNET_RANGE=-N
                       ;;
      manual)          # When the user stipulated switches append them to the start command
                       [[ $PARAMETERS != "" ]] && VPN_START="$VPN_START $PARAMETERS"
                     
                       # Note: No need to specify the subnet range here.  A value has been forced
                       #       in the ad hoc window and is automatically used in the following
                       #       vpn start command
                       ;;
      *)               # Otherwise
                       exit 1        
                       ;;
   esac
}



start-vpn-connection()
{
   : 'Start the ssh tunnel, log-in, begin the vpn session, report the outcome'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Sets $VPN_ESTABLISHED'
   : ' for later use to control whether an icon is added to the taskbar tray'
   : ' displays a window reporting the result of the connection attempt'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' gksu lib-ssh-conduit-suite yad'

   # Start sshuttle to make the vpn connection
   gksu --message "$LIB_MESSAGE_GKSU" "$VPN_START --remote=$ACCOUNT_NAME@$IP_ADDRESS:$PORT_NUMBER $SUBNET_RANGE"
   

   # When making the vpn connection succeeded
   if [[ $? = 0 ]]; then

      # Ensure the capability to display a tray icon is available
      VPN_ESTABLISHED=TRUE
      
      # Assign the success message to be used in the following yad window
      CONNECTION_STATUS_FEEDBACK="\nSuccessfully started VPN connection   \n"
      
      # Ensure the success icon is used in the following yad window
      CONNECTION_STATUS_ICON="$LIB_SUCCESS"
      
      # When making the vpn connection failed
      else
      
      # Assign the failure message used in the following yad window
      CONNECTION_STATUS_FEEDBACK="\nFailed to start VPN connection   \n"
         
      # Ensure the fail icon is used in the following yad window
      CONNECTION_STATUS_ICON="$LIB_FAILURE"
   fi


   # Display the feedback of the sshuttle vpn connection attempt
   yad --center                                      \
       --width=0                                     \
       --height=0                                    \
       --title="$LIB_WINDOW_TITLE"                   \
       --borders="$LIB_BORDER_SIZE"                  \
       --window-icon="$LIB_APP"                      \
       --image-on-top                                \
       --image="$CONNECTION_STATUS_ICON"             \
       --text-align="$LIB_TEXT_ALIGNMENT"            \
       --text="$CONNECTION_STATUS_FEEDBACK"          \
       --timeout-indicator="$LIB_COUNTDOWN_POSITION" \
       --timeout="$COUNTDOWN"                        \
       --buttons-layout="$LIB_BUTTONS_POSITION"      \
       --button="$LIB_CLOSE"
}



stop-vpn-connection()
{
   : 'Ask user to select one or more vpns to disconnect'
   : 'Stop the ssh tunnel, log-out, stop the vpn session, report the outcome'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Displays a window reporting the result of the disconnection attempt'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : '  basename cat find gksu lib-ssh-conduit-suite yad'

   # Capture a list of sshuttle vpn connections presently in use
   VPN_CANDIDATES=$(find /tmp/ -maxdepth 1                    \
                               -type f                        \
                               -name "ssh-conduit-vpn.*.pid"  \
                               -exec basename --suffix=".pid" \
                               {} ';')
   
   
   # Re-show the following yad window until the user either selects
   # a vpn connection or cancels the selection operation
   while [[ $VPN_STOP_SELECTED = "" ]]
   do
	    # Question to display
	    MESSAGE="\n <b><big>Which one(s)?</big></b> \
	             \n"

	    # Text to display in menu column header 1
	    HEADER_COL1="VPN Connections"
	
	    # Display a list of sshuttle vpns presently in use, from which
	    # the user can select one or more to stop
	    VPN_STOP_SELECTED=$(echo "$VPN_CANDIDATES"                         \
                            | yad --center                                 \
                                  --width=600                              \
                                  --height=300                             \
                                  --title="$LIB_WINDOW_TITLE"              \
                                  --borders="$LIB_BORDER_SIZE"             \
                                  --window-icon="$LIB_APP"                 \
                                  --image-on-top                           \
                                  --image="$LIB_APP"                       \
                                  --buttons-layout="$LIB_BUTTONS_POSITION" \
                                  --button="$LIB_OK"                       \
                                  --button="$LIB_CANCEL"                   \
                                  --list                                   \
                                  --multiple                               \
                                  --no-rules-hint                          \
                                  --column "$HEADER_COL1"                  \
                                  --text="$MESSAGE")
            
      # Continue or quit based on how the preceding yad window was closed
      lib_continue-or-quit $?
   done
      
   # Ensure temp_file_1 is empty
   cat /dev/null > $TEMP_FILE_1
     
   # Step through each vpn selected to disconnect, handle each in turn
   echo "$VPN_STOP_SELECTED" | while IFS="|" read -r VPN_NAME
   do
      # Attach the path and file extension to the vpn pidfile name
      VPN_PID_FILE=/tmp/${VPN_NAME}.pid

      # Capture the pid from the vpn pidfile
      VPN_PID=$(cat $VPN_PID_FILE)

      # Terminate the vpn connection
      gksu --message "$LIB_MESSAGE_GKSU" "kill $VPN_PID"

      # Allocate the appropriate feedback about the termination
      case $? in
         0)   # Stopping the vpn connection succeeded
              # Append a feedback message to a file to record the outcome
              echo " Succeeded for $VPN_NAME " >> $TEMP_FILE_1
              ;;
         *)   # Stopping the vpn connection failed
              # Append a feedback message to a file to record the outcome
              echo " Failed for $VPN_NAME " >> $TEMP_FILE_1
              ;;
      esac
   done
   
   
   # When values have been obtained from the config file
   # Note this is whenever the script is not started from the taskbar icon
   if [[ $CONFIG_FILE_VALUES_SOURCED = TRUE ]]; then
      
      # Continue
      :
      
      # When the values have not been obtained from the config file
      # Note this is whenever the script is started from the taskbar icon
      else
      
      # Obtain the config values
      # Note this is to get the user specified timeout values employed in the following yad window
      lib_source-file-or-issue-error-message $CONFIG_DIR "$CONFIG_FILE"
      
      # Guard against the user misconfiguring the countdown timeout period to an empty value
      COUNTDOWN=$(lib_fallback-timeout $COUNTDOWN)
   fi


   # Message to display at the top of the yad window
   MESSAGE="\n <b><big>Stopping the VPN connection</big></b> \
            \n"

   # Display the feedback of the vpn disconnection attempt
   yad --center                                      \
       --width=600                                   \
       --height=300                                  \
       --borders="$LIB_BORDER_SIZE"                  \
       --window-icon="$LIB_APP"                      \
       --title="$LIB_WINDOW_TITLE"                   \
       --image="$LIB_INFO"                           \
       --image-on-top                                \
       --text="$MESSAGE"                             \
       --timeout-indicator="$LIB_COUNTDOWN_POSITION" \
       --timeout="$COUNTDOWN"                        \
       --buttons-layout="$LIB_BUTTONS_POSITION"      \
       --button="$LIB_CLOSE"                         \
       --text-info                                   \
       --filename=$TEMP_FILE_1
}



show-tray-icon()
{
   : ' Displays an icon in the taskbar tray to indicate a vpn is in operation'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Shows a single icon irrespective of the number of vpn connections.'
   : ' Any vpn session can be terminated via this single icon'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' The user setting to activate this feature is in sshuttle.conf'
   :
   : Requires
   : ' lib-ssh-conduit-suite yad'
   
   # Capture whether a vpn icon is currently displayed in the task bar tray   
   ICON_ON_DISPLAY=$(lib_find-process-by-command-string-order '/usr/bin/yad --notification.*tray-icons/ssh-conduit-v')
  
   # When the icon is not on display
   if [[ $ICON_ON_DISPLAY = "" ]]; then
         
      # Guidance to display when hovering cursor over the icon in the tray
      TOOLTIP="Close a VPN session"
         
      # Entries to display in the menu upon right click of the icon in the tray
      RIGHT_CLICK_MENU="Quit!quit"
         
      # Add an icon in the taskbar notification area
      yad --notification                     \
          --no-middle                        \
          --window-icon="$LIB_APP"           \
          --image="$LIB_VPN_SESSION"         \
          --command="$PROGNAME --disconnect" \
          --text="$TOOLTIP"                  \
          --menu="$RIGHT_CLICK_MENU"         &
   fi
}



remove-tray-icon()
{
   : ' Removes the icon from the taskbar tray'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Stops showing the icon when no vpn connections are in operation.'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' kill lib-ssh-conduit-suite'
   
   # Capture whether a vpn icon is currently displayed in the task bar tray
   ICON_ON_DISPLAY=$(lib_find-process-by-command-string-order '/usr/bin/yad --notification.*tray-icons/ssh-conduit-v')
   
   # Capture whether an sshuttle vpn is operating
   SSHUTTLE_VPN=$(lib_find-process-by-command-string-order 'sshuttle.*ssh-conduit-vpn')
   
   # When an icon is on display and there are no active vpn connections
   if [[ $ICON_ON_DISPLAY != "" ]] && [[ $SSHUTTLE_VPN = "" ]]; then
         
      # Capture the id number of the tray icon process to stop
      PID_TO_KILL=$(lib_get-value-of-field "2" " " "${ICON_ON_DISPLAY}")
      
      # Remove the icon
      kill $PID_TO_KILL
   fi
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
   :
   : Requires
   : ' rm'

   # Remove temporary files
   rm -rf $TEMP_FILE_1
   rm -rf $HELP_VPN_FILE
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
VPN connection to the remote LAN.

Usage: 
   $PROGNAME [options]

Options:
   -h, --help   Show this output

Summary:
   Before access to the remote system is granted, an encrypted tunnel is
   automatically created between it and the local system.  The tunnel is
   then used to log-in the local system user to the remote system. After
   a successful log-in, the local user can access resources on the remote
   LAN. The VPN session is secured by passing all traffic within the
   encrypted SSH tunnel.
   
   Creating the tunnel and accessing the reomte system are controlled by 
   the local system user. An operator is not required at the remote
   system location.
   
   Optionally, one or more profiles may be created.  Each profile points
   to a different remote system.  In this way a range of remote systems
   can be defined which enables a VPN connection to be easily established
   to each respective LAN.
   
   During launch, any or none of the profiles may be chosen before a 
   connection is made.  Any one of the profiles can optionally be
   designated as the preferred profile.  In that case it is automatically
   loaded and connected at launch time.  An ad hoc mode is also available
   during launch to enable an on-the-fly connection to a remote system.
   
   For convenience a template profile is provided that may be copied and
   edited as required.
   
   Two predefined VPN modes are available; system-to-site and site-to-site.
   A manual mode is also available.
   
Configuration:
   Profiles
   /home/USERNAME/.config/ssh-conduit/sshuttle/profiles/your-filename.sshuttle
   
   User specified configuration
   /home/USERNAME/.config/ssh-conduit/sshuutle/sshuttle.conf
  
Environment:
   The script works in a GUI (X) environment.

Requires:
   bash, basename, cat, find, gksu, mktemp, rm, setsid, sshuttle, yad
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
   --disconnect)  # Begin the routine to close a vpn connection
                  stop-vpn-connection
                  
                  # Remove the icon from the taskbar tray
                  remove-tray-icon 
                  ;;
   *)             # Otherwise
                  exit 1        
                  ;;
esac   
