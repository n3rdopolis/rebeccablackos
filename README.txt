OVERVIEW:

Use the latest ISO here: http://sourceforge.net/projects/rebeccablackos/files/

This is inspired by Linux distributions of the same theme (Hannah Montana Linux, and Justin Beiber Linux) that have appeared in the Linux community, only this is Rebecca Black Linux. 

There are many native Wayland toolkits and libraries installed, QT, KDE Frameworks 5, GTK, EFL, Clutter and SDL has been compiled on this CD to support Wayland as well as mpv, and gstreamer. There are a few applications that don't work, but many more are starting to work.

Xwayland is also included, which allows X applications to run under a Wayland server. Xwayland has a few issues, but is usable.

There are also other Wayland Desktop environments installed: Orbital, and Hawaii, and three non Weston Wayland servers: Enlightenment, swc, and Gnome Shell Wayland, aside from the default Weston shell.

This distribution is fan made. Yes. I am a fan of Rebecca Black.


How to use the ISO:
  Burn it, (or put it in a VM), reboot, set the BIOS to boot from the CD if it does not already, boot from the CD. Once it boots you can use the live system. 

  The ISO is built with Remastersys, which makes it compatible with unetbootin, and the USB Startup creator. It is also a hybrid ISO, so it can boot raw from a flash drive.

You could also use the test_RBOS_ISO.sh to test weston on the iso without a reboot. Put the .iso into your home folder, make the test_RBOS_ISO script executable, and run the script from a terminal, and pass the path to the ISO file as an argument. You can usually do this by dragging the iso onto the terminal window after the path to the script, and a space. (and selecting paste text if needed)
it will give you a shell running as a test user account, where you can run the command westonnestedxwaylandcaller. The password for this user account is no password
It requires unionfs-fuse,squashfs-tools, dialog and zenity to be installed, all of which the script tries to install automatically by trying to figure out your distro's package manager. It also needs either konsole, gnome-terminal OR xterm. If none of these are installed, it tries to install Xterm. 
 
How to use Wayland:
    
    Wayland now starts automatically as the default display server. The loginmanager display, and the users session are now all Wayland sessions

    Wayland programs are in /opt/bin. But there are also many availible from the application launcher menu, under "All Wayland Programs".

    Pressing the "I" icon in the panel (in the default Weston shell) will give you information on key bindings, and opening a terminal will instantly display instructions for more advanced usage.

TODO:

      Need Creative Commons compatible images that can actually be put into a Open Source CD.

PROBLEMS:
      Wayland is still new, things are still a bit unstable, but "somewhat" useable.

      The distribution is now using systemd v212 as its init system, replacing Ubuntu's upstart/systemd v204 hybrid. As the first tier packages are still built around the assumption that upstart is the default init system, there might be breakerage.

BUILDING: 
     Building your own ISO is simple. Simply download the SVN by ensuring subversion is installed, and running the command:
          svn co https://rebeccablackos.svn.sourceforge.net/svnroot/rebeccablackos
     run the rebeccablacklinux_builder.sh, and then select the build architechture to run. The build process only works on Linux computers, but should work on most distros. A full build from scratch may take about a day depending on your hardware, and may take several GB. If nothing is selected to be rebuilt on the second build attempt, it may take less than an hour depending on your hardware.

     If you need to select specific revisions of the packages, copy RebeccaBlackLinux_Revisions_(architechture).txt into ~/RBOS_Build_Files . Ensure that the file is official, and not tampered with, as it is *executed* by the build scripts to set the revision. Only revision files built by SVN commit 2954 are fully compatible.


     CONTROL FILES (relative to ~/RBOS_Build_Files):
        DontDownloadDebootstrapScript: Delete this file to force the downloaded debootstrap in RBOS_Build_Files to run again at the next build
        DontRestartArchives(architechture): Delete this file to force all the downloaded packages to be downloaded again for the respective architechture.
        DontRestartPhase1(architechture): Delete this file to force Phase1 to debootstrap again for the respective architechture. This only hosts the smaller chroot system that downloads everything
        DontRestartPhase2(architechture): Delete this file to force Phase2 to debootstrap again for the respective architechture. This is the chroot that gets copied to Phase3, and is on the output ISO files.
        DontRestartBuildoutput(architechture): Delete this file to force all deb packages to rebuild for the respective architechture. This will increase the build time.
        DontStartFromScratch(architechture): Delete this file to force delete everything included downloaded repositories for the respective architechture, and cause it to start from scratch.
        build/(architechture)/buildoutput/control/(packagename): Delete these files to specify a specific package to rebuild.
