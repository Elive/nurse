#!/bin/bash
#===============================================================================
#
#          FILE:  nurse-post-x.sh
#
#         USAGE:  ./nurse-post-x.sh
#
#   DESCRIPTION:  post X of nurse mode
#
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Thanatermesis (Thanatermesis), thanatermesis@gmail.com
#       COMPANY:  Elivecd.org
#       VERSION:  1.0
#       CREATED:  22/08/09 17:52:02 CEST
#      REVISION:  ---
#       LICENSE:  The license of this code allow you to use it for
#                 non-commercial purposes, if you want to use it for
#                 commercial purpuses you need the permission of the original
#                 author (thanatermesis@gmail.com). You are allowed to
#                 modify the code and adapt it at your needs, also you can
#                 send me a patch with bugfixes or new features, they are
#                 very welcome. If you want to use this code on another
#                 operating system than Elive, you need to reference that
#                 this tool is an Elive tool perfectly visible (so, in the
#                 interface itself of the user at every run (not a hidden option)
#                 and also include the website link ( http://www.elivecd.org ).
#===============================================================================
. gettext.sh
TEXTDOMAIN="nurse"
export TEXTDOMAIN


#===  FUNCTION  ================================================================
#          NAME:  exit_me
#   DESCRIPTION:  Exit step
#    PARAMETERS:
#       RETURNS:
#===============================================================================
exit_me(){
    exit $1
    rm -r /tmp/enlightenment-${USER}* 2>/dev/null
    rm -f /tmp/.option-nurse 2>/dev/null
}


#===  FUNCTION  ================================================================
#          NAME:  install_dependency
#   DESCRIPTION:  install a package dependency if is not installed
#    PARAMETERS:  executable, packagename
#       RETURNS:
#===============================================================================
install_dependency(){
    if ! test -x "$1" ; then
        $guitool --info --text="$( eval_gettext "We need to install a dependency package, please ensure that you have access to the internet to continue" )"
        if ! check_if_internet ; then
            $guitool --error --text="$( eval_gettext "No internet connection found" )"
            return 1
        else
            urxvt -e bash -c "apt-get update && apt-get -f install && apt-get install $2"
        fi
    fi
}


#===  FUNCTION  ================================================================
#          NAME:  do_check_installed_packages
#   DESCRIPTION:  checks installed packages and install them if they are not installed
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_check_installed_packages(){
    $guitool --question --text="$( eval_gettext "Do you want to check your installed packages? Your system can run wrongly if it doesn't has installed all the default packages included by Elive, it is very recommended to do this check. Do you want to continue?" )" || return

    dpkg -l | awk '{print $1" "$2}' | grep -E "(^ii|^hi)" | awk '{print $2}' > /tmp/.installed-packages

    if ! check_if_internet ; then
        $guitool --error --text="$( eval_gettext "No internet connection found. To run this tool you need to be connected to internet" )"
        return 1
    else
        urxvt -e bash -c "apt-get update"
    fi

    ( sleep 10 ; echo 25 ; sleep 10000 ) | $guitool --progress --pulsate --text="$( eval_gettext "Checking packages, please be patient..." )" &
    gui_pid=$!

    cat /etc/elive/system/packages/packages-installed | while read package
do
    if ! grep -q $package /tmp/.installed-packages ; then
        local message_found
        message_found="$( printf "$( eval_gettext "Warning: I have found a package that is not installed in your system, this is a default package of your Elive system, your system may work incorrectly without it, do you want to reinstall it?\n\nPackage: %s" )" "$package" )"

        if $guitool --question --text="$message_found" ; then
            urxvt -geometry 100 -e bash -c "apt-get install ${package}"
            urxvt -geometry 100 -e bash -c "apt-get -f install"
        fi
    fi
done

kill $gui_pid
#$guitool --info
}


#===  FUNCTION  ================================================================
#          NAME:  do_health
#   DESCRIPTION:  do hardware tests and verifications for the correct work of it
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_health(){
    $guitool --question --text="$( eval_gettext "This tool allows you to do some hardware verification, to see if the components work properly and without problems. These tests check for errors in the hard disk, in your RAM, and your processor. If you complete all these steps without any error, your computer is working perfectly. Do you want to continue ?" )" || return 0

    #-------------------------------------------------------------------------------
    #   Disk check
    #-------------------------------------------------------------------------------
    if $guitool --question --text="$( eval_gettext "Do you want to verify if your hard disk contains bad blocks ? This operation can be very slow and time-consuming. If you see several lines with lots of numbers, then errors were found, but you can stop the process at any moment by closing the terminal" )"   # FIXME: add a feature in the installer to allow bad blocks
    then
        result="$( fdisk -l 2>/dev/null | grep "^Disk" | grep bytes | grep -v "contain a valid partition table" | awk '{print $2"\n"$3" "$4}' | sed -e 's|:||g' -e 's|,||g' \
            | awk '{print $0}END{print"Select_manually\nManual"}' | $guitool --list --text="$( eval_gettext "Select the Hard Disk to use" )" --column="$( eval_gettext "Disk" )" --column="$( eval_gettext "Size" )" || echo cancel )"

        if [[ "$result" = "Select_manually" ]] ; then
            result="$( $guitool --entry --text="$( eval_gettext "Enter the name of the desired device." )" --entry-text="/dev/..." || echo cancel )"
        fi
        if ! check_result_guitool $result ; then
            $guitool --error --text="$( eval_gettext "Incorrect option selected" )"
            unset result
        fi
        if ! test -b $result 1>/dev/null 2>&1 ; then
            $guitool --error --text="$( eval_gettext "Incorrect disk selected" )"
            unset result
        fi

        if [[ ! -z "$result" ]] ; then
            urxvt -geometry 100 -hold -e bash -c "badblocks -vs ${result} ; echo ; echo Finished, close this window"
        fi
    fi


    #-------------------------------------------------------------------------------
    #   CPU check
    #-------------------------------------------------------------------------------
    if $guitool --question --text="$( eval_gettext "We are going to test CPU calculations. This will stress test your processor with mathematical calculations. If they are incorrect, this is very bad for your data. You should not need more than 15 minutes for a test, just watch the terminal for any error messages,. You can close the terminal at any moment to stop the process,. If this is the case, the common cause of this will be that your CPU is too hot. To solve this, first of all try to clean it (no layer of dust). Or it may need a better cooler. It is recommended to get silent coolers to minimize noise. Or you may have overclocked it too much, so drop down it a notch. If it is not any of these causes, then your cpu or motherboard may be damaged or defective; please consult a specialist. Do you want to continue ?" )" ; then
        install_dependency "/usr/bin/mprime-cpu" "mprime-cpu"

        urxvt -geometry 100 -hold -e bash -c "mprime-cpu -t"
    fi

    #-------------------------------------------------------------------------------
    #   Ram check
    #-------------------------------------------------------------------------------
    $guitool --info --text="$( eval_gettext "To run the RAM diagnostic check, you need to reboot the computer and select that option from the boot menu:" )"" Memory RAM Diagnostic. ""$( eval_gettext "You need to run this process for a few hours, better yet, run it overnight. If you see any error there you should change your RAM immediately, RAM errors are really very bad for your data and is the common cause of lots of errors that do not seem to make sense. By the way be sure that you do not get 'false positives' errors (Search online for help)" )"


    #-------------------------------------------------------------------------------
    #   Other checks
    #-------------------------------------------------------------------------------
    $guitool --info --text="$( eval_gettext "It is recommended to open the computer case from time to time to check that everything is alright, i.e. there's no dust on the coolers and that all the pieces are correctly attached or well-seated." )"
}



#===  FUNCTION  ================================================================
#          NAME:  do_cleanup_system
#   DESCRIPTION:  do a cleanup of the system freeing space
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_cleanup_system(){
    local message_logs
    message_logs="$( printf "$( eval_gettext "The logs of your system sometimes takes a large quantity of space, specially with big debug options enabled, you can also disable it in the installation process of Elive (complete mode)\n\nThe actual size for it is: %s" )" "$(du -hs /var/log/)" )"

    if $guitool --question --text="$message_logs" ; then
        #find /var/log/ -type f -exec rm -f {} \;
        for FILE in $(find /var/log/ -type f)
        do
            : > ${FILE}
        done
    fi

    if $guitool --question --text="$( eval_gettext "Do you want to clean the trash and temporal files of all the users?" )" ; then
        for user in $DHOME/*
        do
            [[ -d ${user}/.local/share/Trash ]] && rm -rf ${user}/.local/share/Trash/*
            [[ -d ${user}/.thumbnails ]] && rm -rf ${user}/.thumbnails/*
            [[ -d ${user}/.streamtunner/cache ]] && rm -rf ${user}/.streamtunner/cache/*
            [[ -d ${user}/.xsession-errors ]] && rm -rf ${user}/.xsession-errors
            userlist="$userlist $user"
        done
        rm -rf /root/.local/share/Trash/* 2>/dev/null
        $guitool --info --text="$( eval_gettext "Trash cleaned for users" )"
        unset user userlist
    fi

    if $guitool --question --text="$( eval_gettext "Do you want to run an application to inspect your hard disk searching where more space is wasted?" )" ; then
        install_dependency "/usr/bin/baobab" "gnome-utils"
        baobab
    fi

    $guitool --info
}



#===  FUNCTION  ================================================================
#          NAME:  do_boot_recover
#   DESCRIPTION:  recover boot of the system (vmlinuz, initrd, etc)
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_boot_recover(){
    $guitool --question --text="$( eval_gettext "You are going to recover the boot of the normal system, do you want to continue ?" )" || return 0
    urxvt -geometry 100 -e bash -c "echo 'Regenerating initrd, please wait...' ; update-initramfs -k $(uname -r) -u -t ; cp /boot/vmlinuz-$(uname -r).nurse /boot/vmlinuz-$(uname -r) "
    if $guitool --question --text="$( eval_gettext "Do you want to reinstall Grub to your disk boot ? (you should not need this)" )" ; then
        result="$( fdisk -l 2>/dev/null | grep "^Disk" | grep bytes | grep -v "contain a valid partition table" | awk '{print $2"\n"$3" "$4}' | sed -e 's|:||g' -e 's|,||g' \
            | awk '{print $0}END{print"Select_manually\nManual"}' | $guitool --list --text="$( eval_gettext "Select the Hard Disk to use" )" --column="$( eval_gettext "Disk" )" --column="$( eval_gettext "Size" )" || echo cancel )"

        if [[ "$result" = "Select_manually" ]] ; then
            result="$( $guitool --entry --text="$( eval_gettext "Enter the name of the desired device." )" --entry-text="/dev/..." || echo cancel )"
        fi
        if ! check_result_guitool $result ; then
            $guitool --error --text="$( eval_gettext "Incorrect option selected" )"
            unset result
        fi
        if ! test -b $result 1>/dev/null 2>&1 ; then
            $guitool --error --text="$( eval_gettext "Incorrect disk selected" )"
            unset result
        fi

        if [[ ! -z "$result" ]] ; then
            urxvt -geometry 100 -e bash -c "grub-install --recheck --no-floppy $result"
        fi
    fi
    $guitool --info
}


#===  FUNCTION  ================================================================
#          NAME:  do_boot_list_edit
#   DESCRIPTION:  edit grub menu.lst file
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_boot_list_edit(){
    $guitool --question --text="$( eval_gettext "Did you mess up the boot list configuration file (menu.lst of grub) and wish to recover the original?" )" && cp /boot/grub/menu.lst.bak-elive /boot/grub/menu.lst
    $guitool --question --text="$( eval_gettext "Are you going to edit the boot menu? You can change or add operating systems or options. Although there is no graphical tool to edit the boot menu directly, you can use any text editor on it. The file is easy enough to understand. Numerous examples or documentation can be found online using Google. Do you want to continue ?" )" && scite /boot/grub/menu.lst
    $guitool --info
}


#===  FUNCTION  ================================================================
#          NAME:  do_entrance_conf_recover
#   DESCRIPTION:  recover entrance conf
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_entrance_conf_recover(){
    $guitool --question --texty="$( eval_gettext "The Entrance (login manager) configuration is messed up. Do you want to revert to the original default Elive configuration?" )" && cp /etc/entrance_config.cfg.bak /etc/entrance_config.cfg
    sleep 1
    $guitool --info
}


#===  FUNCTION  ================================================================
#          NAME:  do_kernel_install_new
#   DESCRIPTION:  installs a new kernel
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_kernel_install_new(){
    # FIXME: añadir en el fichero de info de elive (/etc/elive) el numero de kernel original que se instaló. UPDATE: obtenerlo de la lista de paquetes instalados ? nah, mas seguro asi...
    $guitool --question --text="$( eval_gettext "You are going to install a new Elive Kernel. The old one will be saved, with the new you can have updated drivers, you can install special versions of the kernel like the highmem that let you to use more than 4 GB of memory RAM. Do you want to continue ?" )" || return 0

    if ! check_if_internet ; then
        $guitool --error --text="$( eval_gettext "No internet connection found. To run this tool you need to be connected to internet" )"
        return 1
    else
        urxvt -e bash -c "apt-get update"
    fi

    kernel_to_install="$(
    for package in $( apt-cache search linux-image elive | grep "^linux-image" | sort -g | awk '{print $1}' )
    do
        echo "$package"
        case "$package" in
            (*core2*highmem*)
                echo "$( eval_gettext "For Core2Duo processors and more than 4 GB of RAM" )"
                ;;
            (*highmem*|*bigmem*)
                echo "$( eval_gettext "Lets you use more than 4 GB of RAM" )"
                ;;
            (*)
                echo "$( eval_gettext "Normal Version" )"
                ;;
        esac
    done | $guitool --list --column="$( eval_gettext "Package" )" --column="$( eval_gettext "Description" )" --width=630 --height=400 || echo cancel )"

    check_result_guitool $kernel_to_install || return 0

    kernel_version="${kernel_to_install#linux-image-}"
    packages_to_install="$( apt-cache search $kernel_version | awk '{print $1}' | grep -v "nvidia" | grep -v "fglrx" | grep -v "^linux-image" | grep -v "^linux-source" | grep -v "^linux-tree" | grep -v "^linux-headers" | grep -v "squashfs" | sort -u | tr '\n' ' ' )"

    # do the first full list of things to install
    if test -f /etc/elive/system/packages/packages-to-remove ; then
        for package in $packages_to_install
        do
            grep -q "${package%$kernel_version}" /etc/elive/system/packages/packages-to-remove && packages_to_install="${packages_to_install/$package/}"
        done
    fi

    # check if requires some nvidia packages
    if test -f /etc/elive/system/packages/packages-to-hold ; then
        if grep -q nvidia-glx /etc/elive/system/packages/packages-to-hold ; then
            $guitool --question --text="$( eval_gettext "Warning: You have nvidia packages installed. Installing a new kernel may need to update the nvidia-glx package, which can made incompatible nvidia in your current kernel. You are then limited to using the new one, and for revert (downgrade) to the original kernel later you will need to reinstall Elive. Do you wish to continue ?" )" || return 0
            hold_all=yes
        fi

        prevalue="$( grep nvidia-glx /etc/elive/system/packages/packages-to-hold | sed 's|nvidia-glx||g' )"
        nvidia_kernel_package="$( apt-cache search nvidia-kernel${prevalue}-${kernel_version} | tail -1 | awk '{print $1}' )"
        if [[ -z "$nvidia_kernel_package" ]] ; then
            local message_nvidia
            message_nvidia="$( printf "$( eval_gettext "No packages found for %s" )" "nvidia-kernel${prevalue}-${kernel_version}" )"

            $guitool --error --text="$message_nvidia"
            return 0
        else
            packages_to_install="$packages_to_install $nvidia_kernel_package nvidia-glx${prevalue}"
        fi
    fi

    # check if requires some fglrx packages
    if test -f /etc/elive/system/packages/packages-to-hold ; then
        if grep -q fglrx-glx /etc/elive/system/packages/packages-to-hold ; then
            $guitool --question --text="$( eval_gettext "Warning: You have fglrx (ATI) packages installed. Installing a new kernel may need you to update the fglrx-glx package, which can make an incompatible fglrx in your current kernel. You are then limited to using the new one, and for revert (downgrade) to the original kernel you will need to reinstall Elive. Do you wish to continue ?" )" || return 0
            hold_all=yes

            fglrx_kernel_package="$( apt-cache search fglrx-kernel-${kernel_version} | tail -1 | awk '{print $1}' )"
            if [[ -z "$fglrx_kernel_package" ]] ; then
                local message_ati
                message_ati="$( printf "$( eval_gettext "No packages found for %s" )" "fglrx-kernel-${kernel_version}" )"

                $guitool --error --text="$message_ati"
                return 0
            else
                packages_to_install="$packages_to_install $fglrx_kernel_package fglrx-glx fglrx-driver"
            fi

        fi
    fi

    urxvt -geometry 100 -e bash -c "apt-get -f install"
    urxvt -geometry 100 -e bash -c "apt-get install -y linux-image-${kernel_version}"
    urxvt -geometry 100 -e bash -c "apt-get -f install"
    for package in $packages_to_install
    do
        urxvt -geometry 100 -e bash -c "apt-get install -y $package"
    done

    # This is needed ? do tests:
    #   urxvt -geometry 100 -hold -e bash -c "apt-get -f install ; for package in $(cat /etc/elive/system/packages/packages-to-remove | tr '\n' ' ' ) ; do apt-get remove $package ; done ; echo ; echo Finished, close this window"

    if [[ "$hold_all" = "yes" ]] ; then
        for package in $packages_to_install
        do
            echo $package hold | dpkg --set-selections
        done
    fi

    /usr/share/nurse/lib/grub-aggregator.awk -v kernel_version="$kernel_version" /boot/grub/menu.lst > /boot/grub/menu.lst.new
    mv /boot/grub/menu.lst.new /boot/grub/menu.lst

    $guitool --info
}


#===  FUNCTION  ================================================================
#          NAME:  do_wifi_configure
#   DESCRIPTION:  configure/install a driver for wireless
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_wifi_configure(){
    $guitool --info --text="$( eval_gettext "Some wireless cards are not provided with Linux drivers. This is the fault of the manufacturer. It is very bad service not to provide you with a driver for the product you paid for (are you going to buy a device without drivers for windows?). This problem exists for some devices in MacOsX as well. You can help to get drivers for GNU/Linux by emailing the manufacturer requesting a driver for Linux. " )"
    $guitool --info --text="$( eval_gettext "There's only 2 things that you can do in order to make your Wireless card working, the first one is to install the linux driver, by compile it yourself maybe, the best way to do that is by just searching in google your device card name and the word linux and see if there's drivers for linux for it, you will found the instructions about how to install it too. The second solution is less recommended because with some devices exist the possibility to make your computer unstable, so you can have an entire crash on your system (very bad for your data) due to this, or maybe you can have it working without problems at all, this second option is to use the original drivers of Windows with Ndiswrapper, so use it at your own risk and knowing about this problem. A third solution is to buy a USB wireless device that is correctly supported in Linux (search that in google) and use it instead" )"
    $guitool --question --text="$( eval_gettext "The next step is to configure Ndiswrapper in order to install the driver for your wireless card in case that you have no other options, are you going to continue?" )" || return 0

    mkdir -p /tmp/ndiswrapper/cab
    $guitool --info --text="$( eval_gettext "Please give me the directory where I should search for the windows driver of your wifi card, it can be a CDROM on the /media directory, or an entire Windows partition on /mnt" )"
    ndis_search_dir="$( $guitool --file-selection --directory || echo cancel )"
    [[ "$ndis_search_dir" = "cancel" ]] && return

    ( sleep 4 ; echo 25 ; sleep 10000 ) | $guitool --progress --pulsate --auto-close --text="$( eval_gettext "Searching possible drivers, this operation can take a long time, please be patient" )" &
    pid=$!
    find "$ndis_search_dir" -type f -iname '*'inf | grep -iv autorun | awk '{print "ndiswrapper -i \""$0"\""}' | sh
    find "$ndis_search_dir" -type f -iname '*'cab | grep -iv autorun | awk '{print "cp \""$0"\" /tmp/ndiswrapper/cab"}' | sh
    echo "$ndis_search_dir" | grep -q "/media" && find "$ndis_search_dir" -type f -iname '*'exe | grep -iv autorun | awk '{print "cp \""$0"\" /tmp/ndiswrapper/cab"}' | sh
    lugar=$(pwd)
    cd /tmp/ndiswrapper/cab
    for file in *
    do
        cabextract "$file"
    done

    for file in $(ls -1 | grep -i "inf$" )
    do
        ndiswrapper -i "$file"
    done

    cd "$lugar"
    kill $pid 2>/dev/null
    unset pid

    for dir in $( ndiswrapper -l | grep "invalid driver" | awk '{print $1}')
    do
        rm -rf /etc/ndiswrapper/"$dir"
    done

    ndiswrapper -l | $guitool --list --column="ID" --text="$( eval_gettext "This is a list of installed drivers" )"

    $guitool --info --text="$( eval_gettext "If the driver for your wifi is not installed you can try to download a different version of the driver from internet or just select to scan your windows partition in order to search the files for the installed driver" )"

    lsmod | awk '{print $1}' | grep -q b43 && rmmod b43
    sync
    modprobe ndiswrapper

    $guitool --question --text="$( eval_gettext "It is your wireless card working now ? Try it in the internet configuration and if not works, click to the Cancel button (otherwise we will install it permanently)" )" || return

    grep ndiswrapper /etc/modules || echo "ndiswrapper" >> /etc/modules
    lsmod | awk '{print $1}' | grep -q b43 && echo "blacklist b43" >> /etc/modprobe.d/blacklist

    $guitool --info
}



#===  FUNCTION  ================================================================
#          NAME:  do_remove_win_apps
#   DESCRIPTION:  removes windows applications (menus and data)
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_remove_win_apps(){
    $guitool --question --text="$( eval_gettext "This tool will remove entirely all of your windows applications installed. If you want to remove them one by one, just use the deinstallers from the menus of applications" )"

    result="$( ls -1 $DHOME | $guitool --list --column="$( eval_gettext "User" )" --text="$( eval_gettext "Select the desired user" )" || echo cancel )"

    check_result_guitool $result || return

    if [[ -d "${DHOME}/$result" ]] ; then
        rm -rf ${DHOME}/${result}/.local/share/applications/wine
        rm -rf ${DHOME}/${result}/.local/share/desktop-directories/wine* 2>/dev/null
        rm -rf ${DHOME}/${result}/.wine 2>/dev/null
    else
        $guitool --error --text="User directory '${DHOME}/$result' not exists"
        return
    fi
    $guitool --info
}



#===  FUNCTION  ================================================================
#          NAME:  do_remove_menu_apps
#   DESCRIPTION:  remove applications from menus
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_remove_menu_apps(){
    $guitool --question --text="$( eval_gettext "This tool is for removal of the application entries of your menus, sometimes they are badly written and you may need to remove them in order to have them working correctly. Do you want to continue?" )" || return
    result="$( ls -1 $DHOME | $guitool --list --column="$( eval_gettext "User" )" --text="$( eval_gettext "Select the desired user" )" || echo cancel )"

    check_result_guitool $result || return

    if [[ -d "${DHOME}/${result}/.local/share/applications" ]] ; then
        cd ${DHOME}/${result}/.local/share/applications

        lang=${LC_MESSAGES%%_*}
        resultlist="$(
        find . -type f -iname "*.desktop" | grep -v "usercreated" | grep -v elxstrt | grep -v esetroot | sed 's|^\.\/||g' | while read file
    do
        name="$( grep -q "Name[$lang]=" "$file" && grep "Name[$lang]=" "$file" | head -1 || grep "Name=" "$file" | head -1 )"
        name="${name#*=}"
        [[ -z "$name" ]] && name="$( eval_gettext "Unknown" )"

        comment="$( grep -q "Comment[$lang]=" "$file" && grep "Comment[$lang]=" "$file" | head -1 || grep "Comment=" "$file" | head -1 )"
        comment="${comment#*=}"
        [[ -z "$comment" ]] && comment="$( eval_gettext "Unknown" )"

        echo "remove"
        echo "$file"
        echo "$name"
        echo "$comment"

        unset name comment
    done
    )"

    if [[ ! -z "$resultlist" ]] ; then
        result="$( echo "$resultlist" | $guitool --list --column="Remove" --column="Filename" --column="Name" --column="Comment" --text="$( eval_gettext "Select menu entry's of applications to remove" )" --width=600 --height=400 --checklist )"
    else
        $guitool --info --text="$( eval_gettext "You don't have any entries remaining to remove." )"
        return 0
    fi

    echo "$result" | tr '|' '\n' | while read file
do
    [[ -f "$file" ]] && rm -f "$file"
done

   else
       $guitool --error --text="User directory '${DHOME}/${result}/.local/share/applications' not exists"
       return
   fi

   $guitool --info
}



#===  FUNCTION  ================================================================
#          NAME:  do_update_configurations
#   DESCRIPTION:  update user configurations
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_update_configurations(){
    $guitool --question --text="$( eval_gettext "This tool is to reset the user configurations to the defaults set by Elive, your configuration for such application will be erased, do you want to continue?" )" || return

    result="$( ls -1 $DHOME | $guitool --list --column="$( eval_gettext "User" )" --text="$( eval_gettext "Select the desired user" )" || echo cancel )"

    check_result_guitool $result || return

    if [[ -d "${DHOME}/$result" ]] ; then
        xhost +
        su -c "elive-skel interactive" "$result" # FIXME: move elive-skel upgrade to here
        xhost -
    fi

    $guitool --info
}



#===  FUNCTION  ================================================================
#          NAME:  do_recover_configuration
#   DESCRIPTION:  recover an old upgraded configuration
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_recover_configuration(){
    $guitool --question --text="$( eval_gettext "This tools is for recovery of an old updated configuration, there's no history so you can recover it only to the last updated one. Do you want to continue?" )" || return

    result="$( ls -1 $DHOME | $guitool --list --column="$( eval_gettext "User" )" --text="$( eval_gettext "Select the desired user" )" || echo cancel )"

    check_result_guitool "$result" || return

    if [[ -d "${DHOME}/$result" ]] ; then

        $guitool --error --text="Sorry, not yet implemented"
        return # FIXME: feature "recover" not yet implemented in elive-skel

        xhost +
        su -c "elive-skel recover" "$result"
        xhost -
    fi

    $guitool --info
}



#===  FUNCTION  ================================================================
#          NAME:  do_disks_plug_fix
#   DESCRIPTION:  fix problems with plugged disks, remove them from fstab
#    PARAMETERS:
#       RETURNS:
#===============================================================================
do_disks_plug_fix(){
    $guitool --question --text="$( eval_gettext "This tool will allow you to remove fstab entry's, sometimes you may have an entry on your fstab that doesn't allow you to automatically mount a plugged device, by removing it you will have it pluggable again" )"

    resultlist="$(
    cat /etc/fstab | while read line
do
    echo "$line" | awk '{if ($2 ~ "/mnt/" && $1 !~ "^#") print $1}' | while read dev
do
    unset format size
    format="$( echo "$line" | awk '{print $3}' | head -1 )"
    echo "$dev" | grep -q "UUID=" && dev="$(uuid_decode $dev)"
    if ! echo "$dev" | grep -q "UUID=" && echo "$dev" | grep -q "^/dev/" ; then
        echo "$dev"
        size="$( echo "$( cat /proc/partitions | awk -v dev=${dev##*/} '{if ($4 == dev) print $3}' | head -1 ) / 1024" | bc -l )"
        echo "${size%%.*} MB"
        echo "$format"
        unset format size
    fi
    unset format size
done
   done
   )"

   if [[ ! -z "$resultlist" ]] ; then
       result="$( echo "$resultlist" | $guitool --list --column="$( eval_gettext "Device" )" --column="$( eval_gettext "Size" )" --column="$( eval_gettext "Type" )" || echo cancel )"
   else
       $guitool --info --text="$( eval_gettext "You don't have any entries remaining to remove." )"
       return 0
   fi

   check_result_guitool $result || return

   local message_remove_disk
   message_remove_disk="$( printf "$( eval_gettext "You are going to remove the disk %s from your fstab file in order to allow it to be automounted when is plugged, do you want to continue?" )" "$result" )"

   $guitool --question --text="$message_remove_disk" || return

   umount $result 2>/dev/null

   awk -v dev=$result '{if ($1 == dev && $2 ~ "/mnt") $0 = "#"$0}{print $0}' /etc/fstab > /etc/fstab.new
   mv /etc/fstab.new /etc/fstab

   uuid="$( blkid "$result" | tr ' ' '\n' | grep "^UUID" | sed -e 's|UUID=\"||' -e 's|\"||' | tail -1 )"
   awk -v dev="UUID=$uuid" '{if ($1 == dev && $2 ~ "/mnt") $0 = "#"$0}{print $0}' /etc/fstab > /etc/fstab.new
   mv /etc/fstab.new /etc/fstab

   unset result uuid resulstlist

   $guitool --info
}














#===  FUNCTION  ================================================================
#          NAME:  gui_main_menu
#   DESCRIPTION:  main menu of the GUI
#    PARAMETERS:
#       RETURNS:
#===============================================================================
gui_main_menu(){
    resolution="$(xdpyinfo | grep dimensions | tail -1 | awk '{print $2}')"
    width="$(echo "${resolution%x*} - 40 " | bc -l )"
    height="$(echo "${resolution#*x} - 100 " | bc -l )"
    if [[ ! "$width" -gt "600" ]] || [[ ! "$width" -lt "4000" ]] ; then
        width=600
    fi
    if [[ ! "$height" -gt "500" ]] || [[ ! "$height" -lt "4000" ]] ; then
        height=500
    fi

    # TODO: Features to add:
    #        - dvd/cd disaster app
    #        - testdisk for recover partitions
    #        - photorec, (on testdisk) to recover audio/video/images on corrupted disks (like a flash card device)
    #        - translations: explain how to do translations

    result="$( echo -e \
        "Configurations\n""Clean or update personal configurations""\n"\
        "Health\n""Hardware tests and verifications will indicate if it is working properly""\n"\
        "Cleanup\n""Do a cleanup of your system and freeing space on your hard disk""\n"\
        "Boot\n""Recover the boot (vmlinuz, initrd, grub, etc)""\n"\
        "BootList\n""Edit the list of operating systems in the boot menu""\n"\
        "Entrance\n""Recover entrance configuration (login manager)""\n"\
        "Kernel\n""Install a new version of the kernel""\n"\
        "Wifi\n""Is your wireless card not configured yet ?""\n"\
        "Passwords\n""Change users (or admin) passwords""\n"\
        "AppsWinDel\n""Remove 'windows' installed applications""\n"\
        "AppsMenuDel\n""Remove personal applications/icons from the menus (some may be broken)""\n"\
        "ConfsRecover\n""Recover old configurations that were updated by accident""\n"\
        "Keyboard\n""Change Keyboard mapping""\n"\
        "Language\n""Change Language""\n"\
        "DisksPlug\n""If you cannot use an externally plugged disk, use this option""\n"\
        "Report\n""Report a bug or problem in Elive""\n"\
        "WinMigrate\n""How to import and migrate things from your 'windows' system""\n"\
        "Translations\n""What about the translations of Elive?""\n"\
        "Exit\n""Exit from here" \
        | $guitool --list --column="Action" --column="Description" --width="$width" --height="$height" || echo cancel )"

    case $result in
        Health)
            do_health
            ;;
        Cleanup)
            do_cleanup_system
            ;;
        Boot)
            do_boot_recover
            ;;
        BootList)
            do_boot_list_edit
            ;;
        Entrance)
            do_entrance_conf_recover
            ;;
        Kernel)
            do_kernel_install_new
            ;;
        Wifi)
            do_wifi_configure
            ;;
        Passwords)
            user-manager
            ;;
        AppsWinDel)
            do_remove_win_apps
            ;;
        AppsMenuDel)
            do_remove_menu_apps
            ;;
        Configurations)
            do_update_configurations
            ;;
        ConfsRecover)
            # FIXME: "elive-skel recover" feature not implemented yet
            do_recover_configuration
            ;;
        Keyboard)
            keybconf
            ;;
        Language)
            langconf
            ;;
        DisksPlug)
            do_disks_plug_fix
            ;;
        Report)
            $guitool --info --text="$( eval_gettext "If you found a malfunction in Elive, just report it to http://bugs.elivecd.org. If you want to discuss it with other users you can use the forum http://forum.elivecd.org or chat with Elive users using the application from the Internet applications menu (it should also be in your dock as a second icon)." )"
            ;;
        WinMigrate)
            $guitool --info --text="$( eval_gettext "For the Web Browser (firefox): From your windows go to 'export bookmarks' and in your Elive do a 'import bookmarks', if you don't have firefox installed on windows just install it" )"
            $guitool --info --text="$( eval_gettext "For emule: Just copy or move entirely the directory Incoming to the amule of Elive (you may need to install it)" )"
            $guitool --info --text="$( eval_gettext "For torrents: You need to add again the torrent files to the new application, for continue your downloads just copy the data of your semi-downloaded torrents to the new application temporal files" )"
            ;;
        Translations)
            $guitool --info --text="$( eval_gettext "You are welcome to collaborate with Elive by making translations, for that you just need to run the application 'eltrans', remember that you do not need to do the translations entirely, so that a small part of the work done by many users results in a big end result. Remember too that the English translations are the most important ones, in order to translate the Elive system to a more correct english just do the translations to the 'en' language, remember too that all the other translations are based on these english ones. Thanks a lot for your collaboration." )"
            ;;
        cancel|Exit)
            return 0
            ;;
        *)
            echo "Option not recognized"
            true
            ;;
    esac

    gui_main_menu # return to the main menu after every finished thing

}

