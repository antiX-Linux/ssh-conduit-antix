#!/bin/bash



# ***** Library ********************************************************

# Access the suite library
source /usr/local/lib/ssh-conduit/lib-ssh-conduit-suite



# ***** Settings used solely by this script ****************************

# Capture the name of the script including file extension
PROGNAME=${0##*/}

# Set the version number
PROGVERSION=1.1

# Location of the ssvnc profiles directory
PROFILE_DIR=${HOME}/.vnc/profiles

# Name of the ssvnc profile template file
PROFILE_TEMPLATE_FILE=ssh-conduit_template_profile.ssvnc

# Name of the directory within profile_dir to hold an ssh known host file per ssvnc profile
KNOWN_HOSTS_DIR=ssh_known_hosts

# Location of the sshvnc user configurable settings directory
CONFIG_DIR=${HOME}/.config/ssh-conduit/ssvnc

# Name of the sshvnc user configurable settings file
CONFIG_FILE=ssvnc.conf



# ***** Functions used solely by this script ***************************

main()
{
   : 'Run the main trunk of the script'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Connects a vnc session using a profile or ad hoc mode'
   : ' Disconnects an established vnc connection'
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
   
   # Ensure a link exists in the config dir to the profile dir
   # Note this maintains consistency of access to the profiles with other suite components
   #      because ssvnc defaults to using a different location to the other suite components
   [[ ! -L ${CONFIG_DIR}/profiles ]] && ln -s ${PROFILE_DIR} ${CONFIG_DIR}/profiles
   
   # Ensure the directory exists to hold an ssh known host file per ssvnc profile
   [[ ! -d ${PROFILE_DIR}/${KNOWN_HOSTS_DIR} ]] && mkdir ${PROFILE_DIR}/${KNOWN_HOSTS_DIR}   
      
   # Obtain the config values
   lib_source-file-or-issue-error-message $CONFIG_DIR "$CONFIG_FILE"
   
   # Determine the values to be used for the xterminal shown when making a connection
   xterm_values
   
   # Determine the text values to use for the vnc viewer
   viewer_text_values
   
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
             VNC_STOP=FALSE
             ;;
         1)  # Cancel was selected
             # Quit taking no further action
             exit 1
             ;;
         2)  # Disconnect was selected
             # Ensure the disconnect window will be shown
             VNC_STOP=TRUE
             ;;
         3)  # Ad hoc was selected
             # Ensure the preferred profile is not used
             PREFERRED_PROFILE=
             # Ensure the disconnect window will not be shown
             VNC_STOP=FALSE             
             ;;
         70) # Preferred was selected via timeout
             # Ensure the preferred profile is used by retaining its current value unchanged
             # Ensure the disconnect window will not be shown
             VNC_STOP=FALSE
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
   fi
   
   
   
   # ----- Manual mode (ad hoc) ----------------------------------------
   
   # This mode is forced by supplying an empty profile name to the sshvnc start command
   
   # When a preferred profile is not to be used
   if [[ $PREFERRED_PROFILE = "" ]]; then
   
      # Ensure the disconnect window will not be shown
      VNC_STOP=FALSE
   fi
      
   
   
   # ----- Connect to the remote system and open a vnc session ---------
   
   # When start a vnc connection is requested
   if [[ $VNC_STOP = FALSE ]]; then
      
      # Open a vnc session
      start-vnc-connection
   fi
   
   
   
   # ----- Disconnect and close a vnc session --------------------------
   
   # When stop a vnc session is requested
   if [[ $VNC_STOP = TRUE ]]; then
   
      # Close the vnc connection
      stop-vnc-connection
   fi
   
   
   
   # ---- Quit ---------------------------------------------------------
   
   exit
}



xterm_values()
{
   : 'Assign default or user specified values for the xterm shown when making a connection'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns xterm settings -fs to set the font size, +rv/-rv to reverse the video colours'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' The following values may be set in supplementary.conf'
   : ' $XTERM_FONT_SIZE, $XTERM_COLOURS'
   :
   : Requires
   : ' none'

   # When a value is missing for the terminal font size assign a default value
   [[ $XTERM_FONT_SIZE = "" ]] && XTERM_FONT_SIZE=12
   
   # When a value is missing for the terminal colours assign a default value 
   [[ $XTERM_COLOURS = "" ]] && XTERM_COLOURS=+rv
}



viewer_text_values()
{
   : 'Assign default or user specified values for text in the vnc viewer'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns x11vnc -env text values to use in the command to start the server'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' The following values may be set in supplementary.conf'
   : ' $WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE, $WINDOW_FIXED_WIDTH_TEXT_SIZE'
   :
   : Requires
   : ' Helvetica font'

   # When a value is missing for window text for menus and buttons assign a default size
   [[ $WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE = "" ]] &&  WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE=12
   # Assemble the combined value of font and size
   WINDOW_MENUS_AND_BUTTONS_TEXT="Helvetica -$WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE"
   WINDOW_MENUS_AND_BUTTONS_TEXT=""$WINDOW_MENUS_AND_BUTTONS_TEXT""
      
   # When a value is missing for window fixed width text assign a default size
   [[ $WINDOW_FIXED_WIDTH_TEXT_SIZE = "" ]] && WINDOW_FIXED_WIDTH_TEXT_SIZE=12
   # Assemble the combined value of font and size
   WINDOW_FIXED_WIDTH_TEXT="Helvetica -$WINDOW_FIXED_WIDTH_TEXT_SIZE"
   WINDOW_FIXED_WIDTH_TEXT=""$WINDOW_FIXED_WIDTH_TEXT""
}



opportunity-to-decline-preferred-profile()
{
   : 'Offer user an option to select one of the following:'
   : '   use the preferred profile'
   : '   use ad hoc mode'
   : '   cancel'
   : 'Timeout default selects use preferred profile'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' returns the exit code of the yad button clicked'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' lib-ssh-conduit-suite yad'

   # Question to display
      MESSAGE="\n<b><big> Which one?</big></b> \n\n"
      
      # Field 01 assignments
      LABEL_01="<b>Preferred Profile</b> \
               \nContinue using this profile \n"
      TYPE_01="LBL"
      VALUE_01=""

      # Field 02 assignments
      LABEL_02="<b>Ad Hoc</b> \
               \nManually input the details or choose an alternative profile \n"
      TYPE_02="LBL"
      VALUE_02=""
   
      # Field 03 assignments
      LABEL_03=""
      TYPE_03="LBL"
      VALUE_03=""

      # Display the window asking the user to choose what to do
      yad --center                                      \
          --width=0                                     \
          --height=0                                    \
          --title="$LIB_WINDOW_TITLE"                   \
          --borders="$LIB_BORDER_SIZE"                  \
          --window-icon="$LIB_APP"                      \
          --image-on-top                                \
          --image="$LIB_APP"                            \
          --text-align="$LIB_TEXT_ALIGNMENT"            \
          --text="$MESSAGE"                             \
          --timeout-indicator="$LIB_COUNTDOWN_POSITION" \
          --timeout="$COUNTDOWN"                        \
          --buttons-layout="$LIB_BUTTONS_POSITION"      \
          --button="$LIB_PREFERRED"                     \
          --button="$LIB_AD_HOC"                        \
          --button="$LIB_CANCEL"                        \
          --form                                        \
          --field="$LABEL_01":"$TYPE_01" "$VALUE_01"    \
          --field="$LABEL_02":"$TYPE_02" "$VALUE_02"    \
          --field="$LABEL_03":"$TYPE_03" "$VALUE_03"  
}



start-vnc-connection()
{
   : 'Start the local sshvnc viewer and connect to the remote x11vnc server'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Displays the remote desktop on the local screen'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' lib-ssh-conduit-suite ssvnc'

   # Start vnc session and report the outcome in its terminal window
   SSVNC_XTERM_REPLACEMENT="xterm -fa Monospace                                               \
                                  -fs $XTERM_FONT_SIZE                                        \
                                  $XTERM_COLOURS                                              \
                                  -T \"$WINDOW_TITLE\"                                        \
                                  -e" env SSVNC_FONT_DEFAULT="$WINDOW_MENUS_AND_BUTTONS_TEXT" \
                                      env SSVNC_FONT_FIXED="$$WINDOW_FIXED_WIDTH_TEXT"        \
                                      sshvnc "$PROFILE_FILE"                                  &
                                  # Notes:
                                  # When $PROFILE_FILE is not empty sshvnc automatically loads and connects to it
                                  # When $PROFILE_FILE is empty sshvnc waits at its gui for the user to choose what to do
}



stop-vnc-connection()
{
   : 'Advise the user to close the connection via its window'
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
   : ' lib-ssh-conduit-suite yad'
       
   # Advice message to display
   MESSAGE="\n Closing a VNC connection should be \
            \n performed via F8 in its viewer window \
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
Creates an SSH encrypted connection between two systems and enables the
desktop of one system to be controlled from the other one.

Usage: 
   $PROGNAME [options]

Options:
   -h, --help   Show this output

Summary:
   Before the VNC session is opened, an encrypted tunnel is automatically
   created between two systems.  When the tunnel is established, a VNC
   viewer is launched on the local system which displays the GUI desktop
   of the other system that is running a VNC server. The VNC session is
   secured by passing all traffic within the SSH encrypted tunnel.
   
   Creating the tunnel and opening the VNC session are controlled by the
   VNC viewer operator. An operator is not required at the VNC server
   system location.
   
   Optionally, one or more profiles may be created.  Each profile points
   to a different VNC server system.  In this way a range of remote VNC
   server systems can be defined and easily connected as desired.  
   
   When the VNC viewer (sshvnc) is launched, any or none of the profiles
   may be chosen before a connection is made.  Any one of the profiles
   can optionally be designated as the preferred profile.  In that case
   it is automatically loaded and connected when sshvnc is launched.
   
   For convenience a template profile is provided that may be copied and
   edited as required.
   
Configuration:
   Profiles (including template profile)
   /home/USERNAME/.vnc/profiles/filename-of-your-choice.sshvnc
   
   User specified configuration (including preferred profile)
   /home/USERNAME/.config/ssh-conduit/sshvnc/sshvnc.conf
  
Environment:
   The script works in a GUI (X) environment. 

Requires:
Requires:
   bash, cat, ssvnc, yad
   lib-ssh-conduit-suite
   Each suite executable script and the library list their own requirements.
   
   SSVNC has a built in capability to transfer files between the systems.
   If it is to be used ensure the following is installed:
   default-jre

See also:
   ssh-conduit.sh

References:
   http://www.karlrunge.com/x11vnc/ssvnc.html

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
