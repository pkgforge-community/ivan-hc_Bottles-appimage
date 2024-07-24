This repository creates and distributes the unofficial Appimage of [Bottles](https://usebottles.com/).

![Istantanea_2024-02-28_14-48-48 png](https://github.com/Portable-Linux-Apps/Portable-Linux-Apps.github.io/assets/88724353/b710774a-b412-439d-a90c-db576db3ce12)

---------------------------------
# INDEX

[Disclaim](#disclaim)

[Motivation](#motivation)

[Construction method](#construction-method)

[Build Bottles using Conty](#build-bottles-using-conty)

[Why Conty?](#why-conty)

[Why Conty into an AppImage?](#why-conty-into-an-appimage)

[Download](#download)

[Previous alternative methods](#previous-alternative-methods)

[Troubleshot](#troubleshot)

[Credits](#credits)

[Install and update it with ease](#install-and-update-it-with-ease)

---------------------------------
## Disclaim
The official Bottles package is only available as a Flatpak.

All build methods are based on the unofficial AUR package, at https://aur.archlinux.org/packages/bottles

**Any complaints are due to this mental closure only!**

As a packager I can only go by what I upstream or unofficial developers gave to me.

---------------------------------

## Motivation
Developers and packagers are two completely opposite categories:
- the developer creates the program
- the packager bundles and distributes it (as deb, rpm, flatpak, snap, appimage...) for the platform of competence.

The developer certainly has an interest in seeing his application work everywhere, so if a package works or not on a platform, it is the responsibility of the packager to make it compatible.

The biggest obstacle in the Bottles project are some collaborators who, in order to support Flatpak as the only packaging format, give a firm NO to every request or proposal to use an alternative packaging format. Having met some of these arrogant people has served as an incentive to continue doing the opposite of what they said.

I thank the developer of Bottles, @mirkobrombin, for helping me build the AppImage after many attempts by telling me tips and tricks. Grazie Mirko!

---------------------------------

## Construction method
I have tried many times to allow non-Flatpak users to use Bottles in an alternative way, and not without difficulty.

At this time, the only method that works with certainty is via [Conty](https://github.com/Kron4ek/Conty).

Currently, the AppImage I produced contains the following structure:
```
|---- AppRun
|---- com.usebottles.bottles.desktop
|---- com.usebottles.bottles.svg
|---- conty.sh
```
1. The AppRun is the core script of the AppImage
2. The .desktop file of Bottles
3. The icon of Bottles
4. The Arch Linux container named "conty.sh", it contains Bottles, WINE and grafic drivers

Points 1, 2 and 3 are the essential elements of any AppImage.

The script "conty.sh" (4) is the big one among the elements of this AppImage.

---------------------------------

## Build Bottles using Conty
This is what each file of my workflow is ment for:
1. [create-arch-bootstrap.sh](https://github.com/ivan-hc/Bottles-appimage/blob/main/create-arch-bootstrap.sh) creates an Arch Linux chroot, where Bottles is installed from AUR. This is the first script to be used ("root" required);
2. [create-conty.sh](https://github.com/ivan-hc/Bottles-appimage/blob/main/create-conty.sh) is the second script used in this process, it converts the Arch Linux chroot created by "create-arch-bootstrap.sh" into a big script named "conty.sh", that includes "conty-start.sh";
3. [conty-start.sh](https://github.com/ivan-hc/Bottles-appimage/blob/main/conty-start.sh) is the script responsible of startup inizialization processes to made Conty work. It includes a function that detects the version of the Nvidia drivers needed, if they are needed, the script downloads and installs them in ~/.local/share/Conty. Also it is responsible of full integration of Conty with the host system, using "bubblewrap;
4. [utils_dwarfs.tar.gz](https://github.com/ivan-hc/Bottles-appimage/blob/main/utils_dwarfs.tar.gz) contains "dwarfs", a set of tools similar to squashfs to compress filesystems, and it is needed to compress "conty.sh" as much as possible;
5. [bottles-conty-builder.sh](https://github.com/ivan-hc/Bottles-appimage/blob/main/bottles-conty-builder.sh) is a script i wrote to pundle "conty.sh" near the AppRun, the .desktop file and the icon to convert everything into an AppImage. It is ment to be used in github actions, but can be executed locally to build create the AppImage using a testing release of "conty.sh" from [my fork](https://github.com/ivan-hc/Conty) of Conty.

Files 1, 2, 3 and 4 come from my fork of https://github.com/Kron4ek/Conty

Files 1, 2 and 3 are a mod of the original ones to made them smaller and with only what its needed to made Bottles work.

To learn more about "Conty", to download more complete builds or to learn more on how to create your own, visit the official repository of the project:

https://github.com/Kron4ek/Conty
--------------

---------------------------------

## Why Conty?
Conty is a portable Arch Linux container with its own resources.

Its the only solution that installs its own copy of Nvidia drivers, if not available in the container itself (see picture below).

![running conty](https://github.com/user-attachments/assets/5038abc2-36c3-4891-ab0a-6da012b7b240)

The drivers are installed in the ~/.local/share/Conty directory and can take up to 700 MB of space.

Considering that Bottles, at first start, downloading the necessary libraries and creating profiles for WINE, reaches about 1.4 GB of space in ~/.local/share/bottles, I would say that the size is more than acceptable.

![disk usage](https://github.com/user-attachments/assets/73ccd625-9731-408e-ac7d-30f76fa81d55)

It's a bit like installing a Flatpak runtime. But only one. The rest of the files are stored in Conty itself.

---------------------------------

## Why Conty into an AppImage?
Wrapping Conty into an AppImage allows it to be isolated (via bubblewrap sandbox) using my package manager "[AM](https://github.com/ivan-hc/AM)".

![running conty-based AppImage](https://github.com/user-attachments/assets/d86c3b9a-b7a3-4b5a-8229-f95fa186c9be)

This AppImage is a new generation one (Type3 AppImage), so you don't need `libfuse2` installed on your system to use it.

---------------------------------

## Download
You can download the AppImage from https://github.com/ivan-hc/Bottles-appimage/releases/tag/continuous

---------------------------------

## Previous alternative methods
Having few resources available is what pushed me to proceed by trial and error, more or less effective, within the limits of my possibilities.

The use of Conty is only the latest in a long series.

Old building scripts are available in the directories of this repository:
- "[legacy](https://github.com/ivan-hc/Bottles-appimage/tree/main/legacy)" contains experimental scripts to build the AppImage on top of JuNest, but it lack of hardware accelleration see https://github.com/ivan-hc/ArchImage/issues/20
- "[hybrid](https://github.com/ivan-hc/Bottles-appimage/tree/main/hybrid)" was the one that worked thanks to a mix between my two projects [AppImaGen](https://github.com/ivan-hc/AppImaGen) and [ArchImage](https://github.com/ivan-hc/ArchImage), a mix of Arch Linux and Debian packages. It worked only for newer distros and until newer changes into an assential Arch Linux package (python) that was not good to keep maintain this method. Its still possible to download the only available release son of this method, at https://github.com/ivan-hc/Bottles-appimage/releases/tag/51.11-2

Given the "troubled" history of this repository, I don't know if Conty is the ultimate solution for my workflow. It all depends on the packages that are made available to me by upstream developers or third parties.

---------------------------------

## Troubleshot

### ◆ Very slow first startup
At the first start, if necessary, the drivers for your video card will be downloaded, via Conty (see screenshot above). This may take several seconds or even minutes. This behaviour will only be noticed if when you first start it, you launch Bottles from the terminal instead of using the launcher.

---------------------------------

## Credits

- @mirkobrombin for all the patience and availability shown to me
- Conty https://github.com/Kron4ek/Conty

---------------------------------

## Install and update it with ease

I wrote two bash scripts to install and manage the applications: [AM](https://github.com/ivan-hc/AM) and [AppMan](https://github.com/ivan-hc/AppMan). Their dual existence is based on the needs of the end user.

| [**"AM" Application Manager**](https://github.com/ivan-hc/AM) |
| -- |
| <sub>***If you want to install system-wide applications on your GNU/Linux distribution in a way that is compatible with [Linux Standard Base](https://refspecs.linuxfoundation.org/lsb.shtml) (all third-party apps must be installed in dedicated directories under `/opt` and their launchers and binaries in `/usr/local/*` ...), just use ["AM" Application Manager](https://github.com/ivan-hc/AM). This app manager requires root privileges only to install / remove applications, the main advantage of this type of installation is that the same applications will be available to all users of the system.***</sub>
[![Readme](https://img.shields.io/github/stars/ivan-hc/AM?label=%E2%AD%90&style=for-the-badge)](https://github.com/ivan-hc/AM/stargazers) [![Readme](https://img.shields.io/github/license/ivan-hc/AM?label=&style=for-the-badge)](https://github.com/ivan-hc/AM/blob/main/LICENSE)

| [**"AppMan"**](https://github.com/ivan-hc/AppMan)
| --
| <sub>***If you don't want to put your app manager in a specific path but want to use it portable and want to install / update / manage all your apps locally, download ["AppMan"](https://github.com/ivan-hc/AppMan) instead. With this script you will be able to decide where to install your applications (at the expense of a greater consumption of resources if the system is used by more users). AppMan is portable, all you have to do is write the name of a folder in your `$HOME` where you can install all the applications available in [the "AM" database](https://github.com/ivan-hc/AM-Application-Manager/tree/main/programs), and without root privileges.***</sub>
[![Readme](https://img.shields.io/github/stars/ivan-hc/AppMan?label=%E2%AD%90&style=for-the-badge)](https://github.com/ivan-hc/AppMan/stargazers) [![Readme](https://img.shields.io/github/license/ivan-hc/AppMan?label=&style=for-the-badge)](https://github.com/ivan-hc/AppMan/blob/main/LICENSE)
