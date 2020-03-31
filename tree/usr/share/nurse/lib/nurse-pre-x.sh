#!/bin/bash
# FIXME: re-implement
###########################################################
# License:
# The license of this code allow you to use it for
# non-commercial purposes, if you want to use it for
# commercial purpuses you need the permission of the original
# author (thanatermesis@elivecd.org). You are allowed to
# modify the code and adapt it at your needs, also you can
# send me a patch with bugfixes or new features, they are
# very welcome. If you want to use this code on another
# operating system than Elive, you need to reference that
# this tool is an Elive tool perfectly visible (so, in the
# interface itself of the user at every run (not a hidden option)
# and also include the website link ( http://www.elivecd.org ).
###########################################################
source /lib/lsb/init-functions
source /lib/elive-scripts/elive-functions.sh
source /usr/share/nurse/lib/nurse-post-x.sh
source /etc/default/locale ; export LANG ; update-locale
export EREM="enlightenment_remote"

SOURCE="$0"
source /usr/lib/elive-tools/functions
REPORTS="1"
#el_make_environment
. gettext.sh
TEXTDOMAIN="nurse"
export TEXTDOMAIN

guitool=zenity

echo "$LANG" | grep -qiE "(^en|^es|^it|^fr|^ca|^hr|^da|^nl|^tl|^de|^id|^no|^pl|^ro|^sl)" && export TEXTDOMAIN="nurse" || unset TEXTDOMAIN LANG LANGUAGE LC_ALL LC_MESSAGES

##############################################################################
# Check of the installer-module
##############################################################################
clear
echo -e "************************************"
echo -e "***   Starting Reparation Mode   ***"
echo -e "************************************"

##############################################################################
# First tests of the system
##############################################################################
echo -e ""
log_action_begin_msg "$( eval_gettext "Checking Installed System" )"
sleep 4

unset debugmodule

if [[ -z "$UID" ]] && [[ -z $HOME ]] ; then
   export USER=root
   export USERNAME=root
   export HOME=/root
   export UID=0
fi

if [[ "$UID" != "0" ]] ; then
    echo -e "$( eval_gettext "Please use root" )"
   exit 1
fi

if [[ ! -f /etc/elive-version ]] ; then
    dialog --clear --colors --backtitle "Elive Systems"  --title "$( eval_gettext "Elive Reparation" )"  \
        --msgbox "$( eval_gettext "The Elive Reparation mode is a special recovery tool for the end-user." )"  \
        14 60
fi

check_module_installer_result="$(/usr/lib/eliveinstaller/check-installer-module)"
if [[ -z "$check_module_installer_result" ]] ; then
    check_module_installer_result="$( eval_gettext "No results obtained." )"
   dialog --clear --colors --backtitle "Elive Systems" \
       --title "$( eval_gettext "Elive Reparation" )" \
       --msgbox "It has been detected that your Elive system is not correctly installed, please install Elive again. If the problem persists, report this error message from Reparation mode to Elive.\n\nhttp://bugs.elivecd.org\n\nResult obtained: $check_module_installer_result" \
      14 60
   log_action_end_msg 1
   sleep 1

   log_action_begin_msg "$( eval_gettext "Checking Installer Module" )"
   sleep 2
   export debugmodule=yes
   results="$( /usr/lib/eliveinstaller/check-installer-module 2>&1 )"
   if [[ -z "$results" ]] ; then
      dialog --clear --colors --backtitle "Elive Systems" \
          --title "$( eval_gettext "Elive Reparation" )" \
          --msgbox "The installer-module check has failed, this can be due to a botched install. If you think that this is a bug in Elive, please report it to: http://bugs.elivecd.org \n\nAnd include this data in your report:\n$check_module_installer_result" \
         14 60
      log_action_end_msg 1
      sleep 1
   else
      log_action_end_msg 0
      sleep 1
   fi

   exit 1
else
   log_action_end_msg 0
   sleep 1
fi


##############################################################################
# Request root password
##############################################################################
root_pass_request_try(){
   sleep 1
   echo -e "\n\n""$( eval_gettext "Please Enter the Admin (root) Password" )"
   pass_entered="$( mkpasswd -m md5 -S $root_salt )"
   if [[ "$pass_entered" = "$root_pass" ]] ; then
      return 0
   else
      return 1
   fi
}

root_pass_request(){
   root_pass="$(grep "^root:" /etc/shadow | tail -1 | awk 'BEGIN{FS=":"}; {print $2}' )"
   root_salt="${root_pass#$\1$}"
   root_salt="${root_salt:0:8}"
   root_pass_request_try && return 0
   root_pass_request_try && return 0
   root_pass_request_try && return 0
   root_pass_request_try && return 0
   root_pass_request_try && return 0
   root_pass_request_try && return 0
   echo -e "\n\n""$( eval_gettext "All the attempts have failed, maybe your keyboard has a problem?" )"
   echo -en "$( eval_gettext "You can check this by simply typing the password here" )"
   read nada ; unset nada
   return 1
}
##############################################################################
# Start the Reparation mode (graphical system)
##############################################################################
start_nurse_x(){
   cd $HOME
   source /etc/default/locale ; export LANG ; update-locale
   export TEXTDOMAIN="nurse"

   killall enlightenment_start 2>/dev/null || killall -9 enlightenment_start 2>/dev/null
   killall enlightenment 2>/dev/null || killall -9 enlightenment 2>/dev/null
   rm -r /tmp/enlightenment-${USER}* 2>/dev/null
   elive-skel upgrade .e 1>/dev/null 2>/dev/null
   startx /usr/bin/enlightenment_start -no-precache -- :0 -dpi 100 &
   e_ps=$!


   sleep 16
   $guitool --info --text="$( eval_gettext "Starting Reparation Mode, please be patient..." )" &
   gui_ps=$!

   # FIXME: we dont use E IPC anymore, but DISPLAY vars are needed, how to obtain it ?
   export E_IPC_SOCKET="$(ls -1 /tmp/enlightenment-${USER}/* | tail -1 )"
   export E_IPC_SOCKET="${E_IPC_SOCKET%|*}"
   export DISPLAY="${E_IPC_SOCKET##*disp-}"
   export DISPLAY="${DISPLAY%%-*}"

   $EREM -lang-set "$LANG"
   sleep 1
   $EREM -module-unload itask-ng
   $EREM -desktop-bg-set /usr/share/nurse/images/nurse-background.jpg

   kill $gui_ps 2>/dev/null 1>/dev/null || kill -9 $gui_ps 2>/dev/null 1>/dev/null
   $guitool --info --text="$( eval_gettext "Welcome to the Reparation mode, a tool that allows you to configure and specially repair your system. A lot of different options can be found so please read all of them to know what you can do in this mode." )"

   do_check_installed_packages
   gui_main_menu
   $EREM -exit
   wait
   elive-skel upgrade .e 1>/dev/null 2>/dev/null
   main_menu

   echo "$LANG" | grep -qiE "(^en|^es|^it|^fr|^ca|^hr|^da|^nl|^tl|^de|^id|^no|^pl|^ro|^sl)" && export TEXTDOMAIN="nurse" || unset TEXTDOMAIN LANG LANGUAGE LC_ALL LC_MESSAGES
}

##############################################################################
# Recover the original xorg.conf of Elive
##############################################################################
recover_original_xorg(){
   if ! cp /etc/X11/xorg.conf.elive /etc/X11/xorg.conf ; then
       echo -e "$( eval_gettext "Error copying saved file /etc/X11/xorg.conf.elive, are you sure that it exists?" )"
      read nada
   fi
   dialog --clear --colors --backtitle "Elive Systems" \
       --title "$( eval_gettext "Elive Reparation" )" \
       --msgbox "$( eval_gettext "Original xorg.conf (graphical configuration) made by Elive has been restored. You can reboot now or enter Reparation mode" )" \
   14 60
   main_menu
}

##############################################################################
# Select options of things to do
##############################################################################
main_menu(){
   option="/tmp/.option-nurse"
   dialog --clear --colors --backtitle "Elive Systems" \
       --title "$( eval_gettext "Elive Reparation" )" \
       --menu     "$( eval_gettext "Welcome to the Elive Reparation mode, a special mode that will assist you in reconfiguring and managing your system. It is specially made for recovery purposes." )""\n\n""$( eval_gettext "Before you start the graphical system with Reparation mode maybe you want to do something else:" )""\n" 18 88 5 \
       "start"    "$( eval_gettext "Nothing more to do, start the Reparation mode" )" \
       "xorg"     "$( eval_gettext "Recover the original xorg.conf (graphical configuration)" )" \
       "reboot"   "$( eval_gettext "Reboot your computer now" )" \
       "login"    "$( eval_gettext "Exit from this menu to go to the login screen" )" \
      2>$option

      # FIXME: to implement (add in the list)
      #"config" "$( eval_gettext "Reconfigure your xorg.conf because it doesn't works" )" \

   case "$(cat $option)" in
   start)
      start_nurse_x
      ;;
   xorg)
      recover_original_xorg
      ;;
   configX|configx|config-X|config)
       echo -e "\n""$( eval_gettext "Not implemented yet" )"
      read nada # FIXME to implement
      ;;
   reboot)
      elive-skel upgrade .e 1>/dev/null 2>/dev/null
      reboot
      ;;
   login)
      rm -f $option
      elive-skel upgrade .e 1>/dev/null 2>/dev/null
      exit 0
      ;;
   *)
      main_menu
      ;;
   esac
   rm -f $option
   main_menu
}


root_pass_request || exit 0

main_menu
