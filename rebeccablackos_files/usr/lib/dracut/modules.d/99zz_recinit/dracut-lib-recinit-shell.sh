#! /bin/sh

_emergency_shell_dracut() {
    local _name="$1"
    if [ -n "$DRACUT_SYSTEMD" ]; then
        : > /.console_lock
        echo "PS1=\"$_name:\\\${PWD}# \"" > /etc/profile
        systemctl start dracut-emergency.service
        rm -f -- /etc/profile
        rm -f -- /.console_lock
    else
        debug_off
        source_hook "$hook"
        echo
        /sbin/rdsosreport
        echo 'You might want to save "/run/initramfs/rdsosreport.txt" to a USB stick or /boot'
        echo 'after mounting them and attach it to a bug report.'
        if ! RD_DEBUG='' getargbool 0 rd.debug -d -y rdinitdebug -d -y rdnetdebug; then
            echo
            echo 'To get more debug information in the report,'
            echo 'reboot with "rd.debug" added to the kernel command line.'
        fi
        echo
        echo 'Dropping to debug shell.'
        echo
        export PS1="$_name:\${PWD}# "
        [ -e /.profile ] || : > /.profile

        _ctty="$(RD_DEBUG='' getarg rd.ctty=)" && _ctty="/dev/${_ctty##*/}"
        if [ -z "$_ctty" ]; then
            _ctty=console
            while [ -f /sys/class/tty/$_ctty/active ]; do
                read -r _ctty < /sys/class/tty/$_ctty/active
                _ctty=${_ctty##* } # last one in the list
            done
            _ctty=/dev/$_ctty
        fi
        [ -c "$_ctty" ] || _ctty=/dev/tty1
        case "$(/usr/bin/setsid --help 2>&1)" in *--ctty*) CTTY="--ctty" ;; esac
        setsid $CTTY /bin/sh -i -l 0<> $_ctty 1<> $_ctty 2<> $_ctty
    fi
}

_emergency_shell() {
    if ls /dev/dri/card* 1> /dev/null 2>&1
    then
        HAS_MODESETTING_DEVICE=1
    else
        HAS_MODESETTING_DEVICE=0
    fi

    if [ -z $norecinit ] && [ $HAS_MODESETTING_DEVICE ] ; then
        if command -v recinit >/dev/null 2>&1; then
            echo "No TTYs detected. Starting user mode recovery console. pass norecinit=1 to disable"
            recinit -- recinit-dracut-emergency
        else
            _emergency_shell_dracut
        fi
    fi
}
