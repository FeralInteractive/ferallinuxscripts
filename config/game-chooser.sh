#!/bin/sh
# Allow us to overload the game being launched with an environment variable
if [ ! -z "${FERAL_SCRIPT_LAUNCH_GAME}" ]; then
	FERAL_GAME_NAME="${FERAL_SCRIPT_LAUNCH_GAME}"
else
	# Make sure the items in the list exist
	CHOICES=()
	for GAME in ${FERAL_LAUNCHER_GAMES[@]}; do
		if [ -x "${GAMEROOT}/bin/$GAME" ]; then
			CHOICES+=($GAME)
		fi
	done

	# Otherwise, if we're a terminal, ask the user
	if [ -t 0 ] && [ ${#CHOICES[@]} -gt 1  ]; then
		echo "Choose which game to launch: ${CHOICES[*]}"
		read CHOICE
		((CHOICE--))
		FERAL_GAME_NAME="${CHOICES[$CHOICE]}"
	fi
fi
