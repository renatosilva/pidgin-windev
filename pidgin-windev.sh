#!/bin/bash

##
##    Pidgin Windows Development Setup 2015.2.11
##    Copyright 2012-2015 Renato Silva
##    GPLv2 licensed
##
## This script is supposed to set up a Windows build environment for Pidgin or
## Pidgin++ in one single shot, without the long manual steps described at
## http://developer.pidgin.im/wiki/BuildingWinPidgin. These steps are
## automatically executed, except for GnuPG installation when using MinGW MSYS.
##
## When this script is executed under MinGW MSYS a build environment for Pidgin
## is created, when executed under MSYS2 a Pidgin++ environment is created
## instead. For Pidgin, after running this tool and finishing the manual steps
## you can configure system path with --path and then be able to start building.
## Pidgin++ does this automatically.
##
## Usage:
##     @script.name [options] DEVELOPMENT_ROOT
##
##     -p, --path          Print system path configuration for evaluation after
##                         the build environment has been created. This will
##                         allow you to start compilation.
##
##     -w, --which-pidgin  Show the minimum Pidgin and Pidgin++ versions this
##                         script creates an environment for. Newer versions
##                         will also compile if not requiring any environment
##                         changes.
##
##         --version=SPEC  Specify a version other than --which-pidgin. For
##                         Pidgin++, SPEC can also be "devel" for the latest
##                         development revision or "devel:revision" for specific
##                         one, Bazaar being required in either case.
##
##     -n, --no-source     Do not retrieve the source code for Pidgin/Pidgin++
##                         itself. Use this if you already have the source code.
##
##     -l, --link-to-me    Also create an NTFS symlink to this script under
##                         DEVELOPMENT_ROOT/win32-dev/@script.name. This
##                         requires administrative privileges.
##
##     -c, --no-color      Disable colored output.
##     -v, --verbose       Verbose output.
##

source easyoptions || exit
plus_plus_version="15.1"
pidgin_version="2.10.11.next"

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

# Pidgin versions
if [[ -n "$which_pidgin" ]]; then
    [[ "$pidgin_version" = *.next ]] && pidgin_prefix="next version following "
    [[ "$plus_plus_version" = *.next ]] && plus_plus_prefix="next version following "
    echo "Pidgin is ${pidgin_prefix}${pidgin_version%.next}"
    echo "Pidgin++ is ${plus_plus_prefix}${plus_plus_version%.next}"
    exit
fi

# MSYS or MSYS2 required
case $(uname -or) in
    1.*Msys) system="MSYS1" ;;
    2.*Msys) system="MSYS2" ;;
    *) oops "incompatible environment $(uname -o) $(uname -r)"
esac

# Pidgin variant
[[ "$version" = devel || "$version" = devel:* ]] && development_revision="yes"
if [[ "$system" = MSYS2 ]]; then
    [[ "$plus_plus_version" = *.next ]] && next_plus_plus="yes"
    pidgin_variant_version="${version:-$plus_plus_version}"
    pidgin_variant="Pidgin++"
    pidgin_plus_plus="yes"
else
    [[ -n "$development_revision" ]] && oops "development revisions are only supported for Pidgin++"
    [[ "$pidgin_version" = *.next ]] && next_pidgin="yes"
    pidgin_variant_version="${version:-$pidgin_version}"
    pidgin_variant="Pidgin"
fi

# Under development
if [[ -z "$no_source" ]]; then
    if [[ -n "$next_pidgin" ]]; then
        echo "This script is under development for the next version of Pidgin following"
        echo "${pidgin_version%.next} and currently can only create a build environment for some specific"
        echo "development revision from the source code repository. You need to either"
        echo "specify --no-source or use a previous version of this script."
        exit 1
    elif [[ -n "$next_plus_plus" && "$version" != devel ]]; then
        echo "This script is under development for the next version of Pidgin++ following"
        echo "${plus_plus_version%.next} and currently can only create a build environment for the"
        echo "latest development revision from source code repository. You need to specify"
        echo "either --version=devel or --no-source."
        exit 1
    fi
fi

# Some validation
devroot="${arguments[0]}"
[[ -n "$version" && -n "$no_source" ]] && oops "a version can only be specified when downloading the source code"
[[ -f "$devroot" ]] && oops "the existing development root is not a directory: \"$devroot\""
[[ -z "$devroot" ]] && oops "a development root must be specified"

# Development root
if [[ ! -e "$devroot" ]]; then
    step "Creating new development root"
    info "Location:" "$devroot"
    info; mkdir -p "$devroot"
fi
cd "$devroot"
devroot=$(readlink -m "$(pwd)")
[[ $? != 0 ]] && oops "failed to get absolute path for $devroot"
cd - > /dev/null

# Configuration
cache="$devroot/downloads"
win32="$devroot/win32-dev"
nsis="nsis-2.46"
mingw="mingw-gcc-4.7.2"
gtkspell="gtkspell-2.0.16"
gcc_core44="gcc-core-4.4.0-mingw32-dll"
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

download() {
    filename="${2%/download}"
    filename="${filename##*/}"
    info "Fetching" "$filename"
    file="$1/$filename"
    mkdir -p "$1"
    [[ -f "$file" && ! -s "$file" ]] && rm "$file"
    [[ "$system" = MSYS1 ]] && cert_args="--no-check-certificate"
    [[ ! -e "$file" ]] && { wget $cert_args --quiet --output-document "$file" "$2" || oops "failed downloading from $2"; }
}

extract() {
    format="$1"
    directory="$2"
    compressed="$3"
    file="$4"
    compressed_name="${compressed##*/}"
    info "Extracting" "${file:+${file##*/} from }${compressed_name}"
    mkdir -p "$directory"
    case "$format" in
        bsdtar)  bsdtar -xzf          "$compressed"  --directory "$directory" ;;
        lzma)    tar --lzma -xf       "$compressed"  --directory "$directory" ;;
        bzip2)   tar -xjf             "$compressed"  --directory "$directory" ;;
        gzip)    tar -xzf             "$compressed"  --directory "$directory" ;;
        zip)     unzip -qo${file:+j}  "$compressed"     $file -d "$directory" ;;
    esac || exit
}

install() {
    package="$1"
    error="failed installing $package"
    if [[ -n "$verbose" ]]
        then device="/dev/stdout"; step "Checking $package"
        else device="/dev/null";   info "Checking" "$package"
    fi
    case "$system" in
        MSYS1)      mingw-get install "$package" --verbose=0 > "$device" 2>&1 || oops "$error"; printf "${verbose:+\n}" ;;
        MSYS2) pacman --needed --sync "$package" --noconfirm > "$device" 2>&1 || oops "$error"; printf "${verbose:+\n}" ;;
    esac
}

# Path configuration
if [[ -n "$path" ]]; then
    case "$system" in
        MSYS1) echo "export PATH=\"$win32:$win32/$nsis:$win32/$mingw/bin:$win32/$perl_dir/perl/bin:$PATH\"" ;;
        MSYS2) echo "export PATH=\"$win32:$win32/$nsis:$PATH\"" ;;
    esac
    exit
fi

# Install what is possible with package manager
[[ -z "$verbose" ]] && step "Installing the necessary packages"
if [[ "$system" = MSYS2 ]]; then
    install "base-devel"
    install "bsdtar"
    install "bzip2"
    install "coreutils"
    install "libiconv"
    install "libopenssl"
    install "rsync"
    install "unzip"
    install "zip"
    for architecture in i686 x86_64; do
        install "mingw-w64-${architecture}-cyrus-sasl"
        install "mingw-w64-${architecture}-drmingw"
        install "mingw-w64-${architecture}-gcc"
        install "mingw-w64-${architecture}-gtk2"
        install "mingw-w64-${architecture}-gtkspell"
        install "mingw-w64-${architecture}-libxml2"
        install "mingw-w64-${architecture}-meanwhile"
        install "mingw-w64-${architecture}-nspr"
        install "mingw-w64-${architecture}-nss"
        install "mingw-w64-${architecture}-perl"
        install "mingw-w64-${architecture}-silc-toolkit"
        install "mingw-w64-${architecture}-xmlstarlet"
    done
else
    install "mingw32-bzip2"
    install "mingw32-libiconv"
    install "msys-bsdtar"
    install "msys-coreutils"
    install "msys-libopenssl"
    install "msys-make"
    install "msys-patch"
    install "msys-unzip"
    install "msys-wget"
    install "msys-zip"
fi
[[ -z "$verbose" ]] && echo

# Download GCC
if [[ "$system" = MSYS1 ]]; then
    step "Downloading specific MinGW GCC"
    download "$cache/$mingw" "$mingw_base_url/binutils/binutils-2.23.1/binutils-2.23.1-1-mingw32-bin.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/gcc-core-4.7.2-1-mingw32-bin.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libgcc-4.7.2-1-mingw32-dll-1.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libgomp-4.7.2-1-mingw32-dll-1.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libquadmath-4.7.2-1-mingw32-dll-0.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gcc/Version4/gcc-4.7.2-1/libssp-4.7.2-1-mingw32-dll-0.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gettext/gettext-0.18.1.1-2/libintl-0.18.1.1-2-mingw32-dll-8.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gmp/gmp-5.0.1-1/gmp-5.0.1-1-mingw32-dev.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/gmp/gmp-5.0.1-1/libgmp-5.0.1-1-mingw32-dll-10.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dev.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dll-2.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/mingwrt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dev.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/mingwrt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dll.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/mpc/mpc-0.8.1-1/libmpc-0.8.1-1-mingw32-dll-2.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/mpc/mpc-0.8.1-1/mpc-0.8.1-1-mingw32-dev.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/mpfr/mpfr-2.4.1-1/libmpfr-2.4.1-1-mingw32-dll-1.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/mpfr/mpfr-2.4.1-1/mpfr-2.4.1-1-mingw32-dev.tar.lzma/download"
    download "$cache/$mingw" "$mingw_base_url/w32api/w32api-3.17/w32api-3.17-2-mingw32-dev.tar.lzma/download"
    download "$cache/$mingw" "$mingw_pthreads_url/libpthreadgc-2.9.0-mingw32-pre-20110507-2-dll-2.tar.lzma/download"
    download "$cache/$mingw" "$mingw_pthreads_url/pthreads-w32-2.9.0-mingw32-pre-20110507-2-dev.tar.lzma/download"
    echo
fi

# Download Pidgin or Pidgin++
if [[ -z "$no_source" ]]; then
    step "Downloading $pidgin_variant source code"
    if [[ -n "$pidgin_plus_plus" ]]; then
        # Pidgin++
        if [[ -n "$development_revision" ]]; then
            # Bazaar branch
            case "$version" in
                devel)    revision="last:1" ;;
                devel:*)  revision="${version#devel:}" ;;
            esac
            url="http://bazaar.launchpad.net/~renatosilva/pidgin++/trunk"
            source_directory="$devroot/pidgin++"
            if [[ -d "$source_directory" ]]; then
                # Update
                if [[ ! -d "$source_directory/.bzr" ]]; then
                    oops "target directory already exists but is not a Bazaar branch:"
                    info "$source_directory"
                else
                    info "Updating already existing Bazaar repository" "$source_directory"
                    bzr pull --quiet --directory "$source_directory" "$url" || oops "failed updating repository"
                fi
            else
                # Create
                info "Cloning Bazaar repository"
                info "From:" "$url"
                info "Into:" "$source_directory"
                bzr branch --revision "$revision" "$url" "$source_directory" || oops "failed cloning repository"
            fi
        else
            # Source release
            plus_plus_milestone=$(echo "$pidgin_variant_version" | tr [:upper:] [:lower:])
            download "$cache" "https://launchpad.net/pidgin++/trunk/$plus_plus_milestone/+download/Pidgin++ $pidgin_variant_version Source.zip"
            source_directory="$devroot/pidgin++_$pidgin_variant_version"
        fi
    else
        # Pidgin
        download "$cache" "prdownloads.sourceforge.net/pidgin/pidgin-$pidgin_variant_version.tar.bz2"
        source_directory="$devroot/pidgin-$pidgin_variant_version"
    fi
    echo
fi

# Download dependencies
step "Downloading build dependencies"
if [[ "$system" = MSYS2 ]]; then
    download "$cache" "https://github.com/vslavik/winsparkle/releases/download/v0.4/WinSparkle-0.4.zip"
else
    download "$cache" "$gnome_base_url/win32/dependencies/gettext-runtime-0.17-1.zip"
    download "$cache" "$gnome_base_url/win32/dependencies/gettext-tools-0.17.zip"
    download "$cache" "$gnome_base_url/win32/gtk+/2.14/gtk+-bundle_2.14.7-20090119_win32.zip"
    download "$cache" "$gnome_base_url/win32/intltool/0.40/$intltool.zip"
    download "$cache" "$mingw_gcc44_url/$gcc_core44.tar.gz/download"
    download "$cache" "$pidgin_base_url/$gtkspell.tar.bz2"
    download "$cache" "$pidgin_base_url/cyrus-sasl-2.1.26_daa1.tar.gz"
    download "$cache" "$pidgin_base_url/enchant_1.6.0_win32.zip"
    download "$cache" "$pidgin_base_url/libxml2-2.9.2_daa1.tar.gz"
    download "$cache" "$pidgin_base_url/meanwhile-1.0.2_daa3-win32.zip"
    download "$cache" "$pidgin_base_url/nss-3.17.3-nspr-4.10.7.tar.gz"
    download "$cache" "$pidgin_base_url/perl-$perl_version.tar.gz"
    download "$cache" "$pidgin_base_url/silc-toolkit-1.1.12.tar.gz"
    download "$cache" "$pidgin_base_url/$pidgin_inst_deps.tar.gz"
    download "$cache" "http://strawberryperl.com/download/$perl_version/$perl.zip"
fi
download "$cache" "http://nsis.sourceforge.net/mediawiki/images/1/1c/Nsisunz.zip"
download "$cache" "http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/$nsis.zip/download"
echo

# Extract GCC
if [[ "$system" = MSYS1 ]]; then
    step "Extracting MinGW GCC"
    for tarball in "$cache/$mingw/"*".tar.lzma"; do
        extract lzma "$win32/$mingw" "$tarball"
    done
    echo
fi

# Extract Pidgin
if [[ -z "$no_source" && -z "$development_revision" ]]; then
    step "Extracting $pidgin_variant source code"
    if [[ -n "$pidgin_plus_plus" ]]; then
        extract zip "$devroot" "$cache/Pidgin++ $pidgin_variant_version Source.zip" && info "Extracted to" "$source_directory"
    else
        extract bzip2 "$devroot" "$cache/pidgin-$pidgin_variant_version.tar.bz2" && info "Extracted to" "$source_directory"
        echo "MONO_SIGNCODE = echo ***Bypassing signcode***" >  "$source_directory/${pidgin_plus_plus:+source/}local.mak"
        echo "GPG_SIGN = echo ***Bypassing gpg***"           >> "$source_directory/${pidgin_plus_plus:+source/}local.mak"
    fi
    echo
fi

# Create link to this script
if [[ -n "$link_to_me" ]]; then
    step "Creating symlink to this script"
    filename="$(basename $BASH_SOURCE)"
    if [[ -f "$win32/$filename" ]]; then
        info "Ignoring already existing file" "$win32/$filename"
    else
        cd $(dirname "$BASH_SOURCE")
        target="$(pwd -W | tr / \\\\)\\$filename"
        target_unix="$(pwd)/$filename"
        cd - > /dev/null
        mkdir -p "$win32"
        cd "$win32"
        info "From:" "$win32/$filename"
        info "To:" "$target_unix"
        cmd //c mklink "$filename" "$target" ">" NUL "&&" echo "NTFS" "symlink" "created."
        cd - > /dev/null
    fi
    echo
fi

# Extract dependencies
step "Extracting build dependencies"
extract zip "$win32" "$cache/$nsis.zip"
extract zip "$win32/$nsis/Plugins" "$cache/Nsisunz.zip" nsisunz/Release/nsisunz.dll
if [[ "$system" = MSYS2 ]]; then
    extract zip "$win32" "$cache/WinSparkle-0.4.zip"
    rm "$win32/WinSparkle-0.4/Release/WinSparkle.lib"
    rm "$win32/WinSparkle-0.4/x64/Release/WinSparkle.lib"
else
    extract gzip   "$win32"               "$cache/$pidgin_inst_deps.tar.gz"
    extract gzip   "$win32"               "$cache/libxml2-2.9.2_daa1.tar.gz"
    extract bsdtar "$win32"               "$cache/cyrus-sasl-2.1.26_daa1.tar.gz"
    extract bsdtar "$win32"               "$cache/nss-3.17.3-nspr-4.10.7.tar.gz"
    extract bsdtar "$win32"               "$cache/perl-$perl_version.tar.gz"
    extract bsdtar "$win32"               "$cache/silc-toolkit-1.1.12.tar.gz"
    extract bzip2  "$win32"               "$cache/$gtkspell.tar.bz2"
    extract zip    "$win32"               "$cache/meanwhile-1.0.2_daa3-win32.zip"
    extract zip    "$win32"               "$cache/enchant_1.6.0_win32.zip"
    extract zip    "$win32/$perl_dir"     "$cache/$perl.zip"
    extract zip    "$win32/gettext-0.17"  "$cache/gettext-runtime-0.17-1.zip"
    extract zip    "$win32/gettext-0.17"  "$cache/gettext-tools-0.17.zip"
    extract zip    "$win32/gtk_2_0-2.14"  "$cache/gtk+-bundle_2.14.7-20090119_win32.zip"
    extract zip    "$win32/$intltool"     "$cache/$intltool.zip"
    extract gzip   "$win32/$gcc_core44"   "$cache/$gcc_core44.tar.gz"
fi
echo

# Check for GnuPG
step "Checking for GnuPG"
gpg=$(which gpg 2> /dev/null)
if [[ -f "$gpg" ]]
    then info "GnuPG found at" "$gpg"
    else warn "could not find GnuPG in system path"
fi
echo
