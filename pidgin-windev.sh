#!/bin/bash

version="2013.10.9"
pidgin_version="2.10.7"

if [[ -z "$1" || "$1" = "--help" || "$1" = "-h" ]]; then echo "
    Pidgin Windows Development Setup $version
    Copyright 2012, 2013 Renato Silva
    GPLv2 licensed

    Hi, I am supposed to set up a Windows build environment for Pidgin $pidgin_version
    in one single shot, suitable for building with MinGW MSYS, and without the
    pain of the manual steps described in wiki documentation at
    http://developer.pidgin.im/wiki/BuildingWinPidgin.

    I was designed based on that page, and I will try my best to perform what
    is described there, but I must say in advance you will need to manually
    install GnuPG, Bonjour SDK, and the Nsisunz NSIS plugin. You will be given
    more details when I finish. I was designed to run under MinGW MSYS with
    mingw-get command available.

    I am going to create a buildbox containing specific versions of GCC, Perl
    and NSIS, along with Pidgin build dependencies. After running me and
    finishing the manual steps you should be able to build Pidgin with
    'make -f Makefile.mingw installers' or the like.

    NOTES: source code tarball for 2.10.7 is broken and cannot be built without
    patching. In order to download Pidgin dependencies without security
    warnings, you need to have the appropriate CA certificates available to
    wget. Also, if you want to sign the installers, you will need to follow the
    manual instructions.

    Usage: $0 DEVELOPMENT_ROOT [--path] | --help | -h"
    echo
    exit
fi

download() {
    echo -e "\tFetching $(echo $1 | sed 's/\/download$//' | awk -F / '{ print $NF }')..."
    wget --no-check-certificate -nv -nc -P "$2" "$1" 2>&1 | grep -v "\->"
}


# Configuration

devroot="$1"
cache="$devroot/downloads"
win32="$devroot/win32-dev"
perl_version="5.10.1.5"
perl="strawberry-perl-$perl_version"
mingw="mingw-gcc-4.4.0"
nsis="nsis-2.46"

pidgin_base_url="https://developer.pidgin.im/static/win32"
gnome_base_url="http://ftp.gnome.org/pub/gnome/binaries/win32"
mingw_base_url="http://sourceforge.net/projects/mingw/files/MinGW/Base"
mingw_gcc4_url="$mingw_base_url/gcc/Version4/Previous%20Release%20gcc-4.4.0"
mingw_packages="bzip2 libiconv msys-make msys-patch msys-zip msys-unzip msys-bsdtar msys-wget msys-libopenssl msys-coreutils"

installing_packages="Installing some MSYS packages..."
downloading_mingw="Downloading specific MinGW GCC..."
downloading_pidgin="Downloading Pidgn source code..."
downloading_dependencies="Downloading build dependencies..."
extracting_mingw="Extracting MinGW GCC..."
extracting_pidgin="Extracting Pidgin source code..."
extracting_dependencies="Extracting build dependencies..."


# Just print PATH setup, or read pidgin version

[ "$2" = "--path" ] && echo "export PATH=\"$win32/$mingw/bin:$win32/$perl/perl/bin:$win32/$nsis:$PATH\"" && exit


# Install what is possible with MinGW automated installer

echo "$installing_packages"
for package in $mingw_packages; do
    echo -e "\tChecking $package..."
    mingw-get install "$package" 2>&1 | grep -v 'installed' | grep -i 'error'
done
echo


# Download MinGW GCC

echo "$downloading_mingw"
for gcc_package in \
    "$mingw_gcc4_url/gmp-4.2.4-mingw32-dll.tar.gz/download"                                         \
    "$mingw_gcc4_url/mpfr-2.4.1-mingw32-dll.tar.gz/download"                                        \
    "$mingw_gcc4_url/gcc-core-4.4.0-mingw32-bin.tar.gz/download"                                    \
    "$mingw_gcc4_url/gcc-core-4.4.0-mingw32-dll.tar.gz/download"                                    \
    "$mingw_gcc4_url/pthreads-w32-2.8.0-mingw32-dll.tar.gz/download"                                \
    "$mingw_base_url/w32api/w32api-3.14/w32api-3.14-mingw32-dev.tar.gz/download"                    \
    "$mingw_base_url/mingw-rt/mingwrt-3.17/mingwrt-3.17-mingw32-dev.tar.gz/download"                \
    "$mingw_base_url/mingw-rt/mingwrt-3.17/mingwrt-3.17-mingw32-dll.tar.gz/download"                \
    "$mingw_base_url/binutils/binutils-2.20/binutils-2.20-1-mingw32-bin.tar.gz/download"            \
    "$mingw_base_url/libiconv/libiconv-1.13.1-1/libiconv-1.13.1-1-mingw32-dll-2.tar.lzma/download"  \
; do download "$gcc_package" "$cache/$mingw"; done
echo


# Download Pidgin source tarball

echo "$downloading_pidgin"
download "prdownloads.sourceforge.net/pidgin/pidgin-$pidgin_version.tar.bz2" "$cache"
echo


# Download Pidgin build dependencies

echo "$downloading_dependencies"
for build_deependency in \
    "$pidgin_base_url/tcl-8.4.5.tar.gz"                                                              \
    "$pidgin_base_url/perl_5-10-0.tar.gz"                                                            \
    "$pidgin_base_url/gtkspell-2.0.16.tar.bz2"                                                       \
    "$pidgin_base_url/enchant_1.6.0_win32.zip"                                                       \
    "$pidgin_base_url/silc-toolkit-1.1.10.tar.gz"                                                    \
    "$pidgin_base_url/cyrus-sasl-2.1.25.tar.gz"                                                      \
    "$pidgin_base_url/nss-3.13.6-nspr-4.9.2.tar.gz"                                                  \
    "$pidgin_base_url/meanwhile-1.0.2_daa3-win32.zip"                                                \
    "$pidgin_base_url/pidgin-inst-deps-20130214.tar.gz"                                              \
    "$gnome_base_url/dependencies/gettext-tools-0.17.zip"                                            \
    "$gnome_base_url/dependencies/libxml2_2.9.0-1_win32.zip"                                         \
    "$gnome_base_url/dependencies/gettext-runtime-0.17-1.zip"                                        \
    "$gnome_base_url/intltool/0.40/intltool_0.40.4-1_win32.zip"                                      \
    "$gnome_base_url/dependencies/libxml2-dev_2.9.0-1_win32.zip"                                     \
    "$gnome_base_url/gtk+/2.14/gtk+-bundle_2.14.7-20090119_win32.zip"                                \
    "http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/$nsis.zip/download"                    \
    "http://strawberryperl.com/download/$perl_version/$perl.zip"                                     \
; do download "$build_deependency" "$cache"; done
echo


# Exctract downloads

echo "$extracting_mingw"
mkdir -p "$win32/$mingw"
mkdir -p "$win32/gcc-core-4.4.0-mingw32-dll"
tar -xzf "$cache/$mingw/gcc-core-4.4.0-mingw32-dll.tar.gz" --directory "$win32/gcc-core-4.4.0-mingw32-dll"
tar  --lzma -xf "$cache/$mingw/libiconv-1.13.1-1-mingw32-dll-2.tar.lzma" --directory "$win32/$mingw"
for gzip_tarball in "$cache/$mingw/"*".tar.gz"; do
    tar -xzf "$gzip_tarball" --directory "$win32/$mingw"
done

echo "$extracting_pidgin"
tar -xjf "$cache/pidgin-$pidgin_version.tar.bz2" --directory "$devroot"
echo "MONO_SIGNCODE = echo ***Bypassing signcode" > "$devroot/pidgin-$pidgin_version/local.mak"
echo "GPG_SIGN = echo ***Bypassing gpg"           >> "$devroot/pidgin-$pidgin_version/local.mak"

echo "$extracting_dependencies"
unzip -qo  "$cache/intltool_0.40.4-1_win32.zip"           -d "$win32/intltool_0.40.4-1_win32"
unzip -qo  "$cache/gtk+-bundle_2.14.7-20090119_win32.zip" -d "$win32/gtk_2_0-2.14"
unzip -qo  "$cache/gettext-tools-0.17.zip"                -d "$win32/gettext-0.17"
unzip -qo  "$cache/gettext-runtime-0.17-1.zip"            -d "$win32/gettext-0.17"
unzip -qo  "$cache/libxml2_2.9.0-1_win32.zip"             -d "$win32/libxml2-2.9.0"
unzip -qo  "$cache/libxml2-dev_2.9.0-1_win32.zip"         -d "$win32/libxml2-2.9.0"
unzip -qo  "$cache/$perl.zip"                             -d "$win32/$perl"
unzip -qo  "$cache/$nsis.zip"                             -d "$win32"
unzip -qo  "$cache/meanwhile-1.0.2_daa3-win32.zip"        -d "$win32"
unzip -qo  "$cache/enchant_1.6.0_win32.zip"               -d "$win32"
tar  -xjf  "$cache/gtkspell-2.0.16.tar.bz2"      --directory "$win32"

for gzip_tarball in "$cache/"*".tar.gz"; do
    bsdtar -xzf "$gzip_tarball" --directory "$win32"
done
cp "$win32/pidgin-inst-deps-20130214/SHA1Plugin.dll" "$win32/$nsis/Plugins/"
echo


# Finishing

echo "Finished setting up the build environment, remaining manual steps are:
1. Install GnuPG and make it available from PATH
2. Install Bonjour SDK under $win32/Bonjour_SDK
3. Install Nsisunz plugin for NSIS under $win32/$nsis/Plugins
4. Add downloaded GCC, Perl and NSIS before others in your PATH by running
   eval \$($0 $devroot --path)."
echo
