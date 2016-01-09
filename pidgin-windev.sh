#!/bin/bash

version="2016.1.9"
pidgin_version="2.10.12"
devroot="$1"
path="$2"

if [[ "$1" = -* || -z "$devroot" || ( -n "$path" && "$path" != --path ) ]]; then echo "
    Pidgin Windows Development Setup ${version}
    Copyright 2012-2016 Renato Silva
    Licensed under BSD

    This Cygwin/MSYS script sets up a Windows build environment for Pidgin ${pidgin_version}
    in one single shot, without the long manual steps described in the official
    documentation. These steps are automatically executed, except for GnuPG
    installation in MSYS. After running this tool you can configure system path
    by evaluating the output of --path.

    Note that the Pidgin source tarball is currently broken. The expected GTK+
    checkshum is outdated, as well as the NSS/NSPR version. Also, MinGW lacks
    default CA certificates required for wget performing HTTPS downloads during
    build. For these reasons, source code will be patched.

    Usage: $(basename "$0") DEVELOPMENT_ROOT [--path]"
    echo
    exit
fi

# Output formatting
step() { printf "${green}$1${normal}\n"; }
info() { printf "$1${2:+ ${purple}$2${normal}}\n"; }
warn() { printf "${1:+${yellow}Warning:${normal} $1}\n"; }
oops() { printf "${red}Error:${normal} $1.\nSee --help for usage and options.\n"; exit 1; }
if [[ -t 1 && -z "$no_color" ]]; then
    normal="\e[0m"
    if [[ "$MSYSCON" = mintty* && "$TERM" = *256color* ]]; then
        red="\e[38;05;9m"
        green="\e[38;05;76m"
        blue="\e[38;05;74m"
        yellow="\e[0;33m"
        purple="\e[38;05;165m"
    else
        red="\e[1;31m"
        green="\e[1;32m"
        blue="\e[1;34m"
        yellow="\e[1;33m"
        purple="\e[1;35m"
    fi
fi

# Under development
if [[ "$pidgin_version" = *.next ]]; then
    echo "This script is under development for the next version of Pidgin following"
    echo "${pidgin_version%.next} and currently can only create a build environment for some specific"
    echo "development revision from the source code repository."
    exit 1
fi

# Development root
if [[ ! -e "$devroot" ]]; then
    step "Creating new development root"
    info "Location:" "$devroot"
    info; mkdir -p "$devroot"
fi
cd "$devroot" || exit
devroot=$(readlink -m "$(pwd)")
[[ $? != 0 ]] && oops "failed to get absolute path for $devroot"
cd - > /dev/null

# Configuration
system=$(uname -o)
cache="$devroot/downloads"
win32="$devroot/win32-dev"
nsis="nsis-2.46"
mingw="mingw-gcc-4.7.2"
gtkspell="gtkspell-2.0.16"
gcc_core44="gcc-core-4.4.0-mingw32-dll"
gcc_source="gcc-4.7.2-1-mingw32-src"
pidgin_inst_deps="pidgin-inst-deps-20130214"
intltool="intltool_0.40.4-1_win32"
perl_version="5.20.1.1"
perl="strawberry-perl-$perl_version-32bit"
perl_dir="strawberry-perl-${perl_version%.*}"
pidgin_base_url="https://developer.pidgin.im/static/win32"
gnome_base_url="http://ftp.gnome.org/pub/gnome/binaries"
mingw_base_url="http://sourceforge.net/projects/mingw/files/MinGW/Base"
mingw_gcc44_url="$mingw_base_url/gcc/Version4/Previous%20Release%20gcc-4.4.0"
mingw_pthreads_url="$mingw_base_url/pthreads-w32/pthreads-w32-2.9.0-pre-20110507-2"

# Functions

available() {
    which "$1" >/dev/null 2>&1
    return $?
}

download() {
    filename="${2%/download}"
    filename="${filename##*/}"
    info "Fetching" "$filename"
    file="$1/$filename"
    mkdir -p "$1"
    [[ -f "$file" && ! -s "$file" ]] && rm "$file"
    [[ ! -e "$file" ]] && { wget --no-check-certificate --quiet --output-document "$file" "$2" || oops "failed downloading from ${2}"; }
}

extract() {
    format="$1"
    directory="$2"
    compressed="$3"
    files=("${@:4}")
    compressed_name="${compressed##*/}"
    info "Extracting" "${files[0]:+${files[0]##*/}${files[1]:+ and other files} from }${compressed_name}"
    mkdir -p "$directory"
    case "$format" in
        bsdtar)  bsdtar -xzf          "$compressed"  --directory "$directory" ;;
        lzma)    tar --lzma -xf       "$compressed"  --directory "$directory" ;;
        bzip2)   tar -xjf             "$compressed"  --directory "$directory" "${files[@]}" ;;
        gzip)    tar -xzf             "$compressed"  --directory "$directory" ;;
        zip)     unzip -qo${files:+j} "$compressed" "${files[@]}" -d "$directory" ;;
    esac || exit
}

install() {
    package="$1"
    info 'Checking' "$package"
    case "${system}" in
        Cygwin) apt-cyg install "$package"             >/dev/null 2>&1 || oops "failed installing ${package}" ;;
        Msys) mingw-get install "$package" --verbose=0 >/dev/null 2>&1 || oops "failed installing ${package}" ;;
    esac
}

# Path configuration
if [[ -n "$path" ]]; then
    printf "export PATH='"
    printf "${win32}/${mingw}/bin:"
    printf "${win32}/${perl_dir}/perl/bin:"
    printf "${win32}/${nsis}:"
    printf "${PATH}'"
    exit
fi

# Install what is possible with package manager
step "Installing the necessary packages"
if [[ "${system}" = Cygwin ]]; then
    if ! available apt-cyg; then
        info 'Installing' 'apt-cyg'
        lynx -source 'https://github.com/transcode-open/apt-cyg/raw/master/apt-cyg' > /usr/local/bin/apt-cyg
        chmod +x /usr/local/bin/apt-cyg
    fi
    install 'bsdtar'
    install 'ca-certificates'
    install 'gnupg'
    install 'libiconv'
    install 'make'
    install 'patch'
    install 'unzip'
    install 'wget'
    install 'zip'
else
    if available mingw-get; then
        install 'mingw32-bzip2'
        install 'mingw32-libiconv'
        install 'msys-bsdtar'
        install 'msys-coreutils'
        install 'msys-libopenssl'
        install 'msys-make'
        install 'msys-patch'
        install 'msys-unzip'
        install 'msys-wget'
        install 'msys-zip'
    else
        warn 'could not find mingw-get in system path'
    fi
fi
echo

# Download GCC
step "Downloading specific MinGW GCC"
download "${cache}/${mingw}" "${mingw_base_url}/binutils/binutils-2.23.1/binutils-2.23.1-1-mingw32-bin.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/gcc-core-4.7.2-1-mingw32-bin.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/${gcc_source}.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libgcc-4.7.2-1-mingw32-dll-1.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libgomp-4.7.2-1-mingw32-dll-1.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libquadmath-4.7.2-1-mingw32-dll-0.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libssp-4.7.2-1-mingw32-dll-0.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gettext/gettext-0.18.1.1-2/libintl-0.18.1.1-2-mingw32-dll-8.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gmp/gmp-5.0.1-1/gmp-5.0.1-1-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gmp/gmp-5.0.1-1/libgmp-5.0.1-1-mingw32-dll-10.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dll-2.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mingwrt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mingwrt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dll.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpc/mpc-0.8.1-1/libmpc-0.8.1-1-mingw32-dll-2.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpc/mpc-0.8.1-1/mpc-0.8.1-1-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpfr/mpfr-2.4.1-1/libmpfr-2.4.1-1-mingw32-dll-1.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpfr/mpfr-2.4.1-1/mpfr-2.4.1-1-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/w32api/w32api-3.17/w32api-3.17-2-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_pthreads_url}/libpthreadgc-2.9.0-mingw32-pre-20110507-2-dll-2.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_pthreads_url}/pthreads-w32-2.9.0-mingw32-pre-20110507-2-dev.tar.lzma/download"
echo

# Download Pidgin
step "Downloading Pidgin source code"
download "$cache" "http://prdownloads.sourceforge.net/pidgin/pidgin-${pidgin_version}.tar.bz2"
source_directory="${devroot}/pidgin-${pidgin_version}"
echo

# Download dependencies
step "Downloading build dependencies"
download "${cache}" "${gnome_base_url}/win32/dependencies/gettext-runtime-0.17-1.zip"
download "${cache}" "${gnome_base_url}/win32/dependencies/gettext-tools-0.17.zip"
download "${cache}" "${gnome_base_url}/win32/gtk+/2.14/gtk+-bundle_2.14.7-20090119_win32.zip"
download "${cache}" "${gnome_base_url}/win32/intltool/0.40/${intltool}.zip"
download "${cache}" "${mingw_gcc44_url}/${gcc_core44}.tar.gz/download"
download "${cache}" "${pidgin_base_url}/${gtkspell}.tar.bz2"
download "${cache}" "${pidgin_base_url}/cyrus-sasl-2.1.26_daa1.tar.gz"
download "${cache}" "${pidgin_base_url}/enchant_1.6.0_win32.zip"
download "${cache}" "${pidgin_base_url}/libxml2-2.9.2_daa1.tar.gz"
download "${cache}" "${pidgin_base_url}/meanwhile-1.0.2_daa3-win32.zip"
download "${cache}" "${pidgin_base_url}/nss-3.20.1-nspr-4.10.10.tar.gz"
download "${cache}" "${pidgin_base_url}/perl-${perl_version}.tar.gz"
download "${cache}" "${pidgin_base_url}/silc-toolkit-1.1.12.tar.gz"
download "${cache}" "${pidgin_base_url}/${pidgin_inst_deps}.tar.gz"
download "${cache}" "http://strawberryperl.com/download/${perl_version}/${perl}.zip"
download "${cache}" "http://nsis.sourceforge.net/mediawiki/images/1/1c/Nsisunz.zip"
download "${cache}" "http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/${nsis}.zip/download"
echo

# Extract GCC
step "Extracting MinGW GCC"
for tarball in "${cache}/${mingw}/"*".tar.lzma"; do
    extract lzma "${win32}/${mingw}" "$tarball"
done
echo

# Extract Pidgin
step "Extracting Pidgin source code"
extract bzip2 "$devroot" "${cache}/pidgin-${pidgin_version}.tar.bz2" && info 'Extracted to' "$source_directory"
echo 'MONO_SIGNCODE = echo ***Bypassing signcode***' >  "${source_directory}/local.mak"
echo 'GPG_SIGN = echo ***Bypassing gpg***'           >> "${source_directory}/local.mak"
patch -p2 --directory "${source_directory}" < "$(dirname "$0")/pidgin-${pidgin_version}.patch"
[[ "${system}" = Msys ]] && patch -p2 --directory "${source_directory}" < "$(dirname "$0")/pidgin-wget-msys.patch"
echo

# LibSSP sources
step "Creating LibSSP source tarball"
cd "${win32}/${mingw}"
extract bzip2 "${gcc_source}/libssp-src" "${gcc_source}/gcc-4.7.2.tar.bz2" gcc-4.7.2/{libssp,COPYING3,COPYING.RUNTIME}
tar --directory "${gcc_source}/libssp-src/gcc-4.7.2" -czf bin/libssp-src.tar.gz .
rm -r "${gcc_source}"
cd - > /dev/null
echo

# Extract dependencies
step "Extracting build dependencies"
extract gzip   "${win32}"                 "${cache}/${pidgin_inst_deps}.tar.gz"
extract gzip   "${win32}"                 "${cache}/libxml2-2.9.2_daa1.tar.gz"
extract bsdtar "${win32}"                 "${cache}/cyrus-sasl-2.1.26_daa1.tar.gz"
extract bsdtar "${win32}"                 "${cache}/nss-3.20.1-nspr-4.10.10.tar.gz"
extract bsdtar "${win32}"                 "${cache}/perl-${perl_version}.tar.gz"
extract bsdtar "${win32}"                 "${cache}/silc-toolkit-1.1.12.tar.gz"
extract bzip2  "${win32}"                 "${cache}/${gtkspell}.tar.bz2"
extract zip    "${win32}"                 "${cache}/meanwhile-1.0.2_daa3-win32.zip"
extract zip    "${win32}"                 "${cache}/enchant_1.6.0_win32.zip"
extract zip    "${win32}"                 "${cache}/${nsis}.zip"
extract zip    "${win32}/${nsis}/Plugins" "${cache}/Nsisunz.zip" nsisunz/Release/nsisunz.dll
extract zip    "${win32}/${perl_dir}"     "${cache}/${perl}.zip"
extract zip    "${win32}/gettext-0.17"    "${cache}/gettext-runtime-0.17-1.zip"
extract zip    "${win32}/gettext-0.17"    "${cache}/gettext-tools-0.17.zip"
extract zip    "${win32}/gtk_2_0-2.14"    "${cache}/gtk+-bundle_2.14.7-20090119_win32.zip"
extract zip    "${win32}/${intltool}"     "${cache}/${intltool}.zip"
extract gzip   "${win32}/${gcc_core44}"   "${cache}/${gcc_core44}.tar.gz"
info "Installing" "SHA1 plugin for NSIS"; cp "${win32}/${pidgin_inst_deps}/SHA1Plugin.dll" "${win32}/${nsis}/Plugins"
echo

# Finishing
if [[ "${system}" = Cygwin ]]; then
    step "Setting executable permissions"
    info "Setting permission" "for exe files"; find "${win32}" -type f -name '*.exe' | xargs chmod +x
    info "Setting permission" "for dll files"; find "${win32}" -type f -name '*.dll' | xargs chmod +x
else
    step "Checking for GnuPG"
    if available gpg
        then info 'GnuPG found at' $(which gpg)
        else warn 'could not find gpg in system path'
    fi
fi
echo
