#!/usr/bin/bash

# called by dracut
check() {
    [[ "$mount_needs" ]] && return 1
    [[ $(pkglib_dir) ]] || return 1

    require_binaries cage foot || return 1

    return 0
}

# called by dracut
depends() {
    echo drm
}

# called by dracut
install() {
    inst_multiple cage foot recinit id
    instmods evdev

    inst_rules 60-input-id.rules

    #Workaround for older versions of Cage
    inst_simple "/bin/true" "/usr/bin/Xwayland"

    MonospaceFontPath=$(fc-match -f %{file} monospace)
    if [ -n $MonospaceFontPath ]
    then
      inst_simple "$MonospaceFontPath" 
    fi

    BoldMonospaceFontPath=$(fc-match -f %{file} monospace:weight=bold)
    if [ -n $BoldMonospaceFont ]
    then
        inst_simple "$BoldMonospaceFontPath"
    fi

    if [ -e /usr/lib/locale/[cC].[uU][tT][fF]*8/ ]
    then
        CUTF8DIR=$(basename $(ls -d /usr/lib/locale/[cC].[uU][tT][fF]*8))
        find /usr/lib/locale/$CUTF8DIR ! -type d | while read -r file
        do
            inst_simple "$file"
        done
    fi

    if [ -e /usr/share/libinput ]
    then
        find /usr/share/libinput ! -type d | while read -r file
        do
            inst_simple "$file"
        done
    fi

    if [ -e /usr/share/X11/xkb ]
    then
        inst_simple /usr/share/X11/xkb/compat/accessx
        inst_simple /usr/share/X11/xkb/compat/basic
        inst_simple /usr/share/X11/xkb/compat/caps
        inst_simple /usr/share/X11/xkb/compat/complete
        inst_simple /usr/share/X11/xkb/compat/iso9995
        inst_simple /usr/share/X11/xkb/compat/ledcaps
        inst_simple /usr/share/X11/xkb/compat/lednum
        inst_simple /usr/share/X11/xkb/compat/ledscroll
        inst_simple /usr/share/X11/xkb/compat/level5
        inst_simple /usr/share/X11/xkb/compat/misc
        inst_simple /usr/share/X11/xkb/compat/mousekeys
        inst_simple /usr/share/X11/xkb/compat/xfree86
        inst_simple /usr/share/X11/xkb/keycodes/aliases
        inst_simple /usr/share/X11/xkb/keycodes/evdev
        inst_simple /usr/share/X11/xkb/rules/evdev
        find /usr/share/X11/xkb/symbols -maxdepth 1 ! -type d | while read -r file
        do
            inst_simple "$file"
        done
        inst_simple /usr/share/X11/xkb/types/basic
        inst_simple /usr/share/X11/xkb/types/complete
        inst_simple /usr/share/X11/xkb/types/extra
        inst_simple /usr/share/X11/xkb/types/iso9995
        inst_simple /usr/share/X11/xkb/types/level5
        inst_simple /usr/share/X11/xkb/types/mousekeys
        inst_simple /usr/share/X11/xkb/types/numpad
        inst_simple /usr/share/X11/xkb/types/pc
    fi

    if [ -e /usr/share/X11/locale ]
    then
        # In the off chance the user uses their compose key in initrd
        if [ -f "/usr/share/X11/locale/compose.dir" ]
        then
            inst_simple /usr/share/X11/locale/compose.dir
            grep UTF-8/Compose: /usr/share/X11/locale/compose.dir | awk -F: '{ print $1 }' | sort -u | xargs dirname | while read -r DIR
            do
                find /usr/share/X11/locale/$DIR -maxdepth 1 ! -type d | while read -r file
                do
                    inst_simple "$file"
                done
            done
        fi
    fi

    if [ -e /etc/footkiosk.conf ]
    then
        inst_simple /etc/footkiosk.conf
    fi

    inst_simple "$moddir/recinit-dracut-emergency" /usr/bin/recinit-dracut-emergency
    inst_simple "$moddir/dracut-lib-recinit-shell.sh" "/lib/dracut-lib-recinit-shell.sh"
    echo ". /lib/dracut-lib-recinit-shell.sh" >> $initdir/lib/dracut-lib.sh
}
