OVERVIEW:

Use the latest ISO here: http://sourceforge.net/projects/rebeccablackos/files/

This is inspired by Linux distributions of the same theme (Hannah Montana Linux, and Justin Beiber Linux) that have appeared in the Linux community, only this is Rebecca Black Linux. 

There are many native Wayland toolkits and libraries installed, QT, KDE Frameworks 5, GTK, EFL, Clutter and SDL has been compiled on this CD to support Wayland as well as mplayer, and gstreamer. There are a few applications that don't work, but many more are starting to work.

Xwayland is also included, which allows X applications to run under a Wayland server. Xwayland has a few issues, but is usable.

There are also other Wayland Desktop environments installed: Orbital, and Hawaii, and three non Weston Wayland servers: Enlightenment, swc, and Gnome Shell Wayland, aside from the default Weston shell. Enlightenment currently only runs nested, and not on 'bare metal' yet. Gnome shell's application support is limited.

This distribution is fan made. Yes. I am a fan of Rebecca Black.


How to use the ISO:
  Burn it, (or put it in a VM), reboot, set the BIOS to boot from the CD if it does not already, boot from the CD. Once it boots you can use the live system. 

  The ISO is built with Remastersys, which makes it compatible with unetbootin, and the USB Startup creator. It is also a hybrid ISO, so it can boot raw from a flash drive.

You could also use the test_RBOS_ISO.sh to test weston on the iso without a reboot. Put the .iso into your home folder, make the test_RBOS_ISO script executable, and run the script from a terminal, and pass the path to the ISO file as an argument. You can usually do this by dragging the iso onto the terminal window after the path to the script, and a space. (and selecting paste text if needed)
it will give you a shell running as a test user account, where you can run the command westonnestedxwaylandcaller. The password for this user account is no password
It requires xterm,unionfs-fuse,squashfs-tools, dialog and zenity to be installed, all of which the script tries to install automatically with packagekit. If packagekit is uninstalled, you will need to install pkcon

 
How to use Wayland:
    
    Wayland now starts automatically as the default display server. The loginmanager display, and the users session are now all Wayland sessions

    Wayland programs are in /opt/bin. But there are also many availible from the application launcher menu, under "All Wayland Programs".

    Pressing the "I" icon in the panel (in the default Weston shell) will give you information on key bindings, and opening a terminal will instantly display instructions for more advanced usage.

TODO:

      Need Creative Commons compatible images that can actually be put into a Open Source CD.

PROBLEMS:
      Wayland is still new, things are still a bit unstable, but "somewhat" useable.



