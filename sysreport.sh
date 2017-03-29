#!/bin/bash
# =============================================================
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
# =============================================================
# sysreport.sh - Script to gather data about the current system
#
# USAGE: $ sysreport.sh <game install root> <output file>
#
# This will gather a selection of info:
## hardware details
## system software info
## drivers
## environment
## running programs
## intalled game files
## feral preference files
#
# If you're unhappy sharing any of this information then feel
# free to remove it from the output when sending the file over
# =============================================================

# Force C locale to avoid some odd issues
export LC_ALL_OLD=$LC_ALL
export LC_ALL=C

# Escape the steam runtime library path
export SAVED_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
unset LD_LIBRARY_PATH

INSTALLDIR="$1"
OUTFILE="$( cd "$( dirname "$2" )" || exit; pwd )/$( basename "$2" )"
SKIP_CLOSE=$3


# Attempt to find the feral preferences directory
FERAL_PREFS="$XDG_DATA_HOME/feral-interactive"
if [ ! -d "$FERAL_PREFS" ]; then
	FERAL_PREFS="$HOME/.local/share/feral-interactive"
fi

# --------------------------------------------------------------------------------
# Helper functions
output_text() {
	echo "$1"
	echo "<h3 id=\"$1\">$1</h3>" >> "$OUTFILE"
} 

# --------------------------------------------------------------------------------
# Verify inputs
if [ ! -n "$OUTFILE" ] || [ ! -n "$INSTALLDIR" ]; then
	echo "USAGE: \$ $0 <game install root> <output file>"
	exit 1
fi
if [ ! -d "$INSTALLDIR" ]; then
	echo "$INSTALLDIR not found, game install missing?"
	exit 1
fi

# Check we can write to the output
echo "-" > "$OUTFILE"
WRITE_ERROR=$?
if [ $WRITE_ERROR != 0 ] ; then
	exit $WRITE_ERROR
fi

# --------------------------------------------------------------------------------
TEXT_AREA="<textarea rows=\"5\" readonly>"

# --------------------------------------------------------------------------------
# Set up the header
echo "Reporting with $INSTALLDIR to $OUTFILE"
echo "<!DOCTYPE html>
<html>
<head>
<title>Feral System Report</title>
<style>
textarea {
    width:90%;
    height:100px;
}
</style>
</head>
<body>
<h1>Feral System Report</h1>
<p>Generated using '\$ $0 $*' at $(date)</p>
<hr>
<h3>Contents</h3>
<p>
<a href=\"#programs\">Program Outputs</a><br>
<a href=\"#system\">System Files</a><br>
<a href=\"#installed\">Installed Files</a><br>
<a href=\"#preferences\">Preferences</a><br>" > "$OUTFILE"

# Add a tag for steam DLC info if we're appending it to the end
if [ "$PGOW_APPEND" = "1" ]; then
	echo "<a href=\"#steamdlc\">Steam DLC Info</a><br>" >> "$OUTFILE"
fi

echo "</p>" >> "$OUTFILE"

# --------------------------------------------------------------------------------
# "uname -a"           - System and kernel version info
# "lsb_release -a"     - More specific system info
# "nvidia-smi"         - Current GPU stats on nvidia
# "fglrxinfo"          - Current GPU stats on amd
# "lspci -v"           - Info on current hardware
# "lsusb -v"           - Info on USB devices
# "env"                - Check against steam runtime enviroment to catch oddities
# "top -b -n 1"        - Running processes (useful to detect CPU/GPU hogs or zombie processes)
# "glxinfo"            - Detailed opengl information
# "vulkaninfo"         - Detailed vulkan information
# "setxkbmap -query"   - Information on current keyboard map/modes
# "curl-config --ca"   - Location of the certificates bundle
# "cat $CPUFILES"      - Show CPU governor setting
CPUFILES="/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
echo "<hr><h2 id=\"programs\">Program Outputs</h2>" >> "$OUTFILE"
set -- "uname -a" \
	"lsb_release -a" \
	"nvidia-smi" \
	"fglrxinfo" \
	"xrandr" \
	"lspci -v" \
	"lsusb -v" \
	"env" \
	"top -b -n 1" \
	"glxinfo" \
	"vulkaninfo" \
	"setxkbmap -query" \
	"curl-config --ca" \
	"cat ${CPUFILES}"
for CMD do
	output_text "$CMD"
	echo "${TEXT_AREA}" >> "$OUTFILE"
	$CMD 2>&1 | head -n 500 | tee -a "$OUTFILE" | 
	if [ "$(wc -l)" = "500" ]; then 
		echo "...truncated..." >> "$OUTFILE" 
	fi
	echo "</textarea>" >> "$OUTFILE"
done


# --------------------------------------------------------------------------------
# "/etc/*-release"                   - Info on system release version
# "/etc/X11/default-display-manager" - X11 display manager info
# "/proc/meminfo"                    - Info on current RAM
# "/proc/cpuinfo"                    - Info on current CPU
# "/etc/sysconfig/displaymanager"    - Display manger config
# "/etc/sysconfig/desktop"           - WM config
# "/proc/bus/input/devices"          - input devices (controllers + m/k)
echo "<hr><h2 id=\"system\">System Files</h2>" >> "$OUTFILE"
RELEASE_FILES=(/etc/*-release)
set -- "${RELEASE_FILES[@]}" \
	"/etc/X11/default-display-manager" \
	"/proc/meminfo" \
	"/proc/cpuinfo" \
	"/etc/sysconfig/displaymanager" \
	"/etc/sysconfig/desktop" \
	"/proc/bus/input/devices" 
for FILE do
	if [ -e "$FILE" ] ; then
		output_text "$FILE"
		echo "${TEXT_AREA}" >> "$OUTFILE"
		head "$FILE" -n 500 | tee -a "$OUTFILE" | 
		if [ "$(wc -l)" = "500" ]; 
			then echo "...truncated..." >> "$OUTFILE"; 
		fi
		echo "</textarea>" >> "$OUTFILE"
	else
		output_text "$FILE not found"
	fi
done


# --------------------------------------------------------------------------------
# "ls -lRh"            - full information on current installed game files
echo "<hr><h2 id=\"installed\">Installed Files</h2>" >> "$OUTFILE"
cd "$INSTALLDIR" || exit
output_text "ls -lRh in '$INSTALLDIR'"
# shellcheck disable=SC2129
echo "${TEXT_AREA}" >> "$OUTFILE"
ls -lRh >> "$OUTFILE" 2>&1
echo "</textarea>" >> "$OUTFILE"

# "$INSTALLDIR/*.sh"                 - Launch script(s)
# "$INSTALLDIR/share/*.json"         - Configuration JSON files
# "$INSTALLDIR/share/*.xml"          - Configuration XML files
# "$INSTALLDIR/share/*.txt"          - Configuration TXT files
cd "$INSTALLDIR" || exit
for FILE in *.sh share/*.json share/*.xml share/*.txt
do
	output_text "'$FILE' in '$INSTALLDIR'"
	echo "${TEXT_AREA}" >> "$OUTFILE"
	head "$FILE" -n 500 | tee -a "$OUTFILE" | 
	if [ "$(wc -l)" = "500" ]; 
		then echo "...truncated..." >> "$OUTFILE"
	fi
	echo "</textarea>" >> "$OUTFILE"
done

# --------------------------------------------------------------------------------
# "$FERAL_PREFS/*/preferences"       - Preferences files
echo "<hr><h2 id=\"preferences\">Preferences</h2>" >> "$OUTFILE"
cd "$FERAL_PREFS" || exit
for FILE in */preferences
do
	output_text "'$FILE' in '$FERAL_PREFS'"
	echo "${TEXT_AREA}" >> "$OUTFILE"
	head "$FILE" -n 500 | tee -a "$OUTFILE" | 
	if [ "$(wc -l)" = "500" ]; 
		then echo "...truncated..." >> "$OUTFILE"
	fi
	echo "</textarea>" >> "$OUTFILE"
done

# --------------------------------------------------------------------------------
# Attempt to clean out any login commands that contain passwords
sed -i -E 's/-login \w+ \w+/-login <scrubbed> <scrubbed>/g' "$OUTFILE"

# Insert the close tags
if [ "$SKIP_CLOSE" == "1" ]; then
	exit 0
fi

echo "</body>
</html>" >> "$OUTFILE"
