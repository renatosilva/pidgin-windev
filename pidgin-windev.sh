#!/bin/bash

##
##    Pidgin Windows Development Setup 2014.8.6
##    Copyright 2012-2014 Renato Silva
##    GPLv2 licensed
##
## Hi, I am supposed to set up a Windows build environment for Pidgin or
## Pidgin++ 2.x in one single shot, suitable for building with MSYS2 or MinGW
## MSYS, without the long manual steps described in the wiki documentation at
## http://developer.pidgin.im/wiki/BuildingWinPidgin.
##
## I was designed based on that guide, and I will try my best to perform what
## is described there, but I must say in advance you will need to manually
## install the Bonjour SDK, and if using MinGW MSYS, also GnuPG. You will be
## given more details when I finish. I was designed to run under MSYS2 with
## pacman command available, or under MinGW MSYS with mingw-get.
##
## I am going to create a buildbox containing specific versions of GCC, Perl and
## NSIS, along with Pidgin build dependencies. After running me and finishing
## the manual steps you should be able to build Pidgin with something like
## "make -f Makefile.mingw installers" or similar.
##
## NOTES: source code tarball for 2.10.9 cannot be built on MinGW MSYS without
## patching, or without some wget version newer than 1.12. In order to download
## Pidgin dependencies without security warnings, this script obtains the
## appropriate CA bundle from the cURL website. Finally, if you want to sign the
## installers, you will need to follow the manual instructions.
##
## Usage:
##     @script.name DEVELOPMENT_ROOT [options]
##
##     -p, --path          Print system path configuration for evaluation after
##                         the build environment has been created. This will
##                         allow you to start compilation.
##
##     -g, --system-gcc    Do not include custom GCC in --path.
##
##     -w, --which-pidgin  Show the Pidgin and Pidgin++ versions this script
##                         can handle. When specified as "the next version" this
##                         script is currently under development and unusable
##                         for that Pidgin variant.
##
##         --for=VARIANT   The Pidgin variant for which a build environment will
##                         be created, either "pidgin" (default) or "pidgin++".
##


# Parse options
eval "$(from="$0" easyoptions.rb "$@"; echo result=$?)"


# Pidgin versions
pidgin_version="2.10.9"
plus_plus_version="2.10.9-RS137"
if [[ -n "$which_pidgin" ]]; then
    [[ "$pidgin_version" = *.next ]] && pidgin_prefix="next version following "
    [[ "$plus_plus_version" = *.next ]] && plus_plus_prefix="next version following "

    echo "Pidgin: ${pidgin_prefix}${pidgin_version%.next}"
    echo "Pidgin++: ${plus_plus_prefix}${plus_plus_version%.next}"
    exit
fi


# MSYS or MSYS2 required
system=$(uname -o)
system_version=$(uname -r)
if [[ "$system" != Msys || "$system_version" != [12].* ]]; then
    echo "Incompatible environment: $system $system_version."
    echo "This script must be executed under MSYS2 or MinGW MSYS, see --help."
    exit 1
else
    case "$system_version" in
        1.*) system="MinGW MSYS" ;;
        2.*) system="MSYS2" ;;
    esac
fi


# Pidgin variant
see_help="See --help for usage and options."
if [[ -n "$for" && "$for" != "pidgin" && "$for" != "pidgin++" ]]; then
    echo "Unrecognized Pidgin variant: \`$for'."
    echo "$see_help"
    exit 1
fi
if [[ "$for" = "pidgin++" ]]; then
    pidgin_variant="Pidgin++"
    pidgin_variant_version="$plus_plus_version"
    pidgin_plus_plus="yes"
else
    pidgin_variant="Pidgin"
    pidgin_variant_version="$pidgin_version"
fi


# Under development
if [[ "$pidgin_variant_version" = *.next ]]; then
    echo "This script is under development for the next version of $pidgin_variant following"
    echo "${pidgin_variant_version%.next} and is currently unusable. You need to use the version that"
    echo "matches your desired $pidgin_variant version. For general information, see --help."
    exit 1
fi


# Development root
devroot="${arguments[0]}"
[[ $result != 0 ]] && exit
if [[ -z "$devroot" ]]; then
    echo "A development root must be specified, see --help."
    exit 1
fi
if [[ ! -e "$devroot" ]]; then
    printf "Creating new development root at $devroot...\n\n"
    mkdir -p "$devroot"
elif [[ ! -d "$devroot" ]]; then
    echo "The existing development root is not a directory: \`$devroot'."
    echo "$see_help"
    exit 1
fi


# Readlink from MinGW MSYS requires a Unix path
cd "$devroot"
devroot=$(readlink -m "$(pwd)")
cd - > /dev/null


# Configuration
cache="$devroot/downloads"
win32="$devroot/win32-dev"
perl_version="5.10.1.5"
perl="strawberry-perl-$perl_version"
mingw="mingw-gcc-4.7.2"
gcc_core44="gcc-core-4.4.0-mingw32-dll"
gtkspell="gtkspell-2.0.16"
nsis="nsis-2.46"

ca_bundle="/tmp/mozilla.pem"
ca_bundle_url="http://curl.haxx.se/ca/cacert.pem"
pidgin_base_url="https://developer.pidgin.im/static/win32"
gnome_base_url="http://ftp.gnome.org/pub/gnome/binaries/win32"
mingw_base_url="http://sourceforge.net/projects/mingw/files/MinGW/Base"
mingw_gcc44_url="$mingw_base_url/gcc/Version4/Previous%20Release%20gcc-4.4.0"
mingw_pthreads_url="$mingw_base_url/pthreads-w32/pthreads-w32-2.9.0-pre-20110507-2"
xmlstarlet_base_url="http://sourceforge.net/projects/xmlstar/files/xmlstarlet"
packages="bzip2 libiconv msys-make msys-patch msys-zip msys-unzip msys-bsdtar msys-wget msys-libopenssl msys-coreutils"

installing_packages="Installing some $system packages..."
downloading_mingw="Downloading specific MinGW GCC..."
downloading_pidgin="Downloading $pidgin_variant source code..."
downloading_dependencies="Downloading build dependencies..."
downloading_ca_bundle="Downloading CA bundle..."
extracting_mingw="Extracting MinGW GCC..."
extracting_pidgin="Extracting $pidgin_variant source code..."
extracting_dependencies="Extracting build dependencies..."


# Functions
download() {
    which "$3" > /dev/null 2>&1 && return
    echo -e "\tFetching $(echo $1 | sed 's/\/download$//' | awk -F / '{ print $NF }')..."
    if [[ -f "$ca_bundle" ]]; then
        cert_args="--ca-certificate $ca_bundle"
    else
        cert_args="--no-check-certificate"
    fi
    filename="${1%/download}"
    filename="${filename##*/}"
    wget $cert_args -nv -nc -O "$2/$filename" "$1" 2>&1 | grep -v "\->"
}
extract_zip() {
    echo -e "\tExtracting ${1##*/}..."
    unzip -qo${3:+j} "$1" $3 -d "$2"
}


# Path configuration
if [[ -n "$path" ]]; then
    [[ -z "$system_gcc" ]] && custom_gcc="$win32/$mingw/bin:"
    echo "export PATH=\"${custom_gcc}$win32/$perl/perl/bin:$win32/$nsis:$win32:$PATH\""
    exit
fi


# Install what is possible with package manager
echo "$installing_packages"
for package in $packages; do
    if [[ "$system_version" = 1.* ]]; then
        echo -e "\tChecking $package..."
        mingw-get install "$package" 2>&1 | grep -v 'installed' | grep -i 'error'
    else
        package="${package#msys-}"
        printf "\tChecking $package..."
        pacman --noconfirm --sync --needed "$package" 3> /dev/null >&3 2>&3 || printf " error"
        echo
    fi
done
echo


# Download certificates
printf "$downloading_ca_bundle\n\t"
wget -q -O "$ca_bundle" "$ca_bundle_url" && echo "Saved to $ca_bundle."
echo


# Download GCC
mkdir -p "$cache/$mingw"
echo "$downloading_mingw"
for gcc_package in \
    "$mingw_base_url/gmp/gmp-5.0.1-1/gmp-5.0.1-1-mingw32-dev.tar.lzma/download"                      \
    "$mingw_base_url/gmp/gmp-5.0.1-1/libgmp-5.0.1-1-mingw32-dll-10.tar.lzma/download"                \
    "$mingw_base_url/mpfr/mpfr-2.4.1-1/mpfr-2.4.1-1-mingw32-dev.tar.lzma/download"                   \
    "$mingw_base_url/mpfr/mpfr-2.4.1-1/libmpfr-2.4.1-1-mingw32-dll-1.tar.lzma/download"              \
    "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/gcc-core-4.7.2-1-mingw32-bin.tar.lzma/download"        \
    "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libgcc-4.7.2-1-mingw32-dll-1.tar.lzma/download"        \
    "$mingw_pthreads_url/pthreads-w32-2.9.0-mingw32-pre-20110507-2-dev.tar.lzma/download"            \
    "$mingw_pthreads_url/libpthreadgc-2.9.0-mingw32-pre-20110507-2-dll-2.tar.lzma/download"          \
    "$mingw_base_url/w32api/w32api-3.17/w32api-3.17-2-mingw32-dev.tar.lzma/download"                 \
    "$mingw_base_url/mingw-rt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dev.tar.lzma/download"             \
    "$mingw_base_url/mingw-rt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dll.tar.lzma/download"             \
    "$mingw_base_url/binutils/binutils-2.23.1/binutils-2.23.1-1-mingw32-bin.tar.lzma/download"       \
    "$mingw_base_url/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dll-2.tar.lzma/download"       \
    "$mingw_base_url/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dev.tar.lzma/download"         \
    "$mingw_base_url/mpc/mpc-0.8.1-1/mpc-0.8.1-1-mingw32-dev.tar.lzma/download"                      \
    "$mingw_base_url/mpc/mpc-0.8.1-1/libmpc-0.8.1-1-mingw32-dll-2.tar.lzma/download"                 \
    "$mingw_base_url/gettext/gettext-0.18.1.1-2/libintl-0.18.1.1-2-mingw32-dll-8.tar.lzma/download"  \
    "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libgomp-4.7.2-1-mingw32-dll-1.tar.lzma/download"       \
    "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libssp-4.7.2-1-mingw32-dll-0.tar.lzma/download"        \
    "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libquadmath-4.7.2-1-mingw32-dll-0.tar.lzma/download"   \
; do download "$gcc_package" "$cache/$mingw"; done
echo


# Download Pidgin
echo "$downloading_pidgin"
if [[ -n "$pidgin_plus_plus" ]]; then
    plus_plus_milestone=$(echo "$plus_plus_version" | tr [:upper:] [:lower:])
    download "https://launchpad.net/pidgin++/trunk/$plus_plus_milestone/+download/Pidgin $plus_plus_version Source.zip" "$cache"
else
    download "prdownloads.sourceforge.net/pidgin/pidgin-$pidgin_version.tar.bz2" "$cache"
fi
echo


# Download dependencies
echo "$downloading_dependencies"
for build_dependency in \
    "$pidgin_base_url/tcl-8.4.5.tar.gz"                                                              \
    "$pidgin_base_url/perl_5-10-0.tar.gz"                                                            \
    "$pidgin_base_url/$gtkspell.tar.bz2"                                                             \
    "$pidgin_base_url/enchant_1.6.0_win32.zip"                                                       \
    "$pidgin_base_url/silc-toolkit-1.1.10.tar.gz"                                                    \
    "$pidgin_base_url/cyrus-sasl-2.1.25.tar.gz"                                                      \
    "$pidgin_base_url/nss-3.15.4-nspr-4.10.2.tar.gz"                                                 \
    "$pidgin_base_url/meanwhile-1.0.2_daa3-win32.zip"                                                \
    "$pidgin_base_url/pidgin-inst-deps-20130214.tar.gz"                                              \
    "$gnome_base_url/dependencies/gettext-tools-0.17.zip"                                            \
    "$gnome_base_url/dependencies/libxml2_2.9.0-1_win32.zip"                                         \
    "$gnome_base_url/dependencies/gettext-runtime-0.17-1.zip"                                        \
    "$gnome_base_url/intltool/0.40/intltool_0.40.4-1_win32.zip"                                      \
    "$gnome_base_url/dependencies/libxml2-dev_2.9.0-1_win32.zip"                                     \
    "$gnome_base_url/gtk+/2.14/gtk+-bundle_2.14.7-20090119_win32.zip"                                \
    "http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/$nsis.zip/download"                    \
    "http://nsis.sourceforge.net/mediawiki/images/1/1c/Nsisunz.zip"                                  \
    "http://strawberryperl.com/download/$perl_version/$perl.zip"                                     \
    "$mingw_gcc44_url/$gcc_core44.tar.gz/download"                                                   \
; do download "$build_dependency" "$cache"; done
if [[ -n "$pidgin_plus_plus" ]]; then
    download "http://nsis.sourceforge.net/mediawiki/images/c/c9/Inetc.zip" "$cache"
    download "$xmlstarlet_base_url/1.6.0/xmlstarlet-1.6.0-win32.zip/download" "$cache" "xmlstarlet"
fi
echo


# Extract GCC
echo "$extracting_mingw"
mkdir -p "$win32/$mingw"
for lzma_tarball in "$cache/$mingw/"*".tar.lzma"; do
    echo -e "\tExtracting ${lzma_tarball##*/}..."
    tar --lzma -xf "$lzma_tarball" --directory "$win32/$mingw"
done
echo


# Extract Pidgin
echo "$extracting_pidgin"
if [[ -n "$pidgin_plus_plus" ]]; then
    unzip -qo "$cache/Pidgin $plus_plus_version Source.zip" -d "$devroot"
else
    tar -xjf "$cache/pidgin-$pidgin_version.tar.bz2" --directory "$devroot"
    echo "MONO_SIGNCODE = echo ***Bypassing signcode***" >  "$devroot/pidgin-$pidgin_variant_version/${pidgin_plus_plus:+source/}local.mak"
    echo "GPG_SIGN = echo ***Bypassing gpg***"           >> "$devroot/pidgin-$pidgin_variant_version/${pidgin_plus_plus:+source/}local.mak"
fi
echo


# Extract dependencies
echo "$extracting_dependencies"
extract_zip "$cache/intltool_0.40.4-1_win32.zip"              "$win32/intltool_0.40.4-1_win32"
extract_zip "$cache/gtk+-bundle_2.14.7-20090119_win32.zip"    "$win32/gtk_2_0-2.14"
extract_zip "$cache/gettext-tools-0.17.zip"                   "$win32/gettext-0.17"
extract_zip "$cache/gettext-runtime-0.17-1.zip"               "$win32/gettext-0.17"
extract_zip "$cache/libxml2_2.9.0-1_win32.zip"                "$win32/libxml2-2.9.0"
extract_zip "$cache/libxml2-dev_2.9.0-1_win32.zip"            "$win32/libxml2-2.9.0"
extract_zip "$cache/$perl.zip"                                "$win32/$perl"
extract_zip "$cache/$nsis.zip"                                "$win32"
extract_zip "$cache/meanwhile-1.0.2_daa3-win32.zip"           "$win32"
extract_zip "$cache/enchant_1.6.0_win32.zip"                  "$win32"
extract_zip "$cache/Nsisunz.zip"                              "$win32/$nsis/Plugins" "nsisunz/Release/nsisunz.dll"

if [[ -n "$pidgin_plus_plus" ]]; then
    extract_zip "$cache/Inetc.zip" "$win32/$nsis/Plugins/" "Plugins/inetc.dll"
    if ! which xmlstarlet > /dev/null 2>&1; then
        extract_zip "$cache/xmlstarlet-1.6.0-win32.zip" "$win32" "xmlstarlet-1.6.0/xml.exe"
        mv "$win32/xml.exe" "$win32/xmlstarlet.exe"
    fi
fi

mkdir -p "$win32/$gcc_core44"
echo -e "\tExtracting $gcc_core44.tar.gz..."; tar -xzf "$cache/$gcc_core44.tar.gz"       --directory "$win32/gcc-core-4.4.0-mingw32-dll"
echo -e "\tExtracting $gtkspell.tar.bz2...";  tar -xjf "$cache/gtkspell-2.0.16.tar.bz2"  --directory "$win32"

for gzip_tarball in "$cache/"*".tar.gz"; do
    [[ "$gzip_tarball" = *"gcc-core-4.4.0-mingw32-dll.tar.gz" ]] && continue
    echo -e "\tExtracting ${gzip_tarball##*/}..."
    bsdtar -xzf "$gzip_tarball" --directory "$win32"
done
echo -e "\tInstalling the NSIS SHA1 plugin..."
cp "$win32/pidgin-inst-deps-20130214/SHA1Plugin.dll" "$win32/$nsis/Plugins/"
echo

# Finishing
echo "Finished, remaining manual steps are:"
bonjour="Install Bonjour SDK under $win32/Bonjour_SDK."
gnupg="Install GnuPG and make it available from PATH."
path="Add downloaded GCC, Perl and NSIS before others in your PATH by running"
eval="eval \$($0 $devroot --path)."

case "$system_version" in
2.*) echo "1. $bonjour"
     echo "2. $path"
     echo "   $eval"
     ;;
  *) echo "1. $gnupg"
     echo "2. $bonjour"
     echo "3. $path"
     echo "   $eval"
esac
echo
