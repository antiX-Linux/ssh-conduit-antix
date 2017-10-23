#!/bin/bash

   

# ***** Library ********************************************************

# Access the suite library
source /usr/local/lib/ssh-conduit/lib-ssh-conduit-suite



# ***** Settings used solely by this script ****************************

# Capture the name of the script including file extension
PROGNAME=${0##*/}

# Set the version number
PROGVERSION=1.1

# Location of ssh-conduit-x11vnc config files
CONFIG_DIR=/etc/ssh-conduit/x11vnc

# Name of ssh-conduit-x11vnc required settings file
REQUIRED_SETTINGS_FILE=x11vncrc

# Name of ssh-conduit-x11vnc supplementary settings file
SUPPLEMENTARY_SETTINGS=supplementary.conf

# Name of ssh-conduit-x11vnc password file
PASSWORD_FILE=passwd

# Operation to be performed by the script
MODE=$1



# ***** Functions used solely by this script ***************************

main()
{
   : 'Run the main trunk of the script'
   :
   : Parameters
   : ' arg1   server|gui|password'
   :
   : Result
   : ' Performs the task corresponding to arg1'
   : ' server   starts x11vnc server'
   : ' gui      attaches to a running x11vnc server and shows a configuration gui for it'
   : ' password modifies the vnc session password'
   :
   : Example
   : ' ssh-conduit-x11vnc.sh server'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' lib-ssh-conduit-suite x11vnc'
   : ' Helvetica font'

   # ----- Configurable settings ---------------------------------------
   
   # Obtain the supplementary settings to be used by the x11vnc server
   lib_source-file-or-issue-error-message $CONFIG_DIR $SUPPLEMENTARY_SETTINGS
      
   
   
   # ----- Start the server --------------------------------------------
   
   # When start the server is requested
   if [[ $MODE = server ]]; then
      
      # Ensure only a single instance of the suite vnc server
      prevent_multiple_instances
      
      # Determine which authority file to use to display the screen
      choose_authority_file
      
      # Determine the type of server gui to use
      server_gui_type
      
      # Determine the text values to use for the server gui
      server_gui_text_values
      
      # Determine whether to try to work around screen update problems in a compositing wm
      compositing_wm_workaround
      
      # Start the server using the required and determined configuration values
      start_server
   fi
   
   
   
   # ----- Start a discrete server gui and attach it to the server -----
   
   # When start a gui is requested
   if [[ $MODE = gui ]]; then
   
      # Determine the type of server gui to use
      server_gui_type
      
      # Determine the text values to use for the server gui
      server_gui_text_values
      
      # Start the server gui using the determined values
      attach_server_gui
   fi
   
   
   
   # ----- Modify the vnc session password -----------------------------
   
   # When change the vnc session password is specified
   if [[ $MODE = password ]]; then
      
      # Determine the type of terminal emulator to use
      terminal_emulator_type
      
      # Modify the vnc session password using the determined value
      change_password      
   fi
   
   
   
   # ---- Quit ---------------------------------------------------------
   
   exit
}



choose_authority_file()
{
   : 'Select the X authority file the server should use'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns x11vnc -auth option to use in the command to start the server'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' $DISPLAY_MANAGER_AUTH is set in supplementary.conf'
   :
   : Requires
   : ' none'

   # When a user is not logged-in to an X session
   if [[ $DISPLAY = "" ]]; then
         
      # Ensure the raw display manager MIT-MAGIC-COOKIE file is used
      AUTH="-auth $DISPLAY_MANAGER_AUTH"
      
      # When a user is logged-in to an X session
      else
         
      # Ensure the MIT-MAGIC-COOKIE file for the logged-in user is used
      AUTH=""
   fi
}



server_gui_text_values()
{
   : 'Assign default or user specified values for text in the server gui'
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
   : ' $TRAY_ICON_TEXT_SIZE, $TRAY_ICON_MENU_TEXT_SIZE'
   : ' $WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE, $WINDOW_FIXED_WIDTH_TEXT_SIZE'
   :
   : Requires
   : ' Helvetica font'

   # When a value is missing for the tray icon text assign a default size
   [[ $TRAY_ICON_TEXT_SIZE = "" ]] && TRAY_ICON_TEXT_SIZE=10
   # Assemble the combined value of font and size
   TRAY_ICON_TEXT="Helvetica -$TRAY_ICON_TEXT_SIZE bold"
      
   # When a value is missing for the tray icon menu text assign a default size
   [[ $TRAY_ICON_MENU_TEXT_SIZE = "" ]] && TRAY_ICON_MENU_TEXT_SIZE=12
   # Assemble the combined value of font and size
   TRAY_ICON_MENU_TEXT="Helvetica -$TRAY_ICON_MENU_TEXT_SIZE"
      
   # When a value is missing for window text for menus and buttons assign a default size
   [[ $WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE = "" ]] &&  WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE=12
   # Assemble the combined value of font and size
   WINDOW_MENUS_AND_BUTTONS_TEXT="Helvetica -$WINDOW_MENUS_AND_BUTTONS_TEXT_SIZE bold"
      
   # When a value is missing for window fixed width text assign a default size
   [[ $WINDOW_FIXED_WIDTH_TEXT_SIZE = "" ]] && WINDOW_FIXED_WIDTH_TEXT_SIZE=12
   # Assemble the combined value of font and size
   WINDOW_FIXED_WIDTH_TEXT="Helvetica -$WINDOW_FIXED_WIDTH_TEXT_SIZE"
}



server_gui_type()
{
   : 'Select the type of gui the server should use to access its menus'
   :
   : Parameters
   : ' nome'
   :
   : Result
   : ' Returns x11vnc -gui option to use in the command to start the server'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' $GUI_MODE is set in supplementary.conf'
   :
   : Requires
   : ' none'
   
   # When a user is not logged-in to an X session
   if [[ $DISPLAY = "" ]]; then
         
      # Set the gui type to empty as it is invalid for this mode of server operation.
      # In this case the gui type must be handled in the start up script of an
      # unprivileged user after logging into an X session.
      GUI=""
      
      # When a user is logged-in to an X session
      else
      
      # Set up the nominated way of accessing the server options on screen
      case $GUI_MODE in
         tray)    # Place an icon in the system tray of the task bar
                  GUI='-gui tray'
                  ;;
         window)  # Open a standard window
                  GUI='-gui simple'
                  ;;
         *)       # Default to use when the user supplies an empty value
                  GUI='-gui tray'
                  ;;
      esac
   fi
}



compositing_wm_workaround()
{
   : 'Try to work around screen update problems in a compositing wm'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns x11vnc -noxdamage option to use in the command to start the server'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' $COMPOSITING is set in supplementary.conf'
   :
   : Requires
   : ' none'

   # When user indicated a compositing window manager is in use
   case $COMPOSITING in
         true)    # Place an icon in the system tray of the task bar
                  NOXDAMAGE='-noxdamage'
                  ;;
         *)       # Default to use when the user supplies any other value
                  NOXDAMAGE=""
                  ;;
      esac
}



prevent_multiple_instances()
{
   : 'Ensure only a single instance of the suite vnc server'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Display an error message and exit if the suite vnc server is currently running'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :   :
   : Requires
   : ' lib-ssh-conduit-suite yad'

   # Capture whether an x11vnc server is running as part of ssh-conduit
   RUNNING_AS_SUITE_PROCESS=$(lib_find-process-by-command-string-order "${CONFIG_DIR}/${REQUIRED_SETTINGS_FILE}")
      
   # When x11vnc is running as part of ssh-conduit
   if [[ $RUNNING_AS_SUITE_PROCESS != "" ]]; then
         
      # Message to display
      MESSAGE="\n The suite vnc server is already running. \
               \n Only a single instance is permitted.  \
               \n \
               \n"
      
      # Display the message
      yad --center                                   \
          --width=0                                  \
          --height=0                                 \
          --title="$LIB_WINDOW_TITLE"                \
          --borders="$LIB_BORDER_SIZE"               \
          --image-on-top                             \
          --image="$LIB_INFO"                        \
          --text-align="$LIB_TEXT_ALIGNMENT"         \
          --text="$MESSAGE"                          \
          --margins=3                                \
          --buttons-layout="$LIB_BUTTONS_POSITION"   \
          --button="$LIB_CLOSE"
          
      exit
   fi
}



start_server()
{
   : 'Start the server using the required and determined configuration values'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Run a server suitable for use ante or post user login to an X-session'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' When started automatically as part of the boot-up routine:'
   : '   the gui and text elements in this block are not used. They are' 
   : '   handled by the mode=gui block which is called from the start up'
   : '   file owned by the user after log-in to an X-session'
   :
   : '   If the system is set to show the display manager log-in screen'
   : '   the server will be available at that point during the initial'
   : '   boot-up and after a user has logged-out of an X-session'
   :
   : ' When started after boot up i.e. a user is logged-in to an X session'
   : '   the gui and text elements are handled by this block'
   :
   : '   The server remains available only during the period the user is'
   : '   logged-in to an X-session.  It stops when the user logs out and'
   : '   it does not restart at a subsequent log-in'
   :
   : ' If the tray icon is closed via "Stop X11VNC" while the server is'
   : ' running the icon is automatically restarted and restored to the tray'
   :
   : Requires
   : ' x11vnc'

   # Start x11vnc in ssh mode and whenever it terminates, conditionally restart it
   x11vnc -rc ${CONFIG_DIR}/${REQUIRED_SETTINGS_FILE}            \
          $AUTH                                                  \
          $GUI                                                   \
          $NOXDAMAGE                                             \
          -loop2000                                              \
          -env X11VNC_FONT_BOLD_SMALL="$TRAY_ICON_TEXT"          \
          -env X11VNC_FONT_REG_SMALL="$TRAY_ICON_MENU_TEXT"      \
          -env X11VNC_FONT_BOLD="$WINDOW_MENUS_AND_BUTTONS_TEXT" \
          -env X11VNC_FONT_FIXED="$WINDOW_FIXED_WIDTH_TEXT"      \
          >/dev/null 2>&1                                        &
          # Note: redirection is to supress loop messages from x11vnc
}



attach_server_gui()
{
   : 'Start a server gui using the determined configuration values'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' attaches to a running x11vnc server and shows a gui for it'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' The anticipated way of starting is during the boot-up and login'
   : ' routine from the startup file owned by the user after log-in to'
   : ' an X-session'
   :
   : ' If the tray icon is closed via "Stop X11VNC" while the server is'
   : ' running the icon is automatically restarted and restored to the tray'
   :
   : Requires
   : ' lib-ssh-conduit-suite x11vnc'
   : ' Helvetica font'

   # Capture whether an x11vnc server is running as part of ssh-conduit
   RUNNING_AS_SUITE_PROCESS=$(lib_find-process-by-command-string-order "${CONFIG_DIR}/${REQUIRED_SETTINGS_FILE}")
      
   # When x11vnc is running as part of ssh-conduit
   if [[ $RUNNING_AS_SUITE_PROCESS != "" ]]; then
         
      # Connect to the running server, show the server gui, restart it whenever it terminates
      x11vnc $GUI,conn                                              \
             -loop2000                                              \
             -env X11VNC_FONT_BOLD_SMALL="$TRAY_ICON_TEXT"          \
             -env X11VNC_FONT_REG_SMALL="$TRAY_ICON_MENU_TEXT"      \
             -env X11VNC_FONT_BOLD="$WINDOW_MENUS_AND_BUTTONS_TEXT" \
             -env X11VNC_FONT_FIXED="$WINDOW_FIXED_WIDTH_TEXT"      \
             >/dev/null 2>&1                                        &
             # Note: redirection is to supress loop messages from x11vnc
   fi
}



terminal_emulator_type()
{
   : 'Assign default value for the terminal emulator to use to modify the vnc session password'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Returns the name used by x-terminal-emulator as a fallback value'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' $PREFERRED_TERMINAL is set in supplementary.conf'
   :
   : Requires
   : ' x-terminal-emulator'

   # When the value is missing for the preferred terminal assign a default
   [[ $PREFERRED_TERMINAL = "" ]] && PREFERRED_TERMINAL=x-terminal-emulator
}



change_password()
{
   : 'Modifies the password required to open a vnc session'
   :
   : Parameters
   : ' none'
   :
   : Result
   : ' Creates an initial or changes an existing vnc session password'
   :
   : Example
   : ' function-name'
   :
   : Note
   : ' none'
   :
   : Requires
   : ' chmod gksu lib-ssh-conduit-suite stat x11vnc x-terminal-emulator'

   # Modify the x11vnc session password
   gksu --message "$LIB_MESSAGE_GKSU" "$PREFERRED_TERMINAL -e x11vnc -storepasswd ${CONFIG_DIR}/${PASSWORD_FILE}"
               
   # Capture the permissions of the x11vnc password file
   PASSWORD_FILE_PERMISSIONS=$(stat -c %a ${CONFIG_DIR}/${PASSWORD_FILE})
               
   # When the x11vnc password file has inappropriate permissions reset them
   [[ $PASSWORD_FILE_PERMISSIONS != 644 ]] && gksu chmod 644 ${CONFIG_DIR}/${PASSWORD_FILE}
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
   :
   : Requires
   : ' cat'

   # Display the following block
cat << end-of-messageblock

$PROGNAME version $PROGVERSION
Serve the local desktop via VNC across an SSH enrypted connection

Usage:
   $PROGNAME [options]

Options:
   server        Start an x11vnc server in ssh mode
   gui           Add a configuration gui to a running x11vnc server
   password      Change the password required to start a VNC session
   -h, --help    Show this output

Summary:
   When started with the option: server 
   x11vnc is started in a mode that requires a connection from a
   vnc viewer to be made using SSH via localhost.
   
   If no local user is logged in via the display manager and a desktop
   is not yet running, x11vnc shows the usual log in screen of the
   display manager in the vnc viewer.
   
   If a local user has logged in via the display manager and a desktop
   is running, x11vnc shows the desktop of the local user in the VNC
   viewer.
   
   In both the above cases a vnc password is required in order to start
   the VNC session. It must be provided from the VNC viewer side each
   time a connection is requested.
   
   When started with the option: password
   A password is created.  The password file must be created manually
   only once. The password can be changed by running the command again.
      
   When started with the option: gui
   A configuration GUI is added to and shown in an instance of x11vnc
   that was started previously.   
   
   The configuration GUI can be run in either of two modes:
   Tray mode shows an icon in the task bar tray
   Window mode shows a standard window on the desktop
   
Launchers:
   Server and GUI modes are automatically started at different points 
   of the boot-up/log-in routine, so are started from separate files:
   
   Server mode
   /etc/init.d/
   
   Gui mode
   /home/USERNAME/.desktop-session/startup
   
Log:
   A file is rewritten each time x11vnc starts in server mode
   /var/log/ssh-conduit-x11vnc.log

Configuration:
   Required server settings
   /etc/ssh-conduit/x11vnc/x11vncrc
   
   Supplementary server settings
   /etc/ssh-conduit/x11vnc/supplentary.conf
  
Environment:
   The script works in a GUI (X) environment. 

Requires:
   bash, cat, chmod, gksu, stat, x11vnc, x-terminal-emulator
   Helvetica font
   lib-ssh-conduit-suite
   Each suite executable script and the library list their own requirements.

Reference:
   http://www.karlrunge.com/x11vnc/

See also:
   ssh-conduit.sh
   ssh-vnc-server

References:
   http://www.karlrunge.com/x11vnc/ssvnc.html

end-of-messageblock
   exit
}



# ***** Start the script ***********************************************
case $1 in
   server|gui|password) # Begin the main trunk of the script
                        main
                        ;;
   --help|-h)           # Show info and help
                        usage
                        ;;
   *)                   # Otherwise
                        exit 1        
                        ;;
esac   
