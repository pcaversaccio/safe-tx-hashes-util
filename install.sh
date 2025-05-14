#!/usr/bin/env bash

########################
# Don't trust, verify! #
########################

# @license GNU Affero General Public License v3.0 only
# @author pcaversaccio

# Utility function to detect the terminal colour support.
# Please note that we employ the environment flags:
# - https://no-color.org for disabling colour output,
# - https://force-color.org for forcing colour output.
# Only the exact value `true` is accepted to avoid accidental activation.
setup_colours() {
	if [[ "${NO_COLOR:-false}" == "true" ]]; then
		readonly COLOUR_ENABLED=0
	elif [[ "${FORCE_COLOR:-false}" == "true" ]]; then
		readonly COLOUR_ENABLED=1
	# Enable colours only if:
	# 1) output is a terminal (not piped or redirected),
	# 2) the `tput` command is available,
	# 3) and the terminal supports at least 8 colours (i.e. the standard ANSI colours).
	elif [[ -t 1 && -n "$(command -v tput)" && "$(tput colors)" -ge 8 ]]; then
		readonly COLOUR_ENABLED=1
	else
		readonly COLOUR_ENABLED=0
	fi

	if [[ "$COLOUR_ENABLED" -eq 1 ]]; then
		readonly RED="$(tput setaf 1)"
		readonly BOLD="$(tput bold)"
		readonly RESET="$(tput sgr0)"
	else
		readonly RED=""
		readonly BOLD=""
		readonly RESET=""
	fi
}

setup_colours

echo -e "${BOLD}${RED}
███████╗████████╗░██████╗░██████╗░
██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
███████╗░░░██║░░░██║░░░██║██████╔╝
╚════██║░░░██║░░░██║░░░██║██╔═══╝░
███████║░░░██║░░░╚██████╔╝██║░░░░░
╚══════╝░░░╚═╝░░░░╚═════╝░╚═╝░░░░░
${RESET}"

echo -e "${RED}${BOLD}SHAME ON YOU!${RESET}\n"
echo -e "${RED}${BOLD}You just piped a remote script straight into your shell - on the same machine you use to verify multisig transactions!${RESET}"
echo -e "${RED}${BOLD}That's absolutely brilliant... in the most idiotic way. Never blindly run code from the internet. Inspect it first!${RESET}"
