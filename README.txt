OVERVIEW:

Use the latest ISO here: http://sourceforge.net/projects/rebeccablackos/files/

This is inspired by Linux distributions of the same theme (Hannah Montana Linux, and Justin Beiber Linux) that have appeared in the Linux community, only this is Rebecca Black Linux. 

This has both Wayland and X. Even though QT, KDE Frameworks 5, GTK, EFL, Clutter and SDL has been compiled on this CD to support Wayland, under these toolkits, some apps don't work.

However Xwayland is also built into the CD which provides a way for X apps to run in Wayland, where many DO work, with a many more quirks then the native toolkit applications.

This distribution is fan made. Yes. I am a fan of Rebecca Black.


How to use the ISO:
  burn it, (or put it in a VM), reboot, set the BIOS to boot from the CD if it does not already, 
  boot from the CD. Once it boots you can use the live system. 

You could also use the test_RBOS_ISO.sh to test weston on the iso without a reboot. Put the .iso into your home folder, make the test_RBOS_ISO script executable, and run the script from a terminal, and pass the path to the ISO file as an argument. You can usually do this by dragging the iso onto the terminal window after the path to the script, and a space. (and selecting paste text if needed)
it will give you a shell running as a test user account, where you can run the command westoncaller. The password for this user account is no password
It requires xterm,unionfs-fuse,squashfs-tools, dialog and zenity to be installed, all of which the script tries to install automatically with packagekit

 
How to use Wayland:
    
    Wayland now starts automatically as the default display server. The loginmanager display, and the users session are now both Wayland sessions

    Wayland programs are in /opt/bin or the panel at the top, or in the application selector popup that you can call up under Wayland with the dropper icon in the panel.
    Xwayland apps will be availible from the menu provided by hitting the KDE icon on the panel.

    Pressing the "I" icon in the panel will give you information on key bindings, and opening a terminal will instantly display instructions for more advanced usage.

TODO:

      Need Creative Commons compatible images that can actually be put into a Open Source CD.

PROBLEMS:
      Wayland is still new, things are still a bit unstable, but "somewhat" useable.



