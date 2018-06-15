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
# Version 2.9.0

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
		--fresh-prefs)            FERAL_FRESH_PREFERENCES=1      && shift ;;
		--system-asound)          FERAL_SYSTEM_ASOUND=1          && shift ;;
		--clear-system-gl-caches) FERAL_CLEAR_SYSTEM_GL_CACHES=1 && shift ;;
		--log-to-file)            FERAL_LOG_TO_FILE=1            && shift ;;
		--run-from-steam)         FERAL_RUN_FROM_STEAM=1         && shift ;;
		--renderdoc)              FERAL_USE_RENDERDOC=1          && shift ;;
		--version)                FERAL_GET_VERSION=1            && shift ;;
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
# Ensure we pass the steam check, before we inherit the enviroment below
if [ "${FERAL_RUN_FROM_STEAM}" = 1 ]; then
	STEAM_RUNTIME=1
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
	SteamGameId="${FERAL_GAME_STEAMID}"
	export SteamAppId
	export GameAppId
	export SteamGameId
fi

# ====================================================================
# Inherit the steam-runtime from a script if asked
# Requires a script that can set up the steam-runtime at bin/feralrunfromsteam
if [ "${FERAL_RUN_FROM_STEAM}" = 1 ]; then
	source "${GAMEROOT}/bin/feralrunfromsteam"
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
fi

# Otherwise try with guess work
if [ -z "$SSL_CERT_FILE" ]; then
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

# Use a directory in our preferences for the Nvidia driver shader cache if not specified
# We need to move this as our games go over the internal MB limit for the driver
# cache when not placed in a custom location with __GL_SHADER_DISK_CACHE_PATH
if [ -z "$__GL_SHADER_DISK_CACHE_PATH" ]; then
	export __GL_SHADER_DISK_CACHE_PATH="${GAMEPREFS}/driver-gl-shader-cache"
	# Avoid steam runtime libraries for mkdir
	OLD_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
	unset LD_LIBRARY_PATH
		mkdir -p "${__GL_SHADER_DISK_CACHE_PATH}"
	export LD_LIBRARY_PATH="${OLD_LD_LIBRARY_PATH}"
fi

# We also want to clear the caches if requested by the game
# which can't do this during the normal execution as it is unsafe
# To do this, the game will add a temp file for us to catch
__FRL_TMP_FILE_CLEAR_GL_CACHES=/tmp/frl_clear_gl_caches
if [ -f "${__FRL_TMP_FILE_CLEAR_GL_CACHES}" ]; then
	rm "${__FRL_TMP_FILE_CLEAR_GL_CACHES}"
	FERAL_CLEAR_SYSTEM_GL_CACHES=1
fi

# Clean out and remake the driver cache directory if requested
# We need to do this before running the game as the driver won't react well
# to the cache being pulled out from under it
if [ "${FERAL_CLEAR_SYSTEM_GL_CACHES}" = 1 ]; then

	# Avoid steam runtime libraries for rm and mkdir
	OLD_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
	unset LD_LIBRARY_PATH

		# Clear the Nvidia cache locations
		# https://us.download.nvidia.com/XFree86/Linux-x86/384.59/README/openglenvvariables.html
		if [ ! -z "${__GL_SHADER_DISK_CACHE_PATH}" ]; then
			__NV_CACHE="${__GL_SHADER_DISK_CACHE_PATH}"
		elif [ ! -z "${XDG_CACHE_HOME}" ]; then
			__NV_CACHE="${XDG_CACHE_HOME}/.nv/GLCache"
		else
			__NV_CACHE="${HOME}/.nv/GLCache"
		fi
		if [ -d "${__NV_CACHE}" ]; then
			echo "Clearing NVIDIA cache at \"${__NV_CACHE}\""
			rm -r "${__NV_CACHE}"
			mkdir -p "${__NV_CACHE}"
		fi

		# Clear Mesa GLSL cache, using directory search in src/util/disk_cache.c as of 2017-10-12.
		# Note the directory name was renamed from "mesa" to "mesa_shader_cache" on 2017-08-24.
		if [ ! -z "${MESA_GLSL_CACHE_DIR}" ]; then
			__MESA_CACHE="${MESA_GLSL_CACHE_DIR}/mesa_shader_cache"
			if [ ! -d "${__MESA_CACHE}" ]; then
				__MESA_CACHE="${MESA_GLSL_CACHE_DIR}/mesa"
			fi
		elif [ ! -z "${XDG_CACHE_HOME}" ]; then
			__MESA_CACHE="${XDG_CACHE_HOME}/mesa_shader_cache"
			if [ ! -d "${__MESA_CACHE}" ]; then
				__MESA_CACHE="${XDG_CACHE_HOME}/mesa"
			fi
		else
			__MESA_CACHE="${HOME}/.cache/mesa_shader_cache"
			if [ ! -d "${__MESA_CACHE}" ]; then
				__MESA_CACHE="${HOME}/.cache/mesa"
			fi
		fi
		if [ -d "${__MESA_CACHE}" ]; then
			echo "Clearing Mesa cache at \"${__MESA_CACHE}\""
			rm -r "${__MESA_CACHE}"
			mkdir -p "${__MESA_CACHE}"
		fi

		# Clear AMD Closed cache, using location as of 17.30
		__GPUPRO_CACHE="${HOME}/.AMD/GLCache"
		if [ -d "${__GPUPRO_CACHE}" ]; then
			echo "Clearing AMD GPUPRO cache at \"${__GPUPRO_CACHE}\""
			rm -r "${__GPUPRO_CACHE}"
			mkdir -p "${__GPUPRO_CACHE}"
		fi

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

# Set up Vulkan renderdoc if asked
if [ "${FERAL_USE_RENDERDOC}" = 1 ]; then
	export VK_INSTANCE_LAYERS="${VK_INSTANCE_LAYERS}:VK_LAYER_RENDERDOC_Capture"
	export ENABLE_VULKAN_RENDERDOC_CAPTURE=1
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

# Workaround for Ubuntu NVIDIA driver packaging issue:
# https://bugs.launchpad.net/ubuntu/+source/nvidia-graphics-drivers-384/+bug/1726809
#
# Run a tool to determine whether we can enumerate available Vulkan devices. If
# not, check if the Vulkan ICD configuration looks to be affected, and if so,
# try again with an overridden config with a workaround applied.
#
# Don't do anything if the user is manually overriding the Vulkan ICD path.
if [ -z "${VK_ICD_FILENAMES}" ]; then
	CHECK_VULKAN_BINARY="${GAMEROOT}/bin/CheckVulkanDriver"
	if ! "${CHECK_VULKAN_BINARY}"; then
		if [ -e /etc/vulkan/icd.d/nvidia_icd.json ]; then
			VULKAN_ICD_JSON=/etc/vulkan/icd.d/nvidia_icd.json
		elif [ -e /usr/share/vulkan/icd.d/nvidia_icd.json ]; then
			VULKAN_ICD_JSON=/usr/share/vulkan/icd.d/nvidia_icd.json
		fi

		if [ -n "${VULKAN_ICD_JSON}" ]; then
			if grep -q "libGL.so.1" "${VULKAN_ICD_JSON}"; then
				# Try substituting in the GLVND library path to see if this
				# works instead.
				export VK_ICD_FILENAMES="$(mktemp --tmpdir nvidia_icd.XXXXXX.json)"
				sed 's/libGL\.so\.1/libGLX_nvidia.so.0/' "${VULKAN_ICD_JSON}" > "${VK_ICD_FILENAMES}"
				if ! "${CHECK_VULKAN_BINARY}"; then
					# Still doesn't work, revert back to default.
					unset VK_ICD_FILENAMES
				fi
			fi
		fi
	fi
fi

# ====================================================================
# Run the game
cd "${GAMEROOT}/bin"

# Use the signalwrapper if it exists
if [ -e "signalwrapper" ]; then
	GAME_SIGNAL_WRAPPER="./signalwrapper"
fi

# Launch the game with all the arguments
${GAME_LAUNCH_PREFIX} ${GAME_SIGNAL_WRAPPER} "${GAMEROOT}/bin/${FERAL_GAME_NAME}" "$@"
RESULT=$?

# ====================================================================
exit "${RESULT}"
