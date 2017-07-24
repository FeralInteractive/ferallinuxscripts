#!/bin/bash
# ====================================================================
# The MIT License (MIT)
#
# Copyright (c) 2017 Feral Interactive Limited
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ====================================================================
# Generic Feral Launcher script
# Version 2.5.0

# If you have useful edits made for unsupported distros then please
# visit <https://github.com/FeralInteractive/ferallinuxscripts>

# Extra note: Steam's STEAM_RUNTIME_PREFER_HOST_LIBRARIES can now be
# used to control which libraries it'll use
# See http://store.steampowered.com/news/26953/
# ====================================================================

# 'Magic' to get the game root
GAMEROOT="$(sh -c "cd \"${0%/*}\" && echo \"\$PWD\"")"
FERAL_CONFIG="${GAMEROOT}/config"

# Pull in game specific variables
# This is required - we'll fail without it
# shellcheck source=config/game-settings.sh
. "${FERAL_CONFIG}/game-settings.sh"

# The game's preferences directory
if [ -z "${FERAL_PREFERENCES_DIR}" ]; then FERAL_PREFERENCES_DIR="feral-interactive/${FERAL_GAME_NAME_FULL}"; fi
GAMEPREFS="$HOME/.local/share/${FERAL_PREFERENCES_DIR}"

# ====================================================================
# Helper functions

# Show a message box.
ShowMessage()
{
	MESSAGE_TITLE="$1"
	MESSAGE_BODY="$2"

	echo "=== ${MESSAGE_TITLE}"
	echo "${MESSAGE_BODY}"

	MESSAGE_BINARY="${GAMEROOT}/bin/FeralLinuxMessage"
	if [ -x "${MESSAGE_BINARY}" ]; then
		MESSAGE_BUTTON="OK"
		MESSAGE_ICON="${GAMEROOT}/share/icons/GameIcon_16x16x32.png"
		MESSAGE_FONT="${GAMEROOT}/share/NotoSans-Regular.ttf"
		MESSAGE_DEVICES="${GAMEROOT}/share/inputdevices.json"

		ORIG_LD_PRELOAD="${LD_PRELOAD}"
		if ! grep -q steamos /etc/os-release; then
			unset LD_PRELOAD
		fi

		"${MESSAGE_BINARY}" "${MESSAGE_TITLE}" "${MESSAGE_ICON}" "${MESSAGE_BODY}" "${MESSAGE_FONT}" "${MESSAGE_DEVICES}" 1 2 1 "${MESSAGE_BUTTON}"

		export LD_PRELOAD="${ORIG_LD_PRELOAD}"
	fi
}

# ====================================================================
# Options

# Check for arguments
# Note: some of these can be set at a system level to override for
# all Feral games
while [ $# -gt 0 ]; do
	arg=$1
	case ${arg} in
		--fresh-prefs)   FERAL_FRESH_PREFERENCES=1  && shift ;;
		--system-asound) FERAL_SYSTEM_ASOUND=1      && shift ;;
		--log-to-file)   FERAL_LOG_TO_FILE=1        && shift ;;
		--version)       FERAL_GET_VERSION=1        && shift ;;
		*) break ;;
	esac
done

# Always do this first
if [ "${FERAL_LOG_TO_FILE}" = 1 ]; then
	LOGFILE="${GAMEPREFS}/${FERAL_GAME_NAME}_log.txt"
	echo "Logging all output to \"${LOGFILE}\"..."
	exec 1>> "${LOGFILE}" 2>&1
	echo "==="
	echo "log for $(date)"
	echo "==="
fi

# Automatically backup old preferences and start fresh on launch
if [ "${FERAL_FRESH_PREFERENCES}" = 1 ]; then
	mv "${GAMEPREFS}" "${GAMEPREFS}-$(date +%Y%m%d%H%M%S).bak"
fi

# Show a version panel on start
if [ "${FERAL_GET_VERSION}" = 1 ]; then
	unset LD_PRELOAD
	unset LD_LIBRARY_PATH
	if [ -x /usr/bin/zenity ]; then
		/usr/bin/zenity --text-info --title "${FERAL_GAME_NAME_FULL} - Version Information" --filename "${GAMEROOT}/share/FeralInfo.json"
	else
		xterm -T "${FERAL_GAME_NAME_FULL} - Version Information" -e "cat '${GAMEROOT}/share/FeralInfo.json'; echo -n 'Press ENTER to continue: '; read input"
	fi
	exit
fi

# ====================================================================
# Our games are compiled targeting the steam runtime and are not
# expected to work perfectly when run outside of it
# However on some distributions (Arch Linux/openSUSE etc.) users have
# had better luck using their own libs
# Remove the steam-check.sh file if testing that
# shellcheck source=config/steam-check.sh
test -f "${FERAL_CONFIG}/steam-check.sh" && . "${FERAL_CONFIG}/steam-check.sh"

# ====================================================================
# Set the steam appid if not set
if [ "${SteamAppId}" != "${FERAL_GAME_STEAMID}" ]; then
	SteamAppId="${FERAL_GAME_STEAMID}"
	GameAppId="${FERAL_GAME_STEAMID}"
	export SteamAppId
	export GameAppId
fi

# ====================================================================
# Enviroment Modifiers

# Store the current LD_PRELOAD
SYSTEM_LD_PRELOAD="${LD_PRELOAD}"
LD_PRELOAD_ADDITIONS=

# Unset LD_PRELOAD temporarily
# This avoids a chunk of confusing 32/64 errors from the steam overlay
# It also allows us to call the system openssl and curl here
# If your distribution needed an LD_PRELOAD addition then it should be
# fine to comment this out
unset LD_PRELOAD

# LC_ALL has caused users many issues in the past and generally is just
# used for debugging
# Uncomment this line if LC_ALL was needed (sometimes on openSUSE)
unset LC_ALL

# Try and set up SSL paths for all distros, due to steam runtime bug #52
# The value is used by our version of libcurl
# Users on unsupported distros might want to check if this is correct
HAS_CURL="$(sh -c "command -v curl-config")"
if [ -n "${HAS_CURL}" ]; then
	SSL_CERT_FILE="$(curl-config --ca)"
	export SSL_CERT_FILE
else
	# Otherwise try with guess work
	if [ -e /etc/ssl/certs/ca-certificates.crt ]; then
		SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
		export SSL_CERT_FILE
	elif [ -e /etc/pki/tls/certs/ca-bundle.crt ]; then
		SSL_CERT_FILE="/etc/pki/tls/certs/ca-bundle.crt"
		export SSL_CERT_FILE
	elif [ -e /var/lib/ca-certificates/ca-bundle.pem ]; then
		SSL_CERT_FILE="/var/lib/ca-certificates/ca-bundle.pem"
		export SSL_CERT_FILE
	fi
fi
HAS_OPENSSL="$(sh -c "command -v openssl")"
if [ -n "${HAS_OPENSSL}" ]; then
	SSL_CERT_DIR="$(sh -c "openssl version -d | sed -E 's/.*\\\"(.*)\\\"/\1/'")/certs"
	export SSL_CERT_DIR
fi

# Move the driver shader cache to our preferences
if [ -z "$__GL_SHADER_DISK_CACHE_PATH" ]; then
	export __GL_SHADER_DISK_CACHE_PATH="${GAMEPREFS}/driver-gl-shader-cache"
	# Avoid steam runtime libraries for mkdir
	OLD_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
	unset LD_LIBRARY_PATH
	mkdir -p "${__GL_SHADER_DISK_CACHE_PATH}"
	export LD_LIBRARY_PATH="${OLD_LD_LIBRARY_PATH}"
fi

# Brute force fix for some small thread sizes in external libraries
if [ -e "${GAMEROOT}/${FERAL_LIB_PATH}/libminimum_thread_stack_size_wrapper.so" ]; then
	LD_PRELOAD_ADDITIONS="../${FERAL_LIB_PATH}/libminimum_thread_stack_size_wrapper.so:${LD_PRELOAD_ADDITIONS}"
fi

# Use the system asound if requested
# This can help with sound issues on some distros including Arch Linux
# Now most likely only needed if STEAM_RUNTIME_PREFER_HOST_LIBRARIES is set to 0
if [ "${FERAL_SYSTEM_ASOUND}" = 1 ]; then
	LIBASOUND_DYLIB="libasound.so.2"
	if [ -e "/usr/lib/${FERAL_ARCH_FULL}-linux-gnu/${LIBASOUND_DYLIB}" ]; then
		LIBASOUND_LIBDIR="/usr/lib/${FERAL_ARCH_FULL}-linux-gnu"
	elif [ -e "/usr/lib${FERAL_ARCH_SHORT}/${LIBASOUND_DYLIB}" ]; then
		LIBASOUND_LIBDIR="/usr/lib${FERAL_ARCH_SHORT}"
	elif [ -e "/usr/lib/${LIBASOUND_DYLIB}" ]; then
		LIBASOUND_LIBDIR="/usr/lib"
	fi
	LD_PRELOAD_ADDITIONS="${LIBASOUND_LIBDIR}/${LIBASOUND_DYLIB}:${LD_PRELOAD_ADDITIONS}"
fi

# Sometimes games may need an extra set of variables
# Let's pull those in
# shellcheck source=config/extra-environment.sh
test -f "${FERAL_CONFIG}/extra-environment.sh" && . "${FERAL_CONFIG}/extra-environment.sh"

# Add our additionals and the old preload back
LD_PRELOAD="${LD_PRELOAD_ADDITIONS}:${SYSTEM_LD_PRELOAD}"
export LD_PRELOAD

# ====================================================================
# Source in the game chooser if it exists
# shellcheck source=config/game-chooser.sh
test -f "${FERAL_CONFIG}/game-chooser.sh" && . "${FERAL_CONFIG}/game-chooser.sh"

# ====================================================================
# Try and detect some common problems and show useful messages
# First check the dynamic linker
GAME_LDD_LOGFILE=/tmp/${FERAL_GAME_NAME}_ldd_log
if command -v ldd > /dev/null; then
	ldd "${GAMEROOT}/bin/${FERAL_GAME_NAME}" > "${GAME_LDD_LOGFILE}.txt"
	grep "not found" "${GAME_LDD_LOGFILE}.txt" > "${GAME_LDD_LOGFILE}_missing.txt"
	if [ -s "${GAME_LDD_LOGFILE}_missing.txt" ]; then
		echo "=== ERROR - You're missing vital libraries to run ${FERAL_GAME_NAME_FULL}"
		echo "=== Either use the steam runtime or install these using your package manager"
		cat "${GAME_LDD_LOGFILE}_missing.txt" && echo "==="
		rm "${GAME_LDD_LOGFILE}_missing.txt"
	fi
	rm "${GAME_LDD_LOGFILE}.txt"
fi

# Identify whether we have an NVIDIA driver installation that can cause the
# game to crash. This happens when the non-GLVND version of the GL driver is
# installed, but the Vulkan ICD path points to the GLVND version. This
# happens due to a bug in NVIDIA's installer, which made its way into the
# Debian driver packages.
#
# For more details, see:
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=864477

DRIVER_MESSAGE_TITLE="Driver installation issue"
DRIVER_MESSAGE_BODY="Your NVIDIA driver installation has an issue which may cause the game to crash.

If this happens, you will need to install the GLVND version of the driver. On Debian/SteamOS, this can be done by
installing the libgl1-nvidia-glvnd-glx package. Using NVIDIA's installer, the GLVND version should be installed by default.

For more details, see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=864477"

# ldconfig may be in sbin which may not be in the default PATH. We don't
# actually need root just to print its cache.
ORIG_PATH="${PATH}"
export PATH="/sbin:/usr/sbin:${PATH}"

# Find out what libGL we will be using.
LIBGL_PATH=$(ldconfig -p | grep libGL.so.1 | head -n 1 | sed "s/.*=> //g")
LIBGL_TARGET=$(readlink -f "${LIBGL_PATH}")

export PATH=$ORIG_PATH

# Check if it looks like a non-GLVND NVIDIA libGL based on the version number.
# For non-GLVND the file name looks like e.g. libGL.so.375.66
if echo "${LIBGL_TARGET}" | grep -q "\.so\.[0-9][0-9][0-9]\.[0-9][0-9]"; then
	# It's a non-GLVND installation. Check the Vulkan ICD path.
	if [ -e /etc/vulkan/icd.d/nvidia_icd.json ]; then
		VULKAN_ICD_JSON=/etc/vulkan/icd.d/nvidia_icd.json
	elif [ -e /usr/share/vulkan/icd.d/nvidia_icd.json ]; then
		VULKAN_ICD_JSON=/usr/share/vulkan/icd.d/nvidia_icd.json
	fi

	if [ -n "${VULKAN_ICD_JSON}" ]; then
		# If it points to libGLX_nvidia.so.0 then this will probably cause a
		# crash.
		if grep -q "libGLX_nvidia.so.0" "${VULKAN_ICD_JSON}"; then
			ShowMessage "${DRIVER_MESSAGE_TITLE}" "${DRIVER_MESSAGE_BODY}"
		fi
	fi
fi

# Legacy support: Replace the older PS4 mapping with the newer one if we're running a new enough kernel
# See https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/drivers/hid/hid-sony.c?id=ac797b95f53276c132c51d53437e38dd912413d7
KERNEL=$(uname -r)
KERNEL_MAJOR=$(echo "$KERNEL" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL" | cut -d. -f2)
OLD_MAPPING="a:b1,b:b2,back:b13,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b12,leftshoulder:b4,leftstick:b10,lefttrigger:a3,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b11,righttrigger:a4,rightx:a2,righty:a5,start:b9,x:b0,y:b3"
NEW_MAPPING="a:b0,b:b1,back:b8,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b10,leftshoulder:b4,leftstick:b11,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b12,righttrigger:a5,rightx:a3,righty:a4,start:b9,x:b3,y:b2"
if [ "$KERNEL_MAJOR" -gt 4 ] || [ "$KERNEL_MAJOR" = 4 ] && [ "$KERNEL_MINOR" -gt 9 ]; then
	if [ -e "${GAMEROOT}/share/inputdevices.json" ]; then
		sed -i "s/${OLD_MAPPING}/${NEW_MAPPING}/g" "${GAMEROOT}/share/inputdevices.json"
	elif [ -e "${GAMEROOT}/share/controllermapping.txt" ]; then
		sed -i "s/${OLD_MAPPING}/${NEW_MAPPING}/g" "${GAMEROOT}/share/controllermapping.txt"
	fi
fi

# ====================================================================
# Run the game
cd "${GAMEROOT}/bin" && ${GAME_LAUNCH_PREFIX} "${GAMEROOT}/bin/${FERAL_GAME_NAME}" "$@"
RESULT=$?

# ====================================================================
exit "${RESULT}"
