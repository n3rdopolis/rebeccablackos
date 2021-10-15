LICENSE:
  The build script are all under GPL v2+, except for were stated, namely in code in patches under rebeccablacklinux/rebeccablackos_files/usr/share/RBOS_PATCHES
  or imported and modified files in rebeccablacklinux/rebeccablackos_files/usr/share/RBOS_PATCHES/ or rebeccablacklinux/rebeccablackos_files/usr/import/
  Some diffs are for software that is under a different Open Source license, for example Calamares is GPLv3
  
  The Desktop wallpaper (other then the logo) is from https://store.kde.org/content/show.php/Into+Flames+%281920x1200%29?content=52726 by 'Janet' on KDE-look,
  this was documented in the commit message for commit #1985, but the file was moved, and git-svn (or git) doesn't retain the logs of moved files, on the git
  mirror

OVERVIEW:
  Use the latest ISO here: http://sourceforge.net/projects/rebeccablackos/files/

  This is inspired by Linux distributions of the same theme (Hannah Montana Linux, and Justin Beiber Linux) that have appeared in the Linux community, only
  this is RebeccaBlackOS. This KDE blog post from 2011 also inspired the idea. http://ivan.fomentgroup.org/blog/2011/05/02/splash-screens-and-qml/

  There are many native Wayland toolkits and libraries installed, QT, KDE Frameworks 5, GTK, EFL, Clutter and SDL has been compiled on this CD to support
  Wayland as well as mpv, and gstreamer.

  Xwayland is also included, which allows X applications to run under a Wayland server.

  There are also other Wayland Desktop environments that are usable: Liri, Enlightenment, and Gnome Shell Wayland, Kwin, and Sway aside from the default Weston
  Desktop shell.

  This distribution is fan made. Yes. I am a fan of Rebecca Black.

  It is based on Debian Bullseye for Tier 1 packages.


How to use the ISO:
  Burn it, (or put it in a VM), reboot, set the BIOS to boot from the CD if it does not already, boot from the CD. Once it boots you can use the live system.

  The live user "rebestie" has no password

  The ISO is built with Remastersys, which makes it compatible with the USB Startup creator. It is also a hybrid ISO, so it can boot raw from a flash drive,
  where the ISO has been written with dd. Unetbootin will also work, but is not as recommended as it uses syslinux with its own defaults, and no splash.

  You could also use the test_RBOS_ISO.sh to test weston on the iso without a reboot. Put the .iso into your home folder, make the test_RBOS_ISO script
  executable, and run the script from a terminal, and pass the path to the ISO file as an argument. You can usually do this by dragging the iso onto the
  terminal window after the path to the script, and a space. (and selecting paste text if needed)
  
    It will give you a shell running with your UID, the password wil be the same as your password, but within the hosted system.

    It requires squashfs, and also needs dialog or zenity to be installed, and it also needs either konsole, gnome-terminal OR a standard x-terminal-emulator.
 
How to use Wayland:
    The loginmanagerdisplay greeter is weston based, where you can select your desired wayland based desktop.

    Wayland programs are in /opt/bin. But there are also many availible from the application launcher menu, under "All Wayland Programs".

    Pressing the "I" icon in the panel (in the default Weston shell) will give you information on key bindings, and opening a terminal will instantly display
    instructions for more advanced usage.

PROBLEMS:
      A few files outside of /opt get written that may conflict with the files provided by main Debian archives. The number of files that get overwritten is
      small, and mostly just header files. If an installed system can't be updated due to this, use the rbos-enable-dpkg-overwrites command for a wizard to
      enable dpkg overwrites.

      When virtualized, under QEMU, be sure to use either KVM32 or KVM64 as the 'emulated' processor. It appears to be caused by specifying an emulated
      processor that reports capabilities that the host processor doesn't have, and causes failures. Selecting an emulated processor that reports CPU
      capabilities that it doesn't have. This affects even the upstream install of Mesa, and not just the newer one provided in /opt.

      Especially when virtualized, programs may hang on startup. This is due to a recent fix in the Linux Kernel that makes getrandom() block, until there is
      enough "randomness", provided by hardware sources. On hardware that is not as complex, (like a VM) there is not enough hardware providing this
      "randomness", so some programs that rely on getrandom() will hang. One workaround is to randomly mash the keyboard for a few seconds, as keyboards are
      among devices used.

BOOT OPTIONS:
      The WaylandLoginManager responds when paticular strings are passed to the kernel command line. These options are made availible by the live CD boot menu,
      or on an installed system by running the command rbos-failedboot as root. (Which is automatically called when the login manager's display server crashes
      5 times.)
            wlmforceswrender:           Force all user sessions, and the Login Manager's display to be started with the environment variable
                                        LIBGL_ALWAYS_SOFTWARE=1 to force software rendering

            wlmforcepixman:             Force the Login Manager's display, and the hosts for any fullscreen or kiosk shell supporing session to use Pixman

            wlmforcefbdev:              Force the WaylandLoginManager to handle the system as if though it does not support kernel mode setting, even if kernel
                                        mode setting is availible.

            wlmnofbdev:                 Force the WaylandLoginManager to handle the system as if though it does not support framebuffer, even if framebuffers
                                        are availible.

            wlmdebug:                   Force more sysrq trigger options to be availible, then the more secure default. This option is not settable from
                                        rbos-failedboot as it's for more advanced users

            wlmdebuginsecure:           This option is the same as wlmdebug, and allows a root diagnostic terminal to be started.

       This option is also handled, (but not by the WaylandLoginManager itself)
            vttydisable:                This option turns off the minimal display server used for logging into TTYs, and falls back to legacy gettys

       This option is handled early in initramfs:
            simplekms.forceload:        This forces the simplekmsdriver to be loaded, even if there is an existing /dev/dri/card0 device.
                                        This option is only applicable for hardware with multiple video cards, where the primary video card
                                        does not have support by a Linux modesetting driver, and generic modesetting support is needed.
                                        the driver gtes loaded if there are no supported video cards by default, but a secondary one will,
                                        without this option, be detected as the 'primary'.

      When installed, and you are unable to use a UI, you can use the commands:
            rbos-force-softwarerendering: Wizard for setting wlmforceswrender option to the kernel commandline with grub

CHANGING THE RESOLUTION ON SIMPLE HARDWARE:
      Not every video card has its own driver that supports Kernel Mode Setting. VirtualBox did not until recently, and the emulated 'vmware' device in QEMU
      VMs would not have mode setting support. With this hardware, you would get at most a framebuffer device. However the bootloader also has to initialize
      a framebuffer for the kernel.

      A kernel mode setting driver, simplekms has been cherry-picked and is built. This allows mode setting on many more platforms that would only support
      framebuffers, which means that even mode setting only Wayland desktops can run on these devices (with software rendering). Pending the 
      simplekms/simpledrm driver actually being merged into the mainline kernel, many of the fallbacks, such as using framebuffer backends, using Weston hosts
      to nest sessions, and the custom framebuffer permissons could soon start to become not as favored.

      What sets the resolution for this is not the kernel, but the bootloader. To ensure maximum support, it attempts 1024x768, and then 800x600 then 640x480
      It is possible to change this if you want to attempt a higher resolution.

      For Live CD mode, in the boot menu, hit the 'e' key. and set SetCustomResolution to 1 (from 0) and then change the set gfxmode= line to your desired
      resolution, and hit "CTRL+X"

      For installed, a utility, rbos-configure-simplegraphics is provided.

BUILDING: 
     Building your own ISO is simple. Simply download the SVN by ensuring subversion is installed, and running the command:
          svn co svn://svn.code.sf.net/p/rebeccablackos/code/
     run the rebeccablackos_builder.sh, and then select the build architechture to run. The build process only works on Linux computers, but should work on
     most distros. A full build from scratch may take several hours to about a day depending on your hardware, and may take several GB. If nothing is selected
     to be rebuilt on the second build attempt, it may take less than an hour depending on your hardware.

     If you need to select specific revisions of the packages, copy buildcore_revisions_(architechture).txt into /var/cache/RBOS_Build_Files . Ensure that the file
     is official, and not tampered with, as it is *executed* by the build scripts to set the revision. Only revision files built by SVN commit 3418 are fully
     compatible for the packages. Revisions files can also specify a snapshot date for the underlying Debian packages, but only since commit 5555.
     Commit 6413 corrected a bash 5.0 quirk in how the function-name safe names were handled.

     CONTROL FILES (relative to /var/cache/RBOS_Build_Files):
        DontDownloadDebootstrapScript:                           Delete this file to force the downloaded debootstrap in RBOS_Build_Files to run again at the
                                                                 next build
        DontRestartArchives(architechture):                      Delete this file to force all the downloaded packages to be downloaded again for the 
                                                                 respective architechture.
        DontRestartSourceDownload(architechture):                Delete this file to force all the downloaded source repositories to be downloaded again for
                                                                 the respective architechture.
        DontRestartPhase1(architechture):                        Delete this file to force Phase1 to debootstrap again for the respective architechture. This
                                                                 only hosts the smaller chroot system that downloads everything
        DontRestartPhase2(architechture):                        Delete this file to force Phase2 to debootstrap again for the respective architechture. This
                                                                 is the chroot that gets copied to Phase3, and is on the output ISO files.
        DontRestartBuildoutput(architechture):                   Delete this file to force all deb packages to rebuild for the respective architechture. This
                                                                 will increase the build time.
        DontStartFromScratch(architechture):                     Delete this file to force delete everything included downloaded repositories for the
                                                                 respective architechture, and cause it to start from scratch.
        DontRestartCargoDownload(architechture):                 Force build_core to download of a new cargo nightly binary build.
        build/(architechture)/buildoutput/control/(packagename): Delete these files to specify a specific package to rebuild.
        buildcore_revisions_(architechture).txt:                 Add a revisions file into this path, to specify paticular packages, as described above
        RestartPackageList_(architechture).txt:                  Add in the list of packages (as in the files in build/(architechture)/buildoutput/control/ ).
                                                                 One per each line. For batch resetting paticular packages
        DontForceSnapshotBuild(architechture):                   Delete this file only after the first run is complete, before the next build. This forces
                                                                 temporary chroots to be built
