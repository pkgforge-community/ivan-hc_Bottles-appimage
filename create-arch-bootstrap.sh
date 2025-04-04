#!/usr/bin/env bash

# Dependencies: curl tar gzip grep coreutils
# Root rights are required

########################################################################

# Package groups
audio_pkgs="alsa-lib lib32-alsa-lib libpulse lib32-libpulse pipewire lib32-pipewire"

wine_pkgs="lib32-giflib lib32-libpng lib32-libldap lib32-gnutls mpg123 \
	lib32-mpg123 lib32-openal lib32-v4l-utils lib32-libpulse \
	lib32-alsa-plugins lib32-alsa-lib \
	lib32-libjpeg-turbo lib32-libxcomposite \
	lib32-libxinerama lib32-libxslt lib32-libva gtk3 \
	lib32-gtk3 lib32-sdl2 lib32-vkd3d lib32-gst-plugins-good \
	lib32-gst-plugins-base"

devel_pkgs="base-devel git meson mingw-w64-gcc cmake"

# Packages to install
# You can add packages that you want and remove packages that you don't need
# Apart from packages from the official Arch repos, you can also specify
# packages from the Chaotic-AUR repo
export packagelist="${audio_pkgs} ${wine_pkgs} ${devel_pkgs} \
	xorg-xwayland gamemode lib32-gamemode wayland \
	lib32-wayland xorg-server xorg-apps which ibus libpng v4l-utils libxslt \
 	lib32-vulkan-icd-loader gnutls openal libjpeg-turbo libva sdl2 xterm"

# If you want to install AUR packages, specify them in this variable
export aur_packagelist="bottles"

# ALHP is a repository containing packages from the official Arch Linux
# repos recompiled with -O3, LTO and optimizations for modern CPUs for
# better performance
#
# When this repository is enabled, most of the packages from the official
# Arch Linux repos will be replaced with their optimized versions from ALHP
#
# Set this variable to true, if you want to enable this repository
enable_alhp_repo="false"

# Feature levels for ALHP. Available feature levels are 2 and 3
# For level 2 you need a CPU with SSE4.2 instructions
# For level 3 you need a CPU with AVX2 instructions
alhp_feature_level="2"

########################################################################

if [ $EUID != 0 ]; then
	echo "Root rights are required!"

	exit 1
fi

if ! command -v curl 1>/dev/null; then
	echo "curl is required!"
	exit 1
fi

if ! command -v gzip 1>/dev/null; then
	echo "gzip is required!"
	exit 1
fi

if ! command -v grep 1>/dev/null; then
	echo "grep is required!"
	exit 1
fi

if ! command -v sha256sum 1>/dev/null; then
	echo "sha256sum is required!"
	exit 1
fi

script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

mount_chroot () {
	# First unmount just in case
	umount -Rl "${bootstrap}"

	mount --bind "${bootstrap}" "${bootstrap}"
	mount -t proc /proc "${bootstrap}"/proc
	mount --bind /sys "${bootstrap}"/sys
	mount --make-rslave "${bootstrap}"/sys
	mount --bind /dev "${bootstrap}"/dev
	mount --bind /dev/pts "${bootstrap}"/dev/pts
	mount --bind /dev/shm "${bootstrap}"/dev/shm
	mount --make-rslave "${bootstrap}"/dev

	rm -f "${bootstrap}"/etc/resolv.conf
	cp /etc/resolv.conf "${bootstrap}"/etc/resolv.conf

	mkdir -p "${bootstrap}"/run/shm
}

unmount_chroot () {
	umount -l "${bootstrap}"
	umount "${bootstrap}"/proc
	umount "${bootstrap}"/sys
	umount "${bootstrap}"/dev/pts
	umount "${bootstrap}"/dev/shm
	umount "${bootstrap}"/dev
}

run_in_chroot () {
	if [ -n "${CHROOT_AUR}" ]; then
		chroot --userspec=aur:aur "${bootstrap}" /usr/bin/env LANG=en_US.UTF-8 TERM=xterm PATH="/bin:/sbin:/usr/bin:/usr/sbin" "$@"
	else
		chroot "${bootstrap}" /usr/bin/env LANG=en_US.UTF-8 TERM=xterm PATH="/bin:/sbin:/usr/bin:/usr/sbin" "$@"
	fi
}

install_packages () {
	echo "Checking if packages are present in the repos, please wait..."
	for p in ${packagelist}; do
		if pacman -Sp "${p}" &>/dev/null; then
			good_pkglist="${good_pkglist} ${p}"
		else
			bad_pkglist="${bad_pkglist} ${p}"
		fi
	done

	if [ -n "${bad_pkglist}" ]; then
		echo ${bad_pkglist} > /opt/bad_pkglist.txt
	fi

	for i in {1..10}; do
		if pacman --noconfirm --needed -S ${good_pkglist}; then
			good_install=1
			break
		fi
	done

	if [ -z "${good_install}" ]; then
		echo > /opt/pacman_failed.txt
	fi
}

install_aur_packages () {
	cd /home/aur

	echo "Checking if packages are present in the AUR, please wait..."
	for p in ${aur_pkgs}; do
		if ! yay -a -G "${p}" &>/dev/null; then
			bad_aur_pkglist="${bad_aur_pkglist} ${p}"
		fi
	done

	if [ -n "${bad_aur_pkglist}" ]; then
		echo ${bad_aur_pkglist} > /home/aur/bad_aur_pkglist.txt
	fi

	for i in {1..10}; do
		if yes | yay --needed --removemake --builddir /home/aur -a -S ${aur_pkgs}; then
			break
		fi
	done
}

generate_mirrorlist () {
	cat <<EOF > mirrorlist
Server = https://mirror1.sl-chat.ru/archlinux/\$repo/os/\$arch
Server = https://mirror3.sl-chat.ru/archlinux/\$repo/os/\$arch
Server = https://us.mirrors.cicku.me/archlinux/\$repo/os/\$arch
Server = https://mirror.osbeck.com/archlinux/\$repo/os/\$arch
Server = https://md.mirrors.hacktegic.com/archlinux/\$repo/os/\$arch
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://mirror.qctronics.com/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.constant.com/\$repo/os/\$arch
Server = https://america.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://mirror.tmmworkshop.com/archlinux/\$repo/os/\$arch
EOF
}

cd "${script_dir}" || exit 1

bootstrap="${script_dir}"/root.x86_64

curl -#LO 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
curl -#LO 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

if [ ! -s chaotic-keyring.pkg.tar.zst ] || [ ! -s chaotic-mirrorlist.pkg.tar.zst ]; then
	echo "Seems like Chaotic-AUR keyring or mirrorlist is currently unavailable"
	echo "Please try again later"
	exit 1
fi

bootstrap_urls=("arch.hu.fo" \
		"mirror.cyberbits.eu" \
		"mirror.osbeck.com" \
		"mirror.lcarilla.de" \
		"mirror.moson.org" \
  		"mirror.f4st.host")

echo "Downloading Arch Linux bootstrap"

for link in "${bootstrap_urls[@]}"; do
	curl -#LO "https://${link}/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
	curl -#LO "https://${link}/archlinux/iso/latest/sha256sums.txt"

	if [ -s sha256sums.txt ]; then
		grep bootstrap-x86_64 sha256sums.txt > sha256.txt

		echo "Verifying the integrity of the bootstrap"
		if sha256sum -c sha256.txt &>/dev/null; then
			bootstrap_is_good=1
			break
		fi
	fi

	echo "Download failed, trying again with different mirror"
done

if [ -z "${bootstrap_is_good}" ]; then
	echo "Bootstrap download failed or its checksum is incorrect"
	exit 1
fi

rm -rf "${bootstrap}"
tar xf archlinux-bootstrap-x86_64.tar.zst
rm archlinux-bootstrap-x86_64.tar.zst sha256sums.txt sha256.txt

mount_chroot

if command -v reflector 1>/dev/null; then
	echo "Generating mirrorlist..."
	reflector --connection-timeout 10 --download-timeout 10 --protocol https --score 10 --sort rate --save mirrorlist
	reflector_used=1
else
	generate_mirrorlist
fi

rm "${bootstrap}"/etc/pacman.d/mirrorlist
mv mirrorlist "${bootstrap}"/etc/pacman.d/mirrorlist

{
	echo
	echo "[multilib]"
	echo "Include = /etc/pacman.d/mirrorlist"
} >> "${bootstrap}"/etc/pacman.conf

run_in_chroot pacman-key --init
echo "keyserver hkps://keyserver.ubuntu.com" >> "${bootstrap}"/etc/pacman.d/gnupg/gpg.conf
run_in_chroot pacman-key --populate archlinux

# Add Chaotic-AUR repo
run_in_chroot pacman-key --recv-key 3056513887B78AEB
run_in_chroot pacman-key --lsign-key 3056513887B78AEB

mv chaotic-keyring.pkg.tar.zst chaotic-mirrorlist.pkg.tar.zst "${bootstrap}"/opt
run_in_chroot pacman --noconfirm -U /opt/chaotic-keyring.pkg.tar.zst /opt/chaotic-mirrorlist.pkg.tar.zst
rm "${bootstrap}"/opt/chaotic-keyring.pkg.tar.zst "${bootstrap}"/opt/chaotic-mirrorlist.pkg.tar.zst

{
	echo
	echo "[chaotic-aur]"
	echo "Include = /etc/pacman.d/chaotic-mirrorlist"
} >> "${bootstrap}"/etc/pacman.conf

# The ParallelDownloads feature of pacman
# Speeds up packages installation, especially when there are many small packages to install
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 3/g' "${bootstrap}"/etc/pacman.conf

# Do not install unneeded files (man pages and Nvidia firmwares)
sed -i 's/#NoExtract   =/NoExtract   = usr\/lib\/firmware\/nvidia\/\* usr\/share\/man\/\*/' "${bootstrap}"/etc/pacman.conf

run_in_chroot pacman -Sy archlinux-keyring --noconfirm
run_in_chroot pacman -Su --noconfirm

if [ "${enable_alhp_repo}" = "true" ]; then
	if [ "${alhp_feature_level}" -gt 2 ]; then
		alhp_feature_level=3
	else
		alhp_feature_level=2
	fi

	run_in_chroot pacman --noconfirm --needed -S alhp-keyring alhp-mirrorlist
	sed -i "s/#\[multilib\]/#/" "${bootstrap}"/etc/pacman.conf
	sed -i "s/\[core\]/\[core-x86-64-v${alhp_feature_level}\]\nInclude = \/etc\/pacman.d\/alhp-mirrorlist\n\n\[extra-x86-64-v${alhp_feature_level}\]\nInclude = \/etc\/pacman.d\/alhp-mirrorlist\n\n\[core\]/" "${bootstrap}"/etc/pacman.conf
	sed -i "s/\[multilib\]/\[multilib-x86-64-v${alhp_feature_level}\]\nInclude = \/etc\/pacman.d\/alhp-mirrorlist\n\n\[multilib\]/" "${bootstrap}"/etc/pacman.conf
	run_in_chroot pacman -Syu --noconfirm
fi

date -u +"%d-%m-%Y %H:%M (DMY UTC)" > "${bootstrap}"/version

# These packages are required for the self-update feature to work properly
run_in_chroot pacman --noconfirm --needed -S base reflector squashfs-tools fakeroot

# Regenerate the mirrorlist with reflector if reflector was not used before
if [ -z "${reflector_used}" ]; then
	echo "Generating mirrorlist..."
	run_in_chroot reflector --connection-timeout 10 --download-timeout 10 --protocol https --score 10 --sort rate --save /etc/pacman.d/mirrorlist
 	run_in_chroot pacman -Syu --noconfirm
fi

export -f install_packages
run_in_chroot bash -c install_packages

if [ -f "${bootstrap}"/opt/pacman_failed.txt ]; then
	unmount_chroot
	echo "Pacman failed to install some packages"
	exit 1
fi

if [ -n "${aur_packagelist}" ]; then
	run_in_chroot pacman --noconfirm --needed -S base-devel yay
	run_in_chroot useradd -m -G wheel aur
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> "${bootstrap}"/etc/sudoers

	for p in ${aur_packagelist}; do
		aur_pkgs="${aur_pkgs} aur/${p}"
	done
	export aur_pkgs

	export -f install_aur_packages
	CHROOT_AUR=1 HOME=/home/aur run_in_chroot bash -c install_aur_packages
	mv "${bootstrap}"/home/aur/bad_aur_pkglist.txt "${bootstrap}"/opt
fi

#run_in_chroot locale-gen

# Remove unneeded packages
run_in_chroot pacman --noconfirm -Rsu base-devel meson mingw-w64-gcc cmake gcc
run_in_chroot pacman --noconfirm -Rdd wine-staging
run_in_chroot pacman -Qdtq | run_in_chroot pacman --noconfirm -Rsn -
run_in_chroot pacman --noconfirm -Scc

# Generate a list of installed packages
run_in_chroot pacman -Q > "${bootstrap}"/pkglist.x86_64.txt

# Use locale from host
run_in_chroot rm -f "${bootstrap}"/etc/locale.conf
run_in_chroot sed -i 's/LANG=${LANG:-C}/LANG=$LANG/g' /etc/profile.d/locale.sh

# Try to fix GTK/GDK error messages
cp "${bootstrap}"/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so "${bootstrap}"/usr/lib/
cp "${bootstrap}"/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-* "${bootstrap}"/usr/lib/

# Remove bloatwares
run_in_chroot pacman --noconfirm -Rsndd gcc yay pacman systemd
run_in_chroot pacman -Qdtq | run_in_chroot pacman --noconfirm -Rsn -
run_in_chroot pacman --noconfirm -Rsndd pacman
run_in_chroot rm -Rf /usr/include /usr/share/man /usr/share/gtk-doc /usr/lib/gcc /usr/bin/gcc*
run_in_chroot bash -c 'find "${bootstrap}"/usr/share/doc/* -not -iname "*bottles*" -a -not -name "." -delete'
run_in_chroot bash -c 'find "${bootstrap}"/usr/share/locale/*/*/* -not -iname "*bottles*" -a -not -name "." -delete'
rm -rf "${bootstrap}"/usr/lib/*.a
rm -rf "${bootstrap}"/usr/lib/libgo.so*
rm -rf "${bootstrap}"/usr/lib/libgphobos.so*
rm -rf "${bootstrap}"/usr/lib/libjavascript*
rm -rf "${bootstrap}"/usr/lib/libwebkit*
rm -rf "${bootstrap}"/usr/lib/perl*
rm -rf "${bootstrap}"/usr/lib32/*.a
rm -rf "${bootstrap}"/usr/lib32/libgo.so*
rm -rf "${bootstrap}"/usr/lib32/libgphobos.so*
rm -rf "${bootstrap}"/usr/share/ibus/dicts/emoji*
rm -rf "${bootstrap}"/usr/lib/systemd
rm -rf "${bootstrap}"/usr/share/info
rm -rf "${bootstrap}"/usr/share/autoconf
rm -rf "${bootstrap}"/usr/share/automake
rm -rf "${bootstrap}"/usr/share/git*
rm -rf "${bootstrap}"/usr/share/fonts/*
rm -rf "${bootstrap}"/usr/share/pacman
rm -rf "${bootstrap}"/usr/share/gir-1.0
rm -rf "${bootstrap}"/var/lib/pacman/*
rm -f "${bootstrap}"/usr/bin/yay
rm -f "${bootstrap}"/usr/bin/git*
rm -f "${bootstrap}"/usr/bin/systemd*
rm -f "${bootstrap}"/usr/bin/pacman*
rm -f "${bootstrap}"/usr/bin/mangoplot
find "${bootstrap}"/usr/lib "${bootstrap}"/usr/lib32 -type f -regex '.*\.a' -exec rm -f {} \;
find "${bootstrap}"/usr -type f -regex '.*\.so.*' -exec strip --strip-debug {} \;
find "${bootstrap}"/usr/bin -type f ! -regex '.*\.so.*' -exec strip --strip-unneeded {} \;
find "${bootstrap}"/usr/lib -type f -regex '.*\.pyc' -exec rm -f {} \;

# Check if the command we are interested in has been installed
if ! run_in_chroot which bottles; then echo "Command not found, exiting." && exit 1; fi

# Exit chroot
rm -rf "${bootstrap}"/home/aur
unmount_chroot

# Use the patched bwrap to allow launching AppImages from conty
echo "Using patched bubblewrap..."
rm -f "${bootstrap}"/usr/bin/bwrap
wget "https://bin.ajam.dev/x86_64_Linux/bwrap-patched" -O "${bootstrap}"/usr/bin/bwrap || exit 1
chmod +x "${bootstrap}"/usr/bin/bwrap || exit 1

# Clear pacman package cache
rm -f "${bootstrap}"/var/cache/pacman/pkg/*

# Create some empty files and directories
# This is needed for bubblewrap to be able to bind real files/dirs to them
# later in the conty-start.sh script
mkdir "${bootstrap}"/media
mkdir -p "${bootstrap}"/usr/share/fonts
mkdir -p "${bootstrap}"/usr/share/steam/compatibilitytools.d
touch "${bootstrap}"/etc/asound.conf
touch "${bootstrap}"/etc/localtime
chmod 755 "${bootstrap}"/root

# Enable full font hinting
rm -f "${bootstrap}"/etc/fonts/conf.d/10-hinting-slight.conf
ln -s /usr/share/fontconfig/conf.avail/10-hinting-full.conf "${bootstrap}"/etc/fonts/conf.d

clear
echo "Done"

if [ -f "${bootstrap}"/opt/bad_pkglist.txt ]; then
	echo
	echo "These packages are not in the repos and have not been installed:"
	cat "${bootstrap}"/opt/bad_pkglist.txt
	rm "${bootstrap}"/opt/bad_pkglist.txt
fi

if [ -f "${bootstrap}"/opt/bad_aur_pkglist.txt ]; then
	echo
	echo "These packages are either not in the AUR or yay failed to download their"
	echo "PKGBUILDs:"
	cat "${bootstrap}"/opt/bad_aur_pkglist.txt
	rm "${bootstrap}"/opt/bad_aur_pkglist.txt
fi
