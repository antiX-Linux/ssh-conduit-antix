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
   : ' Opens the desired suite component app'
   :
   : Example
   : ' function-name'
   :
   : Note
   : 'none'
   :
   : Requires
   : ' ssh-conduit-admin-centre.sh'
   : ' ssh-conduit-cli.sh'
   : ' ssh-conduit-sshfs.sh'
   : ' ssh-conduit-ssvnc.sh'
   : ' ssh-conduit-sshuttle.sh'

   # ----- Decide type of operation to perform -------------------------
   
   # Choose to connect to remote resource or show local admin centre
   ROLE=$(choose-role)
      
   # Detect the item selected and run the corresponding actions 
   case $ROLE in
      ADM:)    # Show the admin centre
               ssh-conduit-admin-centre.sh
               ;;
      CLI:)    # Open a terminal to a remote system
               ssh-conduit-cli.sh
               ;;
      FS:)     # Mount a remote file system
               ssh-conduit-sshfs.sh
               ;;
      VNC:)    # Operate a remote desktop
               ssh-conduit-ssvnc.sh
               ;;
      VPN:)    # Join/leave a remote network
               ssh-conduit-sshuttle.sh
               ;;
      *)       # Otherwise
               exit 1
               ;;
   esac


   # ---- Quit ---------------------------------------------------------
   
   exit
}



choose-role()
{
   : 'Ask user to select which suite component to run'
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
   : ' awk lib-ssh-conduit-suite yad'
   
   local RETURN_VALUE
      
   # Question to display
   MESSAGE="\n<b><big> Which one?</big></b> \n\n"
   
   # Text to display in the menu for each column in the header row
   HEADER_COL1="Select"
   HEADER_COL2="Summary"

   # Text to display in the menu for each column in each row
   ROW1_COL1="ADM"
   ROW1_COL2="Show the admin centre for this local system"
   ROW2_COL1="CLI"
   ROW2_COL2="Open a terminal to a remote system"
   ROW3_COL1="FS"
   ROW3_COL2="Add/remove a remote folder to/from this local system"
   ROW4_COL1="VNC"
   ROW4_COL2="Operate the desktop of a remote system"
   ROW5_COL1="VPN"
   ROW5_COL2="Join/leave a remote network"

   # Display the menu
   while [[ $ITEM_SELECTED = "" ]]
   do
      ITEM_SELECTED=$(yad --center                                 \
                          --width=700                              \
                          --height=350                             \
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
                          "$ROW1_COL1" "$ROW1_COL2"                \
                          "$ROW2_COL1" "$ROW2_COL2"                \
                          "$ROW3_COL1" "$ROW3_COL2"                \
                          "$ROW4_COL1" "$ROW4_COL2"                \
                          "$ROW5_COL1" "$ROW5_COL2")

      # Continue or quit based on the outcome of the previous command
      lib_continue-or-quit $?
   done
   
   # Return the value of column 1 of the selected menu item
   RETURN_VALUE=$ITEM_SELECTED
   echo "$RETURN_VALUE"
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
Displays a launch menu of SSH-Conduit facilities.

Usage: 
   $PROGNAME [options]

Options:
   -h, --help         Show this output

Summary:
   A system may perform three roles:
   * Connect a variety of remote resources to this local system via SSH
   * Serve a range of local resources to a remote system via SSH
   * Administrate and report on local resources provided by this system
   
   Connect
   The local system can conduct sessions with a remote system providing:
   * Access via a terminal
   * Mounting of a remote file system
   * VNC
   * VPN
   The local user must have an account on the remote system
   
   Serve
   The local system can serve the same range of sessions it can connect to.
   To do so requires the following:
   * SSH daemon is running
   * Python is available
   * X11VNC server is running (included in the SSH-Conduit suite)
   The remote user must have an account on the local system
   
   Administrate/Report
   Provides information and management of the resources served by the
   local system
   
Configuration:
   None for $PROGNAME
   Each suite component provides its own configuration files
  
Environment:
   The script works in a GUI (X) environment. 

Requires:
   awk, bash, cat, yad
   ssh-conduit-admin-centre.sh
   ssh-conduit-cli.sh
   ssh-conduit-sshfs.sh
   ssh-conduit-ssvnc.sh
   ssh-conduit-sshuttle.sh
   lib-ssh-conduit-suite
   Each suite executable script and the library list their own requirements.

See also:
   ssh-conduit-admin-centre.sh
   ssh-conduit-cli.sh
   ssh-conduit-sshfs.sh
   ssh-conduit-sshuttle.sh
   ssh-conduit-ssvnc.sh
   ssh-conduit-x11vnc.sh
   ssh-conduit-x11vnc-server
   lib-ssh-conduit-suite

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
