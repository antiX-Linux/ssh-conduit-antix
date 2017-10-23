#!/bin/bash


# ***** Library ********************************************************

# Access the suite library
source /usr/local/lib/ssh-conduit/lib-ssh-conduit-suite



# ***** Settings used solely by this script ****************************

# Capture the name of the script including file extension
PROGNAME=${0##*/}

# Set the version number
PROGVERSION=1.1

# Location of the sshfs profiles directory
PROFILE_DIR=${HOME}/.config/ssh-conduit/sshfs/profiles

# Name of the sshfs profile template file
PROFILE_TEMPLATE_FILE=ssh-conduit_template_profile.sshfs

# Location of the sshfs user configurable settings directory
CONFIG_DIR=${HOME}/.config/ssh-conduit/sshfs

# Name of the sshfs user configurable settings file
CONFIG_FILE=sshfs.conf

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
   : ' Connects to and mounts a remote file system using a profile or ad hoc mode'
   : ' Disconnects from and unmounts a mounted remote file system'
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
             FS_STOP=FALSE
             ;;
         1)  # Cancel was selected
             # Quit taking no further action
             exit 1
             ;;
         2)  # Disconnect was selected
             # Ensure the disconnect window will be shown
             FS_STOP=TRUE
             ;;
         3)  # Ad hoc was selected
             # Ensure the preferred profile is not used
             PREFERRED_PROFILE=
             ;;
         70) # Preferred was selected via timeout
             # Ensure the preferred profile is used by retaining its current value unchanged
             # Ensure the disconnect window will not be shown
             FS_STOP=FALSE
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
   
   
   # ----- Connect to the remote system and mount a directory ----------
   
   # When start an fs connection is requested
   if [[ $FS_STOP = FALSE ]]; then
   
      # Validate the availability of the requested local mount point
      validate-mount-point-or-issue-error-message
      
      # When a port number is specified prepend the port flag to the value
      [[ $PORT_NUMBER != "" ]] && PORT_NUMBER="-p $PORT_NUMBER"
      
      # Open the fs connection and mount the remote directory
      start-fs-connection
   fi
   
   
   # ----- Show icon in taskbar tray -----------------------------------
   
   # When the user specified display an icon while a vpn is established
   if [[ $TRAY_ICON = true ]] && [[ $FS_ESTABLISHED = TRUE ]]; then
   
      # Add an icon to the taskbar tray
      show-tray-icon
   fi
   
   
   # ----- Disconnect from the remote system and unmount the directory -
   
   # When stop an fs connection is requested
   if [[ $FS_STOP = TRUE ]]; then
   
      # Close the fs connection
      stop-fs-connection
      
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
   : ' Sets $IP_ADDRESS $PORT_NUMBER $ACCOUNT_NAME $PARAMETERS $REMOTE_FOLDER $MOUNT_POINT'
   : ' for later use to control connecting an fs with manually input values'
   : ' Sets $PROFILE_FILE'
   : ' for later use to control connecting an fs with a manually selected profile'
   : ' Sets $FS_STOP'
   : ' for later use to control disconnecting an fs'
   : ' Sets $SELECT_PROFILE'
   : ' to enable/disable (grey-out) browsing for a profile in this yad window'
   : ' Sets $SELECT_DISCONNECT'
   : ' to enable/disable (grey-out) closing an fs in this yad window'
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
   # ip address, account name, mount point
   # are empty or indicating a user entered value is mandatory
   while [[ $IP_ADDRESS = "" ]]   || [[ $IP_ADDRESS = "$FIELD_INFO_1" ]]   || \
         [[ $ACCOUNT_NAME = "" ]] || [[ $ACCOUNT_NAME = "$FIELD_INFO_1" ]] || \
         [[ $MOUNT_POINT = "" ]]  || [[ $MOUNT_POINT = "$FIELD_INFO_1" ]]
   do
      # Decide whether the capability to manually select a profile is greyed-out
      SELECT_PROFILE=$(lib_enable-or-disable-browsing-to-select-a-profile-manually)

      # Decide whether the capability to disconnect a vpn is greyed-out
      SELECT_DISCONNECT=$(lib_set-checkbox-state-by-command-string-order 'sshfs.*: ')
      
      
      # Message to display at the top of the ad hoc action window
      MESSAGE_1="\n<b><big> Make or break an FS connection</big></b>\n"
         
      
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
      LABEL_06="Remote Folder"
      TYPE_06=""
      VALUE_06=""
      
      # Field 07 assignments
      LABEL_07="Local Folder"
      TYPE_07=""
      VALUE_07="$FIELD_INFO_1"
      
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
      LABEL_11="Select an FS connection"
      TYPE_11="CHK"
      VALUE_11="$SELECT_DISCONNECT"
      
      # Field 12 assignments
      LABEL_12=""
      TYPE_12="LBL"
      VALUE_12=""
            
      # Message to display at the top of the help vpn window
      MESSAGE_2="\n<b><big> Help FS</big></b>\n"


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
                                                    --filename=$HELP_FS_FILE"                \
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
      PARAMETERS=$(lib_get-value-of-field "5" "|" "$AD_HOC_ACTION")
      REMOTE_FOLDER=$(lib_get-value-of-field "6" "|" "$AD_HOC_ACTION")
      MOUNT_POINT=$(lib_get-value-of-field "7" "|" "$AD_HOC_ACTION")
      SELECTED_PROFILE=$(lib_get-value-of-field "9" "|" "$AD_HOC_ACTION")
      FS_STOP=$(lib_get-value-of-field "11" "|" "$AD_HOC_ACTION")
      
      
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
      [[ $FS_STOP = TRUE ]] && break 1
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
   if [[ ! -e $HELP_FS_FILE ]]; then
     
      # Create a temporary file to hold the help text
      HELP_FS_FILE=$(mktemp -q)
     
      # Write the help vpn text to its temporary file
cat <<-end-of-messageblock > $HELP_FS_FILE

  TO CONNECT AND MOUNT A REMOTE FILE SYSTEM
  
  Use either
  Method-1   Manually input the details
  Method-2   Browse for and select an existing profile
  
  
  METHOD-1
  
  IP Address
  Use the private IP address when both systems are in the same LAN
  Use the public IP address of the remote firewall when connecting over the internet
  
  Port Number
  The port the remote firewall forwards to the remote SSH server system
  Leave the value empty when both systems are in the same LAN
  
  Account Name
  The user name of an existing account on the remote SSH server system
  This name is used to log in to the remote system
  
  Parameters
  Use of sshfs parameters is optional
  Example:
     -C -o reconnect -o idmap=user
   
  Remote Folder
  The folder in the remote system to include in this local system
  To mount:
     The entire remote home folder, leave the value empty
     A folder in the remote home folder, provide its name without a leading slash
     A folder not in the remote home folder, provide the full path from the root directory
  Spaces are allowed when the value is enclosed in quotes
  Examples:
     No value
     "Documents/Hints and Tips"
     /tmp

  Local Folder
  The mount point name in this local system where the remote folder and files are shown
  It must be unique. It is automatically created as a folder in the local home directory
  Spaces are allowed when the value is enclosed in quotes
  Example: 
     "popeye on xxx.xxx.xxx.xxx"
 
  
  METHOD-2
  
  Select an existing profile
  Browse to choose an existing, fully defined profile
  This is available only when an ssh-conduit FS profile presently exists
  
  
  TO STOP AND UNMOUNT A REMOTE FILE SYSTEM CONNECTION
  
  Select "Disconnect an FS"
  This is available only when an ssh-conduit FS connection is currently established

end-of-messageblock
   fi
}



validate-mount-point-or-issue-error-message()
{
   : 'Verify an unused mount point is available otherwise exit'
   : ''
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Creates $MOUNT_POINT when it does not already exist'
   : ' Issue an error message if $MOUNT_POINT is in use then exit'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' awk lib-ssh-conduit-suite mkdir mount yad'
   
   # When the mount point does not exist
   if [[ ! -d "$MOUNT_POINT" ]]; then
      
      # Create the mount point
      mkdir "$MOUNT_POINT"
      
      # When the mount point exists
      else
      
      # When the mount point has something currently mounted on it
      if [[ $(mount | awk '/'"$MOUNT_POINT"'/') ]]; then
   
         # Advice to display at top of following yad window
         MESSAGE="\n<b><big>$MOUNT_POINT</big></b> \
                  \n \
                  \nCannot be used as the mount point folder \
                  \nbecause something else is mounted on it \
                  \n \
                  \n"
      
         # Display the advice message
         yad --center                                 \
             --width=0                                \
             --height=0                               \
             --title="$LIB_WINDOW_TITLE"              \
             --borders="$LIB_BORDER_SIZE"             \
             --image-on-top                           \
             --image="$LIB_FAILURE"                   \
             --text-align="$LIB_TEXT_ALIGNMENT"       \
             --text="$MESSAGE"                        \
             --buttons-layout="$LIB_BUTTONS_POSITION" \
             --button="$LIB_CLOSE"                      
       
         # Exit with no further action
         exit 1
      fi
   fi   
}



start-fs-connection()
{
   : 'Start the ssh tunnel, log-in, mount the remote directory, report the outcome'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Sets $FS_ESTABLISHED'
   : ' for later use to control whether an icon is added to the taskbar tray'
   : ' Displays a window reporting the result of the connection attempt'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' lib-ssh-conduit-suite setsid yad'

   # Start sshfs to make the connection and mount the resource
   setsid sshfs $PORT_NUMBER                               \
                $ACCOUNT_NAME@$IP_ADDRESS:"$REMOTE_FOLDER" \
                "$MOUNT_POINT"                             \
                $PARAMETERS                                \
                >/dev/null 2>&1
   
   # When making the connection and mount succeeded
   if [[ $? = 0 ]]; then

      # Ensure the capability to display a tray icon is available
      FS_ESTABLISHED=TRUE
      
      # Assign the success message to be used in the following yad window
      CONNECTION_STATUS_FEEDBACK="\nSuccessfully started FS connection   \n"
      
      # Ensure the success icon is used in the following yad window
      CONNECTION_STATUS_ICON="$LIB_SUCCESS"
      
      # When making the connection and mount failed
      else
      
      # Assign the failure message used in the following yad window
      CONNECTION_STATUS_FEEDBACK="\nFailed to start FS connection   \n"
         
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



stop-fs-connection()
{
   : 'Ask user to select one or more fs to disconnect'
   : 'Stop the ssh tunnel, unmount the remote resource, report the outcome'
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
   : '  awk cat fusermount lib-ssh-conduit-suite rmdir sed yad'
   
   # Capture a list of sshfs fs connections presently in use
   FS_CANDIDATES=$(awk '/fuse.sshfs/ { print $2 }' /etc/mtab \
                   | awk -F "/" '{ print $4 }'               \
                   | sed 's/\\040/ /g')
   
   
   # Re-show the following yad window until the user either selects
   # an fs connection or cancels the selection operation
   while [[ $FS_STOP_SELECTED = "" ]]
   do
	    # Question to display
	    MESSAGE="\n <b><big>Which one(s)?</big></b> \
	             \n"

	    # Text to display in menu column header 1
	    HEADER_COL1="FS Connections Mounted"
	
	    # Display a list of sshfs fs presently in use, from which the 
	    # user can select one or more to stop
	    FS_STOP_SELECTED=$(echo "$FS_CANDIDATES"                          \
                          | yad --center                                 \
                                --width=500                              \
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
     
   # Step through each fs selected to disconnect, handle each in turn
   echo "$FS_STOP_SELECTED" | while IFS="|" read -r FS_MOUNT_POINT_NAME
   do
      # Unmount the remote directory and close the connection
      fusermount -u "$FS_MOUNT_POINT_NAME"

      # Allocate the appropriate feedback about the termination and
      # stipulate whether the corresponding mount point is to be removed
      case $? in
         0)   # Stopping the fs connection succeeded
              # Append a feedback message to a file to record the outcome
              echo " Succeeded for $FS_MOUNT_POINT_NAME " >> $TEMP_FILE_1
              
              # Stipulate the mount point is to be removed
              REMOVE_MOUNT_POINT=true
              ;;
         *)   # Stopping the fs connection failed
              # Append a feedback message to a file to record the outcome
              echo " Failed for $FS_MOUNT_POINT_NAME " >> $TEMP_FILE_1
              ;;
      esac
      
      # When the removal of the mount point is to occur
      if [[ $REMOVE_MOUNT_POINT = true ]]; then
         
         # Remove the mount point
         rmdir "$FS_MOUNT_POINT_NAME"
      fi
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
   MESSAGE="\n <b><big>Stopping the FS connection</big></b> \
            \n"

   # Display the feedback of the fs disconnection attempt
   yad --center                                      \
       --width=500                                   \
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
   : 'Display an icon in the taskbar tray to indicate an fs is mounted'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Shows a single icon irrespective of the number of fs connections.'
   : ' Any fs connection can be terminated via this single icon'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' The user setting to activate this feature is in sshfse.conf'
   :
   : Requires
   : ' lib-ssh-conduit-suite yad'
   
   # Capture whether a vpn icon is currently displayed in the task bar tray   
   ICON_ON_DISPLAY=$(lib_find-process-by-command-string-order '/usr/bin/yad --notification.*tray-icons/ssh-conduit-f')
        
   # When the icon is not on display
   if [[ $ICON_ON_DISPLAY = "" ]]; then
         
      # Guidance to display when hovering cursor over the icon in the tray
      TOOLTIP="Unmount a remote folder"
         
      # Entries to display in the menu upon right click of the icon in the tray
      RIGHT_CLICK_MENU="Quit!quit"
         
      # Add an icon in the taskbar notification area
      yad --notification                     \
          --no-middle                        \
          --window-icon="$LIB_APP"           \
          --image="$LIB_FILE_SYSTEM"         \
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
   : ' Stops showing the icon when no fs connections are in operation.'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' kill lib-ssh-conduit-suite'
   
   # Capture whether an fs icon is currently displayed in the task bar tray
   ICON_ON_DISPLAY=$(lib_find-process-by-command-string-order '/usr/bin/yad --notification.*tray-icons/ssh-conduit-f')
   
   # Capture whether an sshfs connection is operating
   SSHFS_FS=$(lib_find-process-by-command-string-order ' sshfs ')
   
   # When an icon is on display and there are no active vpn connections
   if [[ $ICON_ON_DISPLAY != "" ]] && [[ $SSHFS_FS = "" ]]; then
         
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
   : ' ssh-conduit-sshfs.sh --help'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' cat'

   # Display the following block
cat << end-of-messageblock

$PROGNAME version $PROGVERSION
Creates an SSH encrypted connection between two systems and mounts a
directory from the remote system in the home directory of the local system.

Usage: 
   $PROGNAME [options]

Options:
   -h, --help         Show this output
       --disconnect   Unmount a resouce and close the connection

Summary:
   Before the mount is performed, an encrypted tunnel is automatically
   created between two systems.  When the tunnel is established, a
   remote directory is automatically mounted in the user's local home
   directory and can be used in the same manner as any directory in the
   local file system.  The session is secured by passing all traffic
   within the encrypted SSH tunnel.
   
   Creating the tunnel and mounting the directory are controlled by 
   the local system user. An operator is not required at the remote
   system location.
   
   Optionally, one or more profiles may be created.  Each profile points
   to a different remote system, or to a different directory in the same
   system.  In this way a range of remote data areas can easily be 
   connected as desired.  
   
   During launch, any or none of the profiles may be chosen before a 
   connection is made.  Any one of the profiles can optionally be
   designated as the preferred profile.  In that case the remote 
   directory it specifies is automatically mounted.  An ad hoc mode is
   also available during launch which provides a way to mount a remote
   directory on-the-fly.
   
   For convenience a template profile is provided that may be copied and
   edited as required.
   
Configuration:
   Profiles
   /home/USERNAME/.config/ssh-conduit/sshfs/profiles/your-filename.sshfs
   
   User specified configuration
   /home/USERNAME/.config/ssh-conduit/sshfs/sshfs.conf
  
Environment:
   The script works in a GUI (X) environment. 

Requires:
   awk, bash, cat, mkdir, mktemp, mount, rm, rmdir, sed, setsid, sshfs, yad,
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
   --disconnect)  # Begin the routine to close an fs connection
                  stop-fs-connection
                  
                  # Remove the icon from the taskbar tray
                  remove-tray-icon 
                  ;;
   *)             # Otherwise
                  exit 1        
                  ;;
esac
