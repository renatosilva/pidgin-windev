#!/bin/bash

PIDGIN_VERSION="2.10.6"

if [[ -z "$1" || "$1" = "--help" ]]; then echo "
    Pidgin Windows Development Setup 2012.10.1-for-2.10.6
    Copyright 2012 Renato Silva
    GPLv2 licensed

    Hi, I am supposed to set up a Windows build environment for Pidgin
    in one single shot, without the pain of the manual steps described in
    http://developer.pidgin.im/wiki/BuildingWinPidgin.

    I was designed based on that page, and I will try my best to perform what
    is described there, but I must say in advance you will need to install
    Bonjour SDK and Nsisunz NSIS plugin manually. You will be given more
    details when I finish.

    I was designed to run under MinGW MSYS with mingw-get command available.
    Assumed Pidgin version is $PIDGIN_VERSION, but you can pass me some other
    version from 2.7 on and I should work just like the manual instructions.

    I am going to create a buildbox containing specific versions of GCC, Perl
    and NSIS, along with Pidgin build dependencies. After running me and
    finishing the manual steps you should be able to build Pidgin with
    '\$make -f Makefile.mingw installers' or the like.

    Usage: $0 DEVELOPMENT_ROOT [--pidgin-version VERSION] | --help"
    echo
    exit
fi

download() {
    echo -e "\tFetching $(echo $1 | sed 's/\/download$//' | awk -F / '{ print $NF }')..."
    wget -nv -nc -P "$2" "$1" 2>&1 | grep -v "\->"
}


# Configuration

DEVROOT="$1"
CACHE="$DEVROOT/downloads"
WIN32="$DEVROOT/win32-dev"
PERL="ActivePerl-5.12.4.1205"
MINGW="mingw-gcc-4.4.0"
NSIS="nsis-2.46"

PIDGIN_BASE_URL="http://developer.pidgin.im/static/win32"
GNOME_BASE_URL="http://ftp.gnome.org/pub/gnome/binaries/win32"
MINGW_BASE_URL="http://sourceforge.net/projects/mingw/files/MinGW/Base"
MINGW_GCC4_URL="$MINGW_BASE_URL/gcc/Version4/Previous%20Release%20gcc-4.4.0"
MINGW_PACKAGES="bzip2 libiconv msys-make msys-patch msys-zip msys-unzip bsdtar msys-wget"

INSTALLING_PACKAGES="Installing some MSYS packages..."
DOWNLOADING_MINGW="Downloading specific MinGW GCC..."
DOWNLOADING_PIDGIN="Downloading Pidgn source code..."
DOWNLOADING_DEPENDENCIES="Downloading build dependencies..."
EXTRACTING_MINGW="Extracting MinGW GCC..."
EXTRACTING_PIDGIN="Extracting Pidgin source code..."
EXTRACTING_DEPENDENCIES="Extracting build dependencies..."


# Just print PATH setup, or read pidgin version

[ "$2" = "--path" ] && echo "export PATH=\"$WIN32/$MINGW/bin:$WIN32/$PERL/perl/bin:$WIN32/$NSIS:$PATH\"" && exit
[ "$2" = "--pidgin-version" ] && [ ! -z  "$3" ] && PIDGIN_VERSION="$3"


# Install what is possible with MinGW automated installer

echo "$INSTALLING_PACKAGES"
for PACKAGE in $MINGW_PACKAGES; do
    echo -e "\tChecking $PACKAGE..."
    mingw-get install "$PACKAGE" 2>&1 | grep -v 'installed' | grep -i 'error'
done
echo


# Download MinGW GCC

echo "$DOWNLOADING_MINGW"
for GCC_PACKAGE in \
    "$MINGW_GCC4_URL/gmp-4.2.4-mingw32-dll.tar.gz/download"                                         \
    "$MINGW_GCC4_URL/mpfr-2.4.1-mingw32-dll.tar.gz/download"                                        \
    "$MINGW_GCC4_URL/gcc-core-4.4.0-mingw32-bin.tar.gz/download"                                    \
    "$MINGW_GCC4_URL/gcc-core-4.4.0-mingw32-dll.tar.gz/download"                                    \
    "$MINGW_GCC4_URL/pthreads-w32-2.8.0-mingw32-dll.tar.gz/download"                                \
    "$MINGW_BASE_URL/w32api/w32api-3.14/w32api-3.14-mingw32-dev.tar.gz/download"                    \
    "$MINGW_BASE_URL/mingw-rt/mingwrt-3.17/mingwrt-3.17-mingw32-dev.tar.gz/download"                \
    "$MINGW_BASE_URL/mingw-rt/mingwrt-3.17/mingwrt-3.17-mingw32-dll.tar.gz/download"                \
    "$MINGW_BASE_URL/binutils/binutils-2.20/binutils-2.20-1-mingw32-bin.tar.gz/download"            \
    "$MINGW_BASE_URL/libiconv/libiconv-1.13.1-1/libiconv-1.13.1-1-mingw32-dll-2.tar.lzma/download"  \
; do download "$GCC_PACKAGE" "$CACHE/$MINGW"; done
echo


# Download Pidgin source tarball

echo "$DOWNLOADING_PIDGIN"
download "prdownloads.sourceforge.net/pidgin/pidgin-$PIDGIN_VERSION.tar.bz2" "$CACHE"
echo


# Download Pidgin build dependencies

echo "$DOWNLOADING_DEPENDENCIES"
for BUILD_DEEPENDENCY in \
    "$PIDGIN_BASE_URL/tcl-8.4.5.tar.gz"                                                              \
    "$PIDGIN_BASE_URL/perl_5-10-0.tar.gz"                                                            \
    "$PIDGIN_BASE_URL/gtkspell-2.0.16.tar.bz2"                                                       \
    "$PIDGIN_BASE_URL/enchant_1.6.0_win32.zip"                                                       \
    "$PIDGIN_BASE_URL/silc-toolkit-1.1.8.tar.gz"                                                     \
    "$PIDGIN_BASE_URL/cyrus-sasl-2.1.22-daa1.zip"                                                    \
    "$PIDGIN_BASE_URL/nss-3.12.5-nspr-4.8.2.tar.gz"                                                  \
    "$PIDGIN_BASE_URL/meanwhile-1.0.2_daa2-win32.zip"                                                \
    "$PIDGIN_BASE_URL/pidgin-inst-deps-20100315.tar.gz"                                              \
    "$GNOME_BASE_URL/dependencies/gettext-tools-0.17.zip"                                            \
    "$GNOME_BASE_URL/dependencies/libxml2_2.7.4-1_win32.zip"                                         \
    "$GNOME_BASE_URL/dependencies/gettext-runtime-0.17-1.zip"                                        \
    "$GNOME_BASE_URL/intltool/0.40/intltool_0.40.4-1_win32.zip"                                      \
    "$GNOME_BASE_URL/dependencies/libxml2-dev_2.7.4-1_win32.zip"                                     \
    "$GNOME_BASE_URL/gtk+/2.14/gtk+-bundle_2.14.7-20090119_win32.zip"                                \
    "http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/$NSIS.zip/download"                    \
    "http://downloads.activestate.com/ActivePerl/releases/5.12.4.1205/$PERL-MSWin32-x86-294981.zip"  \
; do download "$BUILD_DEEPENDENCY" "$CACHE"; done
echo


# Exctract downloads

echo "$EXTRACTING_MINGW"
mkdir -p "$WIN32/$MINGW"
tar  --lzma -xf "$CACHE/$MINGW/libiconv-1.13.1-1-mingw32-dll-2.tar.lzma" --directory "$WIN32/$MINGW"
for GZIP_TARBALL in "$CACHE/$MINGW/"*".tar.gz"; do
    tar -xzf "$GZIP_TARBALL" --directory "$WIN32/$MINGW"
done

echo "$EXTRACTING_PIDGIN"
tar -xjf "$CACHE/pidgin-$PIDGIN_VERSION.tar.bz2" --directory "$DEVROOT"

echo "$EXTRACTING_DEPENDENCIES"
unzip -qo  "$CACHE/intltool_0.40.4-1_win32.zip"           -d "$WIN32/intltool_0.40.4-1_win32"
unzip -qo  "$CACHE/gtk+-bundle_2.14.7-20090119_win32.zip" -d "$WIN32/gtk_2_0-2.14"
unzip -qo  "$CACHE/gettext-tools-0.17.zip"                -d "$WIN32/gettext-0.17"
unzip -qo  "$CACHE/gettext-runtime-0.17-1.zip"            -d "$WIN32/gettext-0.17"
unzip -qo  "$CACHE/libxml2_2.7.4-1_win32.zip"             -d "$WIN32/libxml2-2.7.4"
unzip -qo  "$CACHE/libxml2-dev_2.7.4-1_win32.zip"         -d "$WIN32/libxml2-2.7.4"
unzip -qo  "$CACHE/enchant_1.6.0_win32.zip"               -d "$WIN32"
unzip -qo  "$CACHE/cyrus-sasl-2.1.22-daa1.zip"            -d "$WIN32"
unzip -qo  "$CACHE/$PERL-MSWin32-x86-294981.zip"          -d "$WIN32"
unzip -qo  "$CACHE/meanwhile-1.0.2_daa2-win32.zip"        -d "$WIN32"
unzip -qo  "$CACHE/$NSIS.zip"                             -d "$WIN32"
tar  -xjf  "$CACHE/gtkspell-2.0.16.tar.bz2"      --directory "$WIN32"

rm -rf "$WIN32/$PERL"
mv "$WIN32/$PERL-MSWin32-x86-294981" "$WIN32/$PERL"
for GZIP_TARBALL in "$CACHE/"*".tar.gz"; do
    bsdtar -xzf "$GZIP_TARBALL" --directory "$WIN32"
done
echo


# Finishing

echo "Finished setting up the build environment, remaining manual steps are:
1. Install Bonjour SDK under $WIN32/Bonjour_SDK
2. Install Nsisunz plugin for NSIS under $WIN32/$NSIS/Plugins
3. Add downloaded GCC, Perl and NSIS before others in your PATH by running
   eval \$($0 $DEVROOT --path)."
echo
