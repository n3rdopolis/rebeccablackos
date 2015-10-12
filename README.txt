LICENSE:
  The build script are all under GPL v2, except for were stated, namely in code in patches under rebeccablacklinux/rebeccablackos_files/usr/share/RBOS_PATCHES/ or imported and modified files in rebeccablacklinux/rebeccablackos_files/usr/share/RBOS_PATCHES/ or rebeccablacklinux/rebeccablackos_files/usr/import/ 
  Some diffs are for software that is under a different Open Source license, for example Calamares is GPLv3

OVERVIEW:
  Use the latest ISO here: http://sourceforge.net/projects/rebeccablackos/files/

  This is inspired by Linux distributions of the same theme (Hannah Montana Linux, and Justin Beiber Linux) that have appeared in the Linux community, only this is RebeccaBlackOS. 

  There are many native Wayland toolkits and libraries installed, QT, KDE Frameworks 5, GTK, EFL, Clutter and SDL has been compiled on this CD to support Wayland as well as mpv, and gstreamer. There are a few applications that don't work, but many more are starting to work.

  Xwayland is also included, which allows X applications to run under a Wayland server. Xwayland is very usable except for a few bugs.

  There are also other Wayland Desktop environments installed: Orbital, Hawaii, Enlightenment, Orbment, and Gnome Shell Wayland, Kwin, and Papyros aside from the default Weston shell.

  This distribution is fan made. Yes. I am a fan of Rebecca Black.


How to use the ISO:
  Burn it, (or put it in a VM), reboot, set the BIOS to boot from the CD if it does not already, boot from the CD. Once it boots you can use the live system. 

  The ISO is built with Remastersys, which makes it compatible with unetbootin, and the USB Startup creator. It is also a hybrid ISO, so it can boot raw from a flash drive.

  You could also use the test_RBOS_ISO.sh to test weston on the iso without a reboot. Put the .iso into your home folder, make the test_RBOS_ISO script executable, and run the script from a terminal, and pass the path to the ISO file as an argument. You can usually do this by dragging the iso onto the terminal window after the path to the script, and a space. (and selecting paste text if needed)
  
    It will give you a shell running as a test user account, where you can run the command westonnestedxwaylandcaller. The password for this user account is no password

    It requires unionfs-fuse,squashfs-tools, dialog and zenity to be installed, all of which the script tries to install automatically by trying to figure out your distro's package manager. It also needs either konsole, gnome-terminal OR xterm. If none of these are installed, it tries to install Xterm. 
 
How to use Wayland:
    Weston now starts automatically as the default display server. The loginmanager display, and the users session are now all Wayland sessions

    Wayland programs are in /opt/bin. But there are also many availible from the application launcher menu, under "All Wayland Programs".

    Pressing the "I" icon in the panel (in the default Weston shell) will give you information on key bindings, and opening a terminal will instantly display instructions for more advanced usage.

TODO:
      Need Creative Commons compatible images that can actually be put into a Open Source CD.

PROBLEMS:
      A few files outside of /opt get written that may conflict with the files provided by main Debian archives. The number of files that get overwritten is small, and mostly just header files. If an installed system can't be updated due to this, use the rbos-enable-dpkg-overwrites command for a wizard to enable dpkg overwrites.

      When virtualized, under QEMU, be sure to use either KVM32 or KVM64 as the 'emulated' processor. It appears to be caused by specifying an emulated processor that reports capabilities that the host processor doesn't have, and causes failures. Selecting an emulated processor that reports CPU capabilities that it doesn't have. This affects even the upstream install of Mesa, and not just the newer one provided in /opt.

BOOT OPTIONS:
      The WaylandLoginManager responds when paticular strings are passed to the kernel command line. These options are made availible by the live CD boot menu, or on an installed system by running the command rbos-failedboot as root. (Which is automatically called when the login manager's display server crashes 5 times.)
            wlmforcefbdev: Force the WaylandLoginManager to handle the system as if though it does not support kernel mode setting, even if kernel mode setting is availible.
            wlmforceswrender: Force all user sessions, and the Login Manager's display to be started with the environment variable LIBGL_ALWAYS_SOFTWARE=1 to force software rendering
            wlmforcevblankoff: Force all user sessions, and the Login Manager's display to be started with the environment variable vblank_mode=0 to disable vblank which might have problems on some hardware.
            wlmdebug: Force more sysrq trigger options to be availible, then the more secure default. Allow the option for a graphical login terminal to be started on the wayland login manager's display. This option is not settable from rbos-failedboot as it's for more advanced users
	    wlmdebuginsecure: This option is the same as wlmdebug, except the diagostic terminal is a root terminal, instead of a login terminal

      When installed, and you are unable to use a UI, you can use the commands:
	    rbos-force-framebuffer: Wizard for setting wlmforcefbdev option to the kernel commandline with grub
	    rbos-force-softwarerendering: Wizard for setting wlmforceswrender option to the kernel commandline with grub
	    rbos-force-vblankoff: Wizard for setting wlmforcevblankoff option to the kernel commandline with grub


BUILDING: 
     Building your own ISO is simple. Simply download the SVN by ensuring subversion is installed, and running the command:
          svn co svn://svn.code.sf.net/p/rebeccablackos/code/
     run the rebeccablackos_builder.sh, and then select the build architechture to run. The build process only works on Linux computers, but should work on most distros. A full build from scratch may take about a day depending on your hardware, and may take several GB. If nothing is selected to be rebuilt on the second build attempt, it may take less than an hour depending on your hardware.

     If you need to select specific revisions of the packages, copy RebeccaBlackOS_Revisions_(architechture).txt into ~/RBOS_Build_Files . Ensure that the file is official, and not tampered with, as it is *executed* by the build scripts to set the revision. Only revision files built by SVN commit 3418 are fully compatible.


     CONTROL FILES (relative to ~/RBOS_Build_Files):
        DontDownloadDebootstrapScript: Delete this file to force the downloaded debootstrap in RBOS_Build_Files to run again at the next build
        DontRestartArchives(architechture): Delete this file to force all the downloaded packages to be downloaded again for the respective architechture.
	DontRestartSourceDownload(architechture): Delete this file to force all the downloaded source repositories to be downloaded again for the respective architechture.
        DontRestartPhase1(architechture): Delete this file to force Phase1 to debootstrap again for the respective architechture. This only hosts the smaller chroot system that downloads everything
        DontRestartPhase2(architechture): Delete this file to force Phase2 to debootstrap again for the respective architechture. This is the chroot that gets copied to Phase3, and is on the output ISO files.
        DontRestartBuildoutput(architechture): Delete this file to force all deb packages to rebuild for the respective architechture. This will increase the build time.
        DontStartFromScratch(architechture): Delete this file to force delete everything included downloaded repositories for the respective architechture, and cause it to start from scratch.
        build/(architechture)/buildoutput/control/(packagename): Delete these files to specify a specific package to rebuild.
        build/(architechture)/buildoutput/acl_control/(packagename): Delete these files to force build_core to allow a non root service user to have permissions to the source files, so git/svn/etc doesn't need to run as root.
