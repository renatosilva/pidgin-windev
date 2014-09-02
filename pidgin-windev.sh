#!/bin/bash

##
##    Pidgin Windows Development Setup 2014.8.2
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
## install the Bonjour SDK if you want to enable such protocol, and also GnuPG
## if using MinGW MSYS. You will be given more details when I finish. I was
## designed to run under MSYS2 with the pacman command available, or under MinGW
## MSYS with mingw-get.
##
## I am going to create a buildbox containing specific versions of GCC, Perl and
## NSIS, along with Pidgin build dependencies. After running me and finishing
## the manual steps you can configure system path with --path and then be able
## to build Pidgin (Pidgin++ configures path automatically).
##
## NOTES: source code tarball for 2.10.9 cannot be built on MinGW MSYS without
## patching, or without some wget version newer than 1.12. Also, if you want to
## sign the installers, you will need to follow the manual instructions.
##
## Usage:
##     @script.name [options] DEVELOPMENT_ROOT
##
##     -g, --system-gcc    Do not include custom GCC in --path.
##     -p, --path          Print system path configuration for evaluation after
##                         the build environment has been created. This will
##                         allow you to start compilation.
##
##     -w, --which-pidgin  Show the minimum Pidgin and Pidgin++ versions this
##                         script creates an environment for. Newer versions
##                         will also compile if not requiring any environment
##                         changes.
##
##         --for=VARIANT   The Pidgin variant for which a build environment will
##                         be created, either "pidgin" (default) or "pidgin++".
##         --version=SPEC  Specify a version other than --which-pidgin. For
##                         Pidgin++, SPEC can also be "devel" for the latest
##                         development revision or "devel:revision" for specific
##                         one, Bazaar being required in either case.
##     -n, --no-source     Do not retrieve the source code for Pidgin/Pidgin++
##                         itself. Use this if you already have the source code.
##
##     -c, --no-color      Disable colored output.
##     -l, --link-to-me    Also create an NTFS symlink to this script under
##                         DEVELOPMENT_ROOT/win32-dev/@script.name. This
##                         requires administrative privileges.
##


# Parse options
eval "$(from="$0" easyoptions.rb "$@"; echo result=$?)"


# Output formatting
if [[ -t 1 && -z "$no_color" ]]; then
    red="\e[38;05;9m"
    green="\e[0;32m"
    blue="\e[38;05;32m"
    yellow="\e[38;05;226m"
    purple="\e[38;05;165m"
    normal="\e[0m"
fi
step() { printf "${green}$1${normal}\n"; }
info() { printf "$1${2:+ ${purple}$2${normal}}\n"; }
warn() { printf "${1:+${yellow}Warning:${normal} $1}\n"; }
oops() { printf "${red}Error:${normal} $1\n"; }


# Pidgin versions
pidgin_version="2.10.9"
plus_plus_version="2.10.9-RS245"
if [[ -n "$which_pidgin" ]]; then
    [[ "$pidgin_version" = *.next ]] && pidgin_prefix="next version following "
    [[ "$plus_plus_version" = *.next ]] && plus_plus_prefix="next version following "
    info "Pidgin is" "${pidgin_prefix}${pidgin_version%.next}"
    info "Pidgin++ is" "${plus_plus_prefix}${plus_plus_version%.next}"
    exit
fi


# MSYS or MSYS2 required
case $(uname -or) in
    1.*Msys) system="MSYS1" ;;
    2.*Msys) system="MSYS2" ;;
    *) echo "Incompatible environment: $(uname -o) $(uname -r)."
       echo "This script must be executed under MSYS2 or MinGW MSYS, see --help."
       exit 1
esac


# Pidgin variant
see_help="See --help for usage and options."
[[ "$version" = devel || "$version" = devel:* ]] && development_revision="yes"
if [[ -n "$for" && "$for" != "pidgin" && "$for" != "pidgin++" ]]; then
    echo "Unrecognized Pidgin variant: \`$for'."
    echo "$see_help"
    exit 1
fi
if [[ "$for" = "pidgin++" ]]; then
    pidgin_plus_plus="yes"
    pidgin_variant="Pidgin++"
    pidgin_variant_version="${version:-$plus_plus_version}"
    [[ "$plus_plus_version" = *.next ]] && next_plus_plus="yes"
else
    if [[ -n "$development_revision" ]]; then
        echo "Development revisions are only supported for Pidgin++."
        echo "$see_help"
        exit 1
    fi
    pidgin_variant="Pidgin"
    pidgin_variant_version="${version:-$pidgin_version}"
    [[ "$pidgin_version" = *.next ]] && next_pidgin="yes"
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


# Mutually exclusive options
if [[ -n "$version" && -n "$no_source" ]]; then
    echo "A version can only be specified when downloading the source code."
    echo "$see_help"
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
    step "Creating new development root"
    info "Location:" "$devroot"
    info
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

pidgin_base_url="https://developer.pidgin.im/static/win32"
gnome_base_url="http://ftp.gnome.org/pub/gnome/binaries/win32"
mingw_base_url="http://sourceforge.net/projects/mingw/files/MinGW/Base"
mingw_gcc44_url="$mingw_base_url/gcc/Version4/Previous%20Release%20gcc-4.4.0"
mingw_pthreads_url="$mingw_base_url/pthreads-w32/pthreads-w32-2.9.0-pre-20110507-2"
xmlstarlet_base_url="http://sourceforge.net/projects/xmlstar/files/xmlstarlet"
packages="bzip2 libiconv msys-make msys-patch msys-zip msys-unzip msys-bsdtar msys-wget msys-libopenssl msys-coreutils"

installing_packages="Installing some $system packages"
downloading_mingw="Downloading specific MinGW GCC"
downloading_pidgin="Downloading $pidgin_variant source code"
downloading_dependencies="Downloading build dependencies"
extracting_mingw="Extracting MinGW GCC"
extracting_pidgin="Extracting $pidgin_variant source code"
extracting_dependencies="Extracting build dependencies"
creating_symlink="Creating symlink to this script"

if [[ -n "$pidgin_plus_plus" ]]; then
    gtk_bundle_version="2.24"
    gtk_bundle="gtk+-bundle_${gtk_bundle_version}.10-20120208_win32.zip"
else
    gtk_bundle_version="2.14"
    gtk_bundle="gtk+-bundle_${gtk_bundle_version}.7-20090119_win32.zip"
fi


# Functions
available() {
    which "$1" > /dev/null 2>&1
    return $?
}

download() {
    error_handler="$3"
    available "$4" && return
    filename="${1%/download}"
    filename="${filename##*/}"
    file="$2/$filename"
    info "Fetching" "$filename"
    [[ -f "$file" && ! -s "$file" ]] && rm "$file"
    [[ "$system" = MSYS1 ]] && cert_args="--no-check-certificate"
    [[ ! -e "$file" ]] && { wget $cert_args --quiet --output-document "$file" "$1" || ${error_handler:-oops} "failed downloading from $1"; }
}

extract() {
    format="$1"
    compressed="$2"
    directory="$3"
    file="$4"
    compressed_name="${compressed##*/}"
    info "Extracting" "$compressed_name"
    case "$format" in
        bsdtar)  bsdtar -xzf "$compressed" --directory "$directory" ;;
        zip)     unzip -qo${file:+j} "$compressed" $file -d "$directory" ;;
        lzma)    tar --lzma -xf "$compressed" --directory "$directory" ;;
        gzip)    tar -xzf "$compressed" --directory "$directory" ;;
        bzip2)   tar -xjf "$compressed" --directory "$directory" ;;
    esac
}

install() {
    package="$1"
    case "$system" in
    MSYS1) info "Checking" "$package"
           mingw-get install "$package" 2> /dev/null || oops "failed installing $package" ;;
    MSYS2) package="${package#msys-}"
           info "Checking" "$package"
           pacman --noconfirm --sync --needed "$package" > /dev/null 2>&1 || oops "failed installing $package" ;;
    esac
}


# Path configuration
if [[ -n "$path" ]]; then
    [[ -z "$system_gcc" ]] && custom_gcc="$win32/$mingw/bin:"
    echo "export PATH=\"${custom_gcc}$win32/$perl/perl/bin:$win32/$nsis:$win32:$PATH\""
    exit
fi


# Install what is possible with package manager
step "$installing_packages"
for package in $packages; do install "$package"; done
[[ -n "$pidgin_plus_plus" && "$system" = MSYS2 ]] && ! available 7z && install "p7zip"
echo


# Download GCC
mkdir -p "$cache/$mingw"
if [[ -z "$system_gcc" ]]; then
    step "$downloading_mingw"
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
fi


# Download Pidgin
if [[ -z "$no_source" ]]; then
    step "$downloading_pidgin"
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
                    warn "target directory already exists but is not a Bazaar branch:"
                    info "$source_directory"
                else
                    info "Updating already existing Bazaar repository" "$source_directory"
                    bzr pull --quiet --directory "$source_directory" "$url" || warn "failed updating repository"
                fi
            else
                # Create
                info "Cloning Bazaar repository"
                info "From:" "$url"
                info "Into:" "$source_directory"
                bzr branch --revision "$revision" "$url" "$source_directory" || warn "failed cloning repository"
            fi
        else
            # Source release
            plus_plus_milestone=$(echo "$pidgin_variant_version" | tr [:upper:] [:lower:])
            download "https://launchpad.net/pidgin++/trunk/$plus_plus_milestone/+download/Pidgin $pidgin_variant_version Source.zip" "$cache" warn
            source_directory="$devroot/pidgin-$pidgin_variant_version"
        fi
    else
        # Pidgin
        download "prdownloads.sourceforge.net/pidgin/pidgin-$pidgin_variant_version.tar.bz2" "$cache" warn
        source_directory="$devroot/pidgin-$pidgin_variant_version"
    fi
    echo
fi


# Download dependencies
step "$downloading_dependencies"
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
    "$gnome_base_url/gtk+/$gtk_bundle_version/$gtk_bundle"                                           \
    "$gnome_base_url/dependencies/libxml2_2.9.0-1_win32.zip"                                         \
    "$gnome_base_url/dependencies/gettext-runtime-0.17-1.zip"                                        \
    "$gnome_base_url/intltool/0.40/intltool_0.40.4-1_win32.zip"                                      \
    "$gnome_base_url/dependencies/libxml2-dev_2.9.0-1_win32.zip"                                     \
    "http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/$nsis.zip/download"                    \
    "http://nsis.sourceforge.net/mediawiki/images/1/1c/Nsisunz.zip"                                  \
    "http://strawberryperl.com/download/$perl_version/$perl.zip"                                     \
    "$mingw_gcc44_url/$gcc_core44.tar.gz/download"                                                   \
; do download "$build_dependency" "$cache"; done

if [[ -n "$pidgin_plus_plus" ]]; then
    download "http://nsis.sourceforge.net/mediawiki/images/c/c9/Inetc.zip" "$cache"
    download "https://github.com/vslavik/winsparkle/releases/download/v0.3/WinSparkle-0.3.zip" "$cache"
    download "$xmlstarlet_base_url/1.6.0/xmlstarlet-1.6.0-win32.zip/download" "$cache" oops xmlstarlet
    download "http://win32builder.gnome.org/packages/3.6/gettext-dev_0.18.2.1-1_win32.zip" "$cache"
fi
echo


# Extract GCC
mkdir -p "$win32/$mingw"
if [[ -z "$system_gcc" ]]; then
    step "$extracting_mingw"
    for tarball in "$cache/$mingw/"*".tar.lzma"; do
        extract lzma "$tarball" "$win32/$mingw"
    done
    echo
fi


# Extract Pidgin
if [[ -z "$no_source" && -z "$development_revision" ]]; then
    step "$extracting_pidgin"
    if [[ -n "$pidgin_plus_plus" ]]; then
        extract zip "$cache/Pidgin $pidgin_variant_version Source.zip" "$devroot" && info "Extracted to" "$source_directory"
    else
        extract bzip2 "$cache/pidgin-$pidgin_variant_version.tar.bz2" "$devroot" && info "Extracted to" "$source_directory"
        echo "MONO_SIGNCODE = echo ***Bypassing signcode***" >  "$source_directory/${pidgin_plus_plus:+source/}local.mak"
        echo "GPG_SIGN = echo ***Bypassing gpg***"           >> "$source_directory/${pidgin_plus_plus:+source/}local.mak"
    fi
    echo
fi


# Create link to this script
if [[ -n "$link_to_me" ]]; then
    step "$creating_symlink"
    filename="$(basename $BASH_SOURCE)"
    if [[ -f "$win32/$filename" ]]; then
        info "Ignoring already existing file" "$win32/$filename"
    else
        cd $(dirname "$BASH_SOURCE")
        target="$(pwd -W | tr / \\\\)\\$filename"
        target_unix="$(pwd)/$filename"
        cd - > /dev/null
        cd "$win32"
        info "From:" "$win32/$filename"
        info "To:" "$target_unix"
        cmd //c mklink "$filename" "$target" ">" NUL "&&" echo "NTFS" "symlink" "created."
        cd - > /dev/null
    fi
    echo
fi


# Extract dependencies
step "$extracting_dependencies"
extract zip "$cache/intltool_0.40.4-1_win32.zip"              "$win32/intltool_0.40.4-1_win32"
extract zip "$cache/$gtk_bundle"                              "$win32/gtk_2_0-$gtk_bundle_version"
extract zip "$cache/gettext-tools-0.17.zip"                   "$win32/gettext-0.17"
extract zip "$cache/gettext-runtime-0.17-1.zip"               "$win32/gettext-0.17"
extract zip "$cache/libxml2_2.9.0-1_win32.zip"                "$win32/libxml2-2.9.0"
extract zip "$cache/libxml2-dev_2.9.0-1_win32.zip"            "$win32/libxml2-2.9.0"
extract zip "$cache/$perl.zip"                                "$win32/$perl"
extract zip "$cache/$nsis.zip"                                "$win32"
extract zip "$cache/meanwhile-1.0.2_daa3-win32.zip"           "$win32"
extract zip "$cache/enchant_1.6.0_win32.zip"                  "$win32"
extract zip "$cache/Nsisunz.zip"                              "$win32/$nsis/Plugins" "nsisunz/Release/nsisunz.dll"

if [[ -n "$pidgin_plus_plus" ]]; then
    extract zip "$cache/WinSparkle-0.3.zip" "$win32"
    extract zip "$cache/Inetc.zip" "$win32/$nsis/Plugins/" "Plugins/inetc.dll"
    extract zip "$cache/gettext-dev_0.18.2.1-1_win32.zip" "$win32/gtk_2_0-2.24"
    if ! available xmlstarlet; then
        extract zip "$cache/xmlstarlet-1.6.0-win32.zip" "$win32" "xmlstarlet-1.6.0/xml.exe"
        mv "$win32/xml.exe" "$win32/xmlstarlet.exe"
    fi
fi

mkdir -p "$win32/$gcc_core44"
extract gzip "$cache/$gcc_core44.tar.gz" "$win32/gcc-core-4.4.0-mingw32-dll"
extract bzip2 "$cache/gtkspell-2.0.16.tar.bz2" "$win32"

for tarball in "$cache/"*".tar.gz"; do
    [[ "$tarball" = *"gcc-core-4.4.0-mingw32-dll.tar.gz" ]] && continue
    extract bsdtar "$tarball" "$win32"
done
info "Installing" "the NSIS SHA1 plugin"
cp "$win32/pidgin-inst-deps-20130214/SHA1Plugin.dll" "$win32/$nsis/Plugins/"
echo


# Finishing
if [[ -n "$no_source" ]]; then
    echo "Finished, remaining manual steps are:"
else
    echo "Finished, below are the remaining manual steps. After these you should be able"
    echo "to build $pidgin_variant from the created source code directory."
    echo
fi

gnupg="Install GnuPG and make it available from PATH."
bonjour="Install the Bonjour SDK under $win32/Bonjour_SDK.${pidgin_plus_plus:+
   This is only required if you want to enable the Bonjour protocol, otherwise
   you can tell the build script of Pidgin++ to disable it.}"
sevenzip="Install 7-Zip and make it available from PATH. This step is only required if
   you want to build the GTK+ bundle, which requires extraction of RPM packages."

case "$system" in
MSYS2) echo "1. $bonjour"
       echo ;;
MSYS1) echo "1. $gnupg"
       echo "2. $bonjour"
       echo "${pidgin_plus_plus:+3. $sevenzip}" ;;
esac
