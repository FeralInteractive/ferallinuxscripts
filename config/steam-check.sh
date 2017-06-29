#!/bin/bash
if [ -z ${STEAM_RUNTIME} ]; then
	echo "WARNING: ${FERAL_GAME_NAME_FULL} not launched within the steam runtime"
	echo "         This is likely incorrect and is not officially supported"
	echo "         Launching steam in 3 seconds with steam://rungameid/${FERAL_GAME_STEAMID}"
	sleep 3
	steam "steam://rungameid/${FERAL_GAME_STEAMID}"
	exit
elif [ ${STEAM_RUNTIME} == 0 ]; then
	echo "WARNING: ${FERAL_GAME_NAME_FULL} launched with STEAM_RUNTIME=0"
	echo "         We recommend using the steam runtime if possible"
fi
