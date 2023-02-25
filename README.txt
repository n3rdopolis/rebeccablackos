LICENSE:
  The build script are all under GPL v2+, except for were stated, namely in code in patches under rebeccablacklinux/rebeccablackos_files/usr/share/RBOS_PATCHES
  or imported and modified files in rebeccablacklinux/rebeccablackos_files/usr/share/RBOS_PATCHES/ Some diffs are for software that is under a different Open 
  Source license, for example Calamares is GPLv3
  
  The Desktop wallpaper (other then the logo) is from https://store.kde.org/content/show.php/Into+Flames+%281920x1200%29?content=52726 by 'Janet' on KDE-look,
  this was documented in the commit message for commit #1985, but the file was moved, and git-svn (or git) doesn't retain the logs of moved files, on the git
  mirror

OVERVIEW:
  Use the latest ISO here: http://sourceforge.net/projects/rebeccablackos/files/

  This is inspired by Linux distributions of the same theme (Hannah Montana Linux, and Justin Beiber Linux) that have appeared in the Linux community, only
  this is RebeccaBlackOS. This KDE blog post from 2011 also inspired the idea. http://ivan.fomentgroup.org/blog/2011/05/02/splash-screens-and-qml/

  There are many native Wayland toolkits and libraries installed, Qt, GTK, EFL, Clutter and SDL has been compiled to support Wayland.

  Xwayland is also included, which allows X applications to run.

  There are also other Wayland Desktop environments that are usable: Liri, Enlightenment, and Gnome Shell Wayland, Kwin, Wayfire, and Sway, aside from the
  default Weston Desktop shell.

  This distribution is fan made. Yes. I am a fan of Rebecca Black.

  It is based on Debian Bookworm for Tier 1 packages.


How to use the ISO:
  Burn the ISO, (or set it to be "in" the CD ROM device in your favorite VM software), reboot, set the BIOS to boot from the DVD if it does not already, boot
  from the DVD. Once it boots you can use the live system.

  The ISOs are also hybrid ISOs, meaning they can also be written directly to a flash drive, to be bootable without using slower optical media.

  The live user "rebestie" has no password.

  The ISO is built with Remastersys, and has Casper, which makes it compatible with the USB Startup creator, despite being based off of Debian. Unetbootin will
  also work. Note that Unetbootin is not recommened if your target computer needs SimpleDRM, as it uses syslinux instead of Grub which does not properly
  allow SimpleDRM to work correctly. (See "CHANGING THE RESOLUTION ON SIMPLE HARDWARE" section for more details)

  You could also use the test_RBOS_ISO.sh to try software on the ISO without a reboot or a VM. This is more recommened for advanced users, as it is not *fully*
  isolated. To use, Download the ISO, and download and make the test_RBOS_ISO.sh script executable, and run the script. It can be run from a terminal, or from
  your file manager.

    It is only recommened for expert users now. Before, it was beneficial to demonstrate sessions that could run nested, and struggled to run on VMs (before
    generic modesetting, as well as before EGL software rendering worked as well as it does now)
  
    It will give you a shell running with your UID, sudo works in the nested environment, and the password wil be the same as your password, rather than
    setting a weaker, or known default. (it reads the host /etc/shadow to put the same line in the nested /etc/shadow) 

    It requires squashfs, and also needs dialog or zenity or kdialog to be installed, and it also needs either konsole, gnome-terminal OR a standard
    x-terminal-emulator.

    Warning: It is not as isolated as a VM. While there are some separations to act as a play sandbox, it's NOT to be treated as a security sandbox.
 
How to use Wayland:
    The loginmanagerdisplay greeter is Weston based.

    The LiveCD is configured to auto-login. The choices presented are the desired session type to start as the default user. All selectable sessions are
    Wayland based.

    Most UI programs use their toolkit's Wayland backend, (unless they are started with the xwaylandapp utility)

PROBLEMS:
      A few files outside of /opt in packages may conflict with the files provided by main Debian archives. The number of files that get overwritten is
      small. If an installed system can't be updated due to this, use the rbos-enable-dpkg-overwrites command for a wizard to
      enable dpkg overwrites.

      Enlightenment in wizard mode sometimes doesn't show the cursor. This is apparently random.

BOOT OPTIONS:
      The WaylandLoginManager responds when particular strings are passed to the kernel command line. These options are made available by the live CD boot menu,
      or on an installed system by running the command rbos-failedboot as root. (Which is automatically called when the login manager's display server crashes
      5 times.)
            wlmforceswrender :          Force all user sessions, and the WaylandLoginManager's display to be started with the environment variable
                                        LIBGL_ALWAYS_SOFTWARE=1 to force software rendering. This also forces the WaylandLoginManager to export session-specific
                                        variables for software rendering, if the wsession desktop file specifies such variables.

            wlmforcepixman :            Force the WaylandLoginManager's display, and the hosts for any fullscreen or kiosk shell supporing session to use the
                                        pixman renderer. Use this if there is a problem with Mesa's software renderer.

            wlmforcefbdev :             [Legacy option] Force the WaylandLoginManager to handle the system as if though it does not support kernel mode
                                        setting, even if kernel mode setting is available.

            wlmnofbdev :                [Legacy option] Force the WaylandLoginManager to handle the system as if though it does not support framebuffer, even
                                        if framebuffers are available. (Recent versions of Weston dropped the framebuffer backend. This is redundant now.)

            wlmdebug :                  [Legacy option] Forces more sysrq trigger options to be available.

            wlmdebuginsecure :          This option is the same as wlmdebug, and allows a root diagnostic terminal to be started.


       These relevant options are also handled, (but not by the WaylandLoginManager itself)
            vttydisable :               This option turns off the minimal display server used for logging into TTYs, and falls back to legacy gettys

            init=/sbin/recinit :        Instead of using init=/bin/bash as an emergency recovery console, this starts a prompt under a user mode terminal.

            nomodeset :                 This option is handled by the kernel. It may be slightly misleading in name, but it prevents other drivers from
                                        taking over SimpleDRM, leaving SimpleDRM as the current graphics driver. Use this if the graphics driver misbehaves,
                                        and fails to create any graphical devices.


      This option is handled early in initramfs:
            norecinit=1                 This forces the initramfs recovery prompt to fall back to the system console, and not use the user mode terminal.


      These utilities assit with changing boot options:
            rbos-force-softwarerendering:  Wizard for configuring the bootloader wlmforceswrender option to the kernel command line

            rbos-force-softwarerendering:  Wizard for configuring the bootloader to add or remove `nomodeset to the kernel command line to force or unforce
                                           using the fallback (SimpleDRM) driver.

            rbos-configure-simplegraphics: Wizard for configuring the bootloader frambuffer size for hardware that requires SimpleDRM (see CHANGING THE
            RESOLUTION ON SIMPLE HARDWARE)


CHANGING THE RESOLUTION ON SIMPLE HARDWARE:
      Not every video card has its own driver that supports Kernel Mode Setting. VirtualBox did not (until recently), and the emulated 'vmware' device in QEMU
      VMs does not work quite right with the vmwgfx driver. Before simpledrm, hardware without proper modesetting support required framebuffer support.  While
      possible, there was the problem that wayland based display servers that have framebuffer backends are rare. The

      The *bootloader* is where the video memory for this driver is prepared, before the kernel starts. Grub tries its best to detect your resolution, with one
      that is supported by both your BIOS and your monitor. However, the resolution can be customized, especially on VMs which may tend to default to a smaller
      screen size.

      For Live CD mode, in the boot menu, hit the 'e' key. and set SetCustomResolution to 1 (from 0) and then change the set gfxmode= line to your desired
      resolution, and hit "CTRL+X"

      For installed, a utility, rbos-configure-simplegraphics is provided.

BUILDING: 
     Building your own ISO is simple. Simply download the SVN by ensuring subversion is installed, and running the command:
          svn checkout svn://svn.code.sf.net/p/rebeccablackos/code/
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
        DontRestartRustDownload(architechture):                  Delete this file to force build_core to redownload Rust
        DontStartFromScratch(architechture):                     Delete this file to force delete everything included downloaded repositories for the
                                                                 respective architechture, and cause it to start from scratch.
        DontRestartCargoDownload(architechture):                 Clear the Cargo cache
        DontRestartRustDownload(architechture):                  Force build_core to download a new build of Rust
        build/(architechture)/buildoutput/control/(packagename): Delete these files to specify a specific package to rebuild.
        buildcore_revisions_(architechture).txt:                 Add a revisions file into this path, to specify particular packages, as described above
        RestartPackageList_(architechture).txt:                  Add in the list of packages (as in the files in build/(architechture)/buildoutput/control/ ).
                                                                 One per each line. For batch resetting particular packages
        DontForceSnapshotBuild(architechture):                   Delete this file only after the first run is complete, before the next build. This forces
                                                                 temporary chroots to be built
