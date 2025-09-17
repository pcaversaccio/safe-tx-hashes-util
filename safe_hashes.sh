#!/usr/bin/env bash

########################
# Don't trust, verify! #
########################

# @license GNU Affero General Public License v3.0 only
# @author pcaversaccio

# Enable strict error handling:
# -E: Inherit `ERR` traps in functions and subshells.
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit.
# -o pipefail: Return the exit status of the first failed command in a pipeline.
set -Eeuo pipefail

# Enable debug mode if the environment variable `DEBUG` is set to `true`.
if [[ "${DEBUG:-false}" == "true" ]]; then
	# Print each command before executing it.
	set -x
fi

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
		readonly GREEN="$(tput setaf 2)"
		readonly YELLOW="$(tput setaf 3)"
		readonly BOLD="$(tput bold)"
		readonly UNDERLINE="$(tput smul)"
		readonly RESET="$(tput sgr0)"
	else
		readonly RED=""
		readonly GREEN=""
		readonly YELLOW=""
		readonly BOLD=""
		readonly UNDERLINE=""
		readonly RESET=""
	fi
}

setup_colours

# Check the Bash version compatibility.
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
	echo -e "${BOLD}${RED}Error: This script requires Bash 4.0 or higher!${RESET}"
	echo -e "${BOLD}${RED}Current version: $BASH_VERSION${RESET}"
	echo -e "${BOLD}${RED}Please upgrade your Bash installation.${RESET}"
	echo -e "${BOLD}${RED}If you've already upgraded via Homebrew, try running:${RESET}"
	echo -e "${BOLD}${RED}/opt/homebrew/bin/bash $0 $@${RESET}"
	exit 1
fi

# Utility function to retrieve and parse the semantic version number (e.g. `1.3.5`)
# from Foundry tools such as `cast` or `chisel`.
parse_foundry_version() {
	local tool="$1"
	local output=""
	local version=""

	# Fail if the tool cannot run.
	if ! output=$("$tool" --version 2>&1); then
		echo -e "${BOLD}${RED}Error: Failed to run \`$tool --version\`!${RESET}" >&2
		exit 1
	fi

	# Extract the tool's semantic version.
	version=$(echo "$output" | awk '/Version:/ {print $3}' | cut -d"-" -f1)

	# Fail if no version was found.
	if [[ -z "$version" ]]; then
		echo "${BOLD}${RED}Error: Could not determine the version of \`$tool\`!${RESET}" >&2
		exit 1
	fi

	echo "$version"
}

# Utility function to compare two semantic versions and return `true` if `$1 >= $2`.
semver_ge() {
	[[ "$(printf "%s\n%s" "$2" "$1" | sort -V | head -n1)" = "$2" ]]
}

# Utility function to ensure all required tools are installed.
check_required_tools() {
	local tools=("curl" "jq" "chisel" "cast")
	local missing_tools=()
	local min_version="1.3.5"

	for tool in "${tools[@]}"; do
		if ! command -v "$tool" &>/dev/null; then
			missing_tools+=("$tool")
		fi

		if [[ "$tool" == "cast" || "$tool" == "chisel" ]]; then
			tool_version=$(parse_foundry_version "$tool")
			if ! semver_ge "$tool_version" "$min_version"; then
				echo -e "${BOLD}${RED}\`$tool\` version \`$tool_version\` is too old. Minimum required is \`$min_version\`.${RESET}"
				exit 1
			fi
		fi
	done

	if [[ ${#missing_tools[@]} -ne 0 ]]; then
		echo -e "${BOLD}${RED}The following required tools are not installed:${RESET}"
		for tool in "${missing_tools[@]}"; do
			echo -e "${BOLD}${RED}  - $tool${RESET}"
		done
		echo -e "${BOLD}${RED}Please install them to run the script properly.${RESET}"
		exit 1
	fi
}

check_required_tools

# Set the zero address as a global constant.
readonly ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

# Set a global flag indicating whether a delegate call warning was already displayed
# to the user. Used to determine proper spacing between multiple warnings.
delegate_call_warning_shown="false"

# Set a global variable to store the Safe transaction hash for use across multiple functions.
global_safe_tx_hash="0x0000000000000000000000000000000000000000000000000000000000000000"
# Set a global variable to store the simulated Safe transaction hash for use across multiple functions.
global_safe_tx_hash_simulated="0x0000000000000000000000000000000000000000000000000000000000000000"

# Set the type hash constants.
# => `keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");`
# See: https://github.com/safe-global/safe-smart-account/blob/a0a1d4292006e26c4dbd52282f4c932e1ffca40f/contracts/Safe.sol#L54-L57.
readonly DOMAIN_SEPARATOR_TYPEHASH="0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218"
# => `keccak256("EIP712Domain(address verifyingContract)");`
# See: https://github.com/safe-global/safe-smart-account/blob/703dde2ea9882a35762146844d5cfbeeec73e36f/contracts/GnosisSafe.sol#L20-L23.
readonly DOMAIN_SEPARATOR_TYPEHASH_OLD="0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749"
# => `keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)");`
# See: https://github.com/safe-global/safe-smart-account/blob/a0a1d4292006e26c4dbd52282f4c932e1ffca40f/contracts/Safe.sol#L59-L62.
readonly SAFE_TX_TYPEHASH="0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8"
# => `keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)");`
# See: https://github.com/safe-global/safe-smart-account/blob/427d6f7e779431333c54bcb4d4cde31e4d57ce96/contracts/GnosisSafe.sol#L25-L28.
readonly SAFE_TX_TYPEHASH_OLD="0x14d461bc7412367e924637b363c7bf29b8f47e2f84869f4426e5633d8af47b20"
# => `keccak256("SafeMessage(bytes message)");`
# See: https://github.com/safe-global/safe-smart-account/blob/febab5e4e859e6e65914f17efddee415e4992961/contracts/libraries/SignMessageLib.sol#L12-L13.
readonly SAFE_MSG_TYPEHASH="0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca"

# Set the storage slots for the configured transaction and module guards.
# => `keccak256("guard_manager.guard.address");`
# See: https://github.com/safe-global/safe-smart-account/blob/333f84083e58df8e70b03e7f7df1947c1d77b262/contracts/libraries/SafeStorage.sol#L63-L67.
readonly GUARD_STORAGE_SLOT="0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8"
# => `keccak256("module_manager.module_guard.address");`
# See: https://github.com/safe-global/safe-smart-account/blob/333f84083e58df8e70b03e7f7df1947c1d77b262/contracts/libraries/SafeStorage.sol#L69-L73.
readonly MODULE_GUARD_STORAGE_SLOT="0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947"

# Set the trusted (i.e. for delegate calls) `MultiSendCallOnly` addresses:
# MultiSendCallOnly `v1.3.0` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.3.0/multi_send_call_only.json#L7,
# MultiSendCallOnly `v1.3.0` (eip155): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.3.0/multi_send_call_only.json#L11,
# MultiSendCallOnly `v1.3.0` (zksync): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.3.0/multi_send_call_only.json#L15,
# MultiSendCallOnly `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.4.1/multi_send_call_only.json#L7,
# MultiSendCallOnly `v1.4.1` (zksync): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.4.1/multi_send_call_only.json#L11,
# MultiSendCallOnly `v1.5.0` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.5.0/multi_send_call_only.json#L7.
declare -a -r MultiSendCallOnly=(
	"0x40A2aCCbd92BCA938b02010E17A5b8929b49130D" # MultiSendCallOnly `v1.3.0` (canonical).
	"0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B" # MultiSendCallOnly `v1.3.0` (eip155).
	"0xf220D3b4DFb23C4ade8C88E526C1353AbAcbC38F" # MultiSendCallOnly `v1.3.0` (zksync).
	"0x9641d764fc13c8B624c04430C7356C1C7C8102e2" # MultiSendCallOnly `v1.4.1` (canonical).
	"0x0408EF011960d02349d50286D20531229BCef773" # MultiSendCallOnly `v1.4.1` (zksync).
	"0xA83c336B20401Af773B6219BA5027174338D1836" # MultiSendCallOnly `v1.5.0` (canonical).
)

# Set the trusted (i.e. for delegate calls) `SafeMigration` addresses:
# SafeMigration `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.4.1/safe_migration.json#L7,
# SafeMigration `v1.4.1` (zksync): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.4.1/safe_migration.json#L11,
# SafeMigration `v1.5.0` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.5.0/safe_migration.json#L7.
declare -a -r SafeMigration=(
	"0x526643F69b81B008F46d95CD5ced5eC0edFFDaC6" # SafeMigration `v1.4.1` (canonical).
	"0x817756C6c555A94BCEE39eB5a102AbC1678b09A7" # SafeMigration `v1.4.1` (zksync).
	"0x6439e7ABD8Bb915A5263094784C5CF561c4172AC" # SafeMigration `v1.5.0` (canonical).
)

# Set the trusted (i.e. for delegate calls) `SignMessageLib` addresses:
# SignMessageLib `v1.3.0` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.3.0/sign_message_lib.json#L7,
# SignMessageLib `v1.3.0` (eip155): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.3.0/sign_message_lib.json#L11,
# SignMessageLib `v1.3.0` (zksync): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.3.0/sign_message_lib.json#L15,
# SignMessageLib `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.4.1/sign_message_lib.json#L7,
# SignMessageLib `v1.4.1` (zksync): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.4.1/sign_message_lib.json#L11,
# SignMessageLib `v1.5.0` (canonical): https://github.com/safe-global/safe-deployments/blob/5c2f9957939ee27ab55d179474c55ec4411a99d6/src/assets/v1.5.0/sign_message_lib.json#L7.
declare -a -r SignMessageLib=(
	"0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2" # SignMessageLib `v1.3.0` (canonical).
	"0x98FFBBF51bb33A056B08ddf711f289936AafF717" # SignMessageLib `v1.3.0` (eip155).
	"0x357147caf9C0cCa67DfA0CF5369318d8193c8407" # SignMessageLib `v1.3.0` (zksync).
	"0xd53cd0aB83D845Ac265BE939c57F53AD838012c9" # SignMessageLib `v1.4.1` (canonical).
	"0xAca1ec0a1A575CDCCF1DC3d5d296202Eb6061888" # SignMessageLib `v1.4.1` (zksync).
	"0x4FfeF8222648872B3dE295Ba1e49110E61f5b5aa" # SignMessageLib `v1.5.0` (canonical).
)

# Set the trusted (i.e. for delegate calls) contract addresses.
# See: https://github.com/safe-global/safe-transaction-service/blob/0e6da1d19cec56f8e2834e6159f2d25733c64843/safe_transaction_service/contracts/management/commands/setup_safe_contracts.py#L15-L19.
declare -A -r TRUSTED_FOR_DELEGATE_CALL=(
	["MultiSendCallOnly"]="${MultiSendCallOnly[@]}"
	["SafeMigration"]="${SafeMigration[@]}"
	["SignMessageLib"]="${SignMessageLib[@]}"
)

# Define the canonical base URL for the Safe transaction service API.
readonly BASE_URL="https://api.safe.global/tx-service"

# Define the supported networks from the Safe transaction service.
# See https://docs.safe.global/advanced/smart-account-supported-networks?service=Transaction+Service.
declare -A -r API_URLS=(
	["arbitrum"]="${BASE_URL}/arb1"
	["aurora"]="${BASE_URL}/aurora"
	["avalanche"]="${BASE_URL}/avax"
	["base"]="${BASE_URL}/base"
	["base-sepolia"]="${BASE_URL}/basesep"
	["berachain"]="${BASE_URL}/berachain"
	["botanix"]="${BASE_URL}/btc"
	["bsc"]="${BASE_URL}/bnb"
	["celo"]="${BASE_URL}/celo"
	["codex"]="${BASE_URL}/codex"
	["ethereum"]="${BASE_URL}/eth"
	["gnosis"]="${BASE_URL}/gno"
	["gnosis-chiado"]="${BASE_URL}/chi"
	["hemi"]="${BASE_URL}/hemi"
	["ink"]="${BASE_URL}/ink"
	["katana"]="${BASE_URL}/katana"
	["lens"]="${BASE_URL}/lens"
	["linea"]="${BASE_URL}/linea"
	["mantle"]="${BASE_URL}/mantle"
	["opbnb"]="${BASE_URL}/opbnb"
	["optimism"]="${BASE_URL}/oeth"
	["peaq"]="${BASE_URL}/peaq"
	["polygon"]="${BASE_URL}/pol"
	["polygon-zkevm"]="${BASE_URL}/zkevm"
	["scroll"]="${BASE_URL}/scr"
	["sepolia"]="${BASE_URL}/sep"
	["sonic"]="${BASE_URL}/sonic"
	["unichain"]="${BASE_URL}/unichain"
	["worldchain"]="${BASE_URL}/wc"
	["xdc"]="${BASE_URL}/xdc"
	["xlayer"]="${BASE_URL}/okb"
	["zksync"]="${BASE_URL}/zksync"
)

# Define the chain IDs of the supported networks from the Safe transaction service.
declare -A -r CHAIN_IDS=(
	["arbitrum"]="42161"
	["aurora"]="1313161554"
	["avalanche"]="43114"
	["base"]="8453"
	["base-sepolia"]="84532"
	["berachain"]="80094"
	["botanix"]="3637"
	["bsc"]="56"
	["celo"]="42220"
	["codex"]="81224"
	["ethereum"]="1"
	["gnosis"]="100"
	["gnosis-chiado"]="10200"
	["hemi"]="43111"
	["ink"]="57073"
	["katana"]="747474"
	["lens"]="232"
	["linea"]="59144"
	["mantle"]="5000"
	["opbnb"]="204"
	["optimism"]="10"
	["peaq"]="3338"
	["polygon"]="137"
	["polygon-zkevm"]="1101"
	["scroll"]="534352"
	["sepolia"]="11155111"
	["sonic"]="146"
	["unichain"]="130"
	["worldchain"]="480"
	["xdc"]="50"
	["xlayer"]="196"
	["zksync"]="324"
)

# Utility function to display the usage information.
usage() {
	cat <<EOF
Usage: $0 [--help] [--version] [--list-networks]
       --network <network> --address <address> [--nonce <nonce>]
       [--nested-safe-address <address>] [--nested-safe-nonce <nonce>]
       [--message <file>] [--interactive] [--simulate <rpc_url>]

Options:
  --help                            Display this help message
  --version                         Display the latest local commit hash (=version) of the script
  --list-networks                   List all supported networks and their chain IDs
  --network <network>               Specify the network (required)
  --address <address>               Specify the Safe multisig address (required)
  --nonce <nonce>                   Specify the transaction nonce (required for transaction hashes)
  --nested-safe-address <address>   Specify the nested Safe multisig address (optional for transaction hashes or off-chain message hashes)
  --nested-safe-nonce <nonce>       Specify the nonce for the nested Safe transaction (optional for transaction hashes)
  --message <file>                  Specify the message file (required for off-chain message hashes)
  --interactive                     Use the interactive mode (optional for transaction hashes)
  --simulate <rpc_url>              Output the \`cast call --trace\` result in addition to the transaction hashes using the specified RPC URL (optional for transaction hashes)

Example for transaction hashes:
  $0 --network ethereum --address 0x1234...5678 --nonce 42

Example for transaction hashes including simulation:
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --simulate https://eth.llamarpc.com

Example for transaction hashes (interactive mode):
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --interactive

Example for transaction hashes (interactive mode) including simulation:
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --interactive --simulate https://eth.llamarpc.com

Example for transaction hashes via a nested Safe multisig approval:
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --nested-safe-address 0x8765...4321 --nested-safe-nonce 10

Example for transaction hashes via a nested Safe multisig approval including simulation:
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --nested-safe-address 0x8765...4321 --nested-safe-nonce 10 --simulate https://eth.llamarpc.com

Example for transaction hashes via a nested Safe multisig approval (interactive mode):
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --nested-safe-address 0x8765...4321 --nested-safe-nonce 10 --interactive

Example for transaction hashes via a nested Safe multisig approval (interactive mode) including simulation:
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --nested-safe-address 0x8765...4321 --nested-safe-nonce 10 --interactive --simulate https://eth.llamarpc.com

Example for off-chain message hashes:
  $0 --network ethereum --address 0x1234...5678 --message message.txt

Example for off-chain message hashes via a nested Safe multisig signer:
  $0 --network ethereum --address 0x1234...5678 --nested-safe-address 0x8765...4321 --message message.txt
EOF
	exit "${1:-1}"
}

# Utility function to retrieve the latest local commit hash from the Git repository.
# We don't include `git` in the `check_required_tools` function to avoid making
# it a strict dependency for the script to run.
get_latest_git_commit_hash() {
	local commit_hash=""
	if command -v git &>/dev/null; then
		commit_hash=$(git rev-parse HEAD 2>/dev/null)
		if [[ -n "$commit_hash" ]]; then
			echo -e "Latest local commit hash (=version) of the script: ${GREEN}$commit_hash${RESET}."
			exit 0
		else
			echo -e "${BOLD}${RED}No commit hash information available. There may be an issue with your Git installation or repository configuration.${RESET}"
			exit 1
		fi
	else
		echo -e "${BOLD}${RED}Git is not installed or not found. Unable to retrieve the commit hash information!${RESET}"
		exit 1
	fi
}

# Utility function to list all supported networks.
list_networks() {
	echo "Supported Networks:"
	for network in $(echo "${!CHAIN_IDS[@]}" | tr " " "\n" | sort); do
		echo "  $network (${CHAIN_IDS[$network]})"
	done
	exit 0
}

# Utility function to print a section header.
print_header() {
	local header="$1"
	if [[ -n "$UNDERLINE" ]]; then
		# Terminal supports formatting.
		printf "\n${UNDERLINE}%s${RESET}\n" "$header"
	else
		# Fallback for terminals without formatting support.
		printf "\n%s\n" "> $header:"
	fi
}

# Utility function to print a labelled value.
print_field() {
	local label="$1"
	local value="$2"
	local empty_line="${3:-false}"

	if [[ "$COLOUR_ENABLED" -eq 1 ]]; then
		# Terminal supports formatting.
		printf "%s: ${GREEN}%s${RESET}\n" "$label" "$value"
	else
		# Fallback for terminals without formatting support.
		printf "%s: %s\n" "$label" "$value"
	fi

	# Print an empty line if requested.
	if [[ "$empty_line" == "true" ]]; then
		printf "\n"
	fi
}

# Utility function to print the transaction data.
print_transaction_data() {
	local address="$1"
	local to="$2"
	local value="$3"
	local data="$4"
	local operation="$5"
	local safe_tx_gas="$6"
	local base_gas="$7"
	local gas_price="$8"
	local gas_token="$9"
	local refund_receiver="${10}"
	local nonce="${11}"
	local message="${12}"

	print_header "Transaction Data"
	print_field "Multisig address" "$address"
	print_field "To" "$to"
	print_field "Value" "$value"
	print_field "Data" "$data"
	case "$operation" in
	1)
		if [[ "$operation" -eq 1 && ! " ${TRUSTED_FOR_DELEGATE_CALL[@]} " =~ " ${to} " ]]; then
			print_field "Operation" "Delegatecall ${RED}(UNTRUSTED delegatecall; carefully verify before proceeding!)${RESET}"
		else
			print_field "Operation" "Delegatecall ${YELLOW}(trusted delegatecall)${RESET}"
		fi
		;;
	0)
		print_field "Operation" "Call"
		;;
	*)
		print_field "Operation" "Unknown"
		;;
	esac
	print_field "Safe Transaction Gas" "$safe_tx_gas"
	print_field "Base Gas" "$base_gas"
	print_field "Gas Price" "$gas_price"
	print_field "Gas Token" "$gas_token"
	print_field "Refund Receiver" "$refund_receiver"
	print_field "Nonce" "$nonce"
	print_field "Encoded message" "$message"
}

# Utility function to format the hash (keep `0x` lowercase, rest uppercase).
format_hash() {
	local hash="$1"
	local prefix="${hash:0:2}"
	local rest="${hash:2}"
	echo "${prefix,,}${rest^^}"
}

# Utility function to print the hash information.
print_hash_info() {
	local domain_hash="$1"
	local message_hash="$2"
	local safe_tx_hash="$3"

	print_header "Hashes"
	print_field "Domain hash" "$(format_hash "$domain_hash")"
	print_field "Message hash" "$(format_hash "$message_hash")"
	print_field "Safe transaction hash" "$safe_tx_hash"
}

# Utility function to print the ABI-decoded transaction data.
print_decoded_data() {
	local address="$1"
	local to="$2"
	local value="$3"
	local data="$4"
	local data_decoded="$5"

	if [[ "$data" == "0x" && "$data_decoded" == "0x" ]]; then
		# With no calldata, interpret intent based on `to` and `value`:
		# - `to == address` and `value == 0` => on-chain rejection,
		# - `to == address` and `value != 0` => ETH self-transfer,
		# - `to != address` and `value == 0` => zero-value ETH transfer,
		# - `to != address` and `value != 0` => standard ETH transfer.
		local method_name=""
		if [[ "$to" == "$address" && "$value" == "0" ]]; then
			method_name="0x (On-Chain Rejection)"
		elif [[ "$to" == "$address" && "$value" != "0" ]]; then
			method_name="0x (ETH Self-Transfer)"
		elif [[ "$to" != "$address" && "$value" == "0" ]]; then
			method_name="0x (Zero-Value ETH Transfer)"
		else
			method_name="0x (ETH Transfer)"
		fi
		print_field "Method" "$method_name"
		print_field "Parameters" "[]"
	elif [[ "$data" != "0x" && "$data_decoded" == "0x" ]]; then
		print_field "Method" "Unknown"
		print_field "Parameters" "Unknown"
	elif [[ "$data_decoded" == "interactive" ]]; then
		print_field "Method" "Unavailable in interactive mode"
		print_field "Parameters" "Unavailable in interactive mode"
	else
		local method=$(echo "$data_decoded" | jq -r ".method")
		local parameters=$(echo "$data_decoded" | jq -r ".parameters")

		print_field "Method" "$method"
		print_field "Parameters" "$parameters"

		# Check if the called function is sensitive and print a warning in bold.
		case "$method" in
		addOwnerWithThreshold | removeOwner | swapOwner | changeThreshold)
			echo -e "\n${BOLD}${RED}WARNING: The \"$method\" function modifies the owners or threshold of the Safe. Proceed with caution!${RESET}"
			;;
		esac

		# Check for sensitive functions in nested transactions.
		if [[ -n "$parameters" && "$parameters" != "null" ]]; then
			jq -r -c '
				.[] | .valueDecoded? |
				if type == "array" then .[]
				elif type == "object" then .
				else empty
				end |
				(.dataDecoded.method? // .method? // empty)
			' <<<"$parameters" | while IFS= read -r nested_method; do
				[[ -z "$nested_method" ]] && continue

				if [[ "$nested_method" =~ ^(addOwnerWithThreshold|removeOwner|swapOwner|changeThreshold)$ ]]; then
					echo -e "\n${BOLD}${RED}WARNING: The \"$nested_method\" function modifies the owners or threshold of the Safe! Proceed with caution!${RESET}"
				fi
			done
		fi
	fi
}

# Utility function to extract the clean Safe multisig version.
get_version() {
	local version="$1"
	# Safe multisig versions can have the format `X.Y.Z+L2`.
	# Remove any suffix after and including the `+` in the version string for comparison.
	local clean_version=$(echo "$version" | sed "s/+.*//")
	echo "$clean_version"
}

# Utility function to validate the Safe multisig version.
validate_version() {
	local version="$1"
	if [[ -z "$version" ]]; then
		echo "${YELLOW}No Safe multisig contract found for the specified network. Please ensure that you have selected the correct network.${RESET}"
		exit 0
	fi

	local clean_version=$(get_version "$version")

	# Ensure that the Safe multisig version is `>= 0.1.0`.
	if [[ "$(printf "%s\n%s" "$clean_version" "0.1.0" | sort -V | head -n1)" == "$clean_version" && "$clean_version" != "0.1.0" ]]; then
		echo "${YELLOW}Safe multisig version \"${clean_version}\" is not supported!${RESET}"
		exit 0
	fi
}

# Utility function to calculate the domain hash.
calculate_domain_hash() {
	local version="$1"
	local domain_separator_typehash="$2"
	local domain_hash_args="$3"

	# Validate the Safe multisig version.
	validate_version "$version"

	local clean_version=$(get_version "$version")

	# Safe multisig versions `<= 1.2.0` use a legacy (i.e. without `chainId`) `DOMAIN_SEPARATOR_TYPEHASH` value.
	# Starting with version `1.3.0`, the `chainId` field was introduced: https://github.com/safe-global/safe-smart-account/pull/264.
	if [[ "$(printf "%s\n%s" "$clean_version" "1.2.0" | sort -V | head -n1)" == "$clean_version" ]]; then
		domain_separator_typehash="$DOMAIN_SEPARATOR_TYPEHASH_OLD"
		domain_hash_args="$domain_separator_typehash, $address"
	fi

	# Calculate the domain hash.
	local domain_hash=$(chisel eval "keccak256(abi.encode($domain_hash_args))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')
	echo "$domain_hash"
}

# Utility function to calculate the domain and message hashes.
calculate_hashes() {
	local chain_id="$1"
	local address="$2"
	local to="$3"
	local value="$4"
	local data="$5"
	local operation="$6"
	local safe_tx_gas="$7"
	local base_gas="$8"
	local gas_price="$9"
	local gas_token="${10}"
	local refund_receiver="${11}"
	local nonce="${12}"
	local data_decoded="${13}"
	local version="${14}"
	local update_global_safe_tx_hash="${15:-}"
	local update_global_safe_tx_hash_simulated="${16:-}"

	local domain_separator_typehash="$DOMAIN_SEPARATOR_TYPEHASH"
	local domain_hash_args="$domain_separator_typehash, $chain_id, $address"
	local safe_tx_typehash="$SAFE_TX_TYPEHASH"

	# Validate the Safe multisig version.
	validate_version "$version"

	local clean_version=$(get_version "$version")

	# Calculate the domain hash.
	local domain_hash=$(calculate_domain_hash "$version" "$domain_separator_typehash" "$domain_hash_args")

	# Calculate the data hash.
	# The dynamic value `bytes` is encoded as a `keccak256` hash of its content.
	# See: https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata.
	local data_hashed=$(printf "%s" "$data" | cast keccak)

	# Safe multisig versions `< 1.0.0` use a legacy (i.e. the parameter value `baseGas` was
	# called `dataGas` previously) `SAFE_TX_TYPEHASH` value. Starting with version `1.0.0`,
	# `baseGas` was introduced: https://github.com/safe-global/safe-smart-account/pull/90.
	if [[ "$(printf "%s\n%s" "$clean_version" "1.0.0" | sort -V | head -n1)" == "$clean_version" && "$clean_version" != "1.0.0" ]]; then
		safe_tx_typehash="$SAFE_TX_TYPEHASH_OLD"
	fi

	# Encode the message.
	local message=$(cast abi-encode "SafeTxStruct(bytes32,address,uint256,bytes32,uint8,uint256,uint256,uint256,address,address,uint256)" \
		"$safe_tx_typehash" \
		"$to" \
		"$value" \
		"$data_hashed" \
		"$operation" \
		"$safe_tx_gas" \
		"$base_gas" \
		"$gas_price" \
		"$gas_token" \
		"$refund_receiver" \
		"$nonce")

	# Calculate the message hash.
	local message_hash=$(cast keccak "$message")

	# Calculate the Safe transaction hash.
	local safe_tx_hash=$(chisel eval "keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), bytes32($domain_hash), bytes32($message_hash)))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

	# Print the retrieved transaction data.
	print_transaction_data "$address" "$to" "$value" "$data" "$operation" "$safe_tx_gas" "$base_gas" "$gas_price" "$gas_token" "$refund_receiver" "$nonce" "$message"
	# Print the ABI-decoded transaction data.
	print_decoded_data "$address" "$to" "$value" "$data" "$data_decoded"
	# Print the results with the same formatting for "Domain hash" and "Message hash" as a Ledger hardware device.
	print_hash_info "$domain_hash" "$message_hash" "$safe_tx_hash"

	# Store the Safe transaction hash so it can be captured by a calling function.
	if [[ -n "$update_global_safe_tx_hash" ]]; then
		global_safe_tx_hash="$safe_tx_hash"
		readonly global_safe_tx_hash
	fi

	# Store the simulated Safe transaction hash so it can be captured by a calling function.
	if [[ -n "$update_global_safe_tx_hash_simulated" ]]; then
		global_safe_tx_hash_simulated="$safe_tx_hash"
		readonly global_safe_tx_hash_simulated
	fi
}

# Utility function to calculate the domain and message hashes for a nested Safe multisig address.
calculate_nested_safe_hashes() {
	local chain_id="$1"
	local target_safe_address="$2"
	local nested_safe_address="$3"
	local nested_safe_nonce="$4"
	local safe_tx_hash="$5"
	local nested_safe_version="$6"

	# Set the fixed parameters for the `approveHash` transaction.
	local to="$target_safe_address"
	local value="0"
	# Encode the `approveHash(bytes32)` function call with the Safe transaction hash.
	# See (`approveHash` function): https://github.com/safe-global/safe-smart-account/blob/bdcfce3a76c4d1dfb256ac2ca971be7cfd6e493a/contracts/Safe.sol#L372-L379.
	# See (`execTransaction` function part): https://github.com/safe-global/safe-smart-account/blob/bdcfce3a76c4d1dfb256ac2ca971be7cfd6e493a/contracts/Safe.sol#L108-L143.
	# See (`checkNSignatures` function part): https://github.com/safe-global/safe-smart-account/blob/bdcfce3a76c4d1dfb256ac2ca971be7cfd6e493a/contracts/Safe.sol#L318-L323.
	# => `bytes4(keccak256("approveHash(bytes32)"));`
	local approve_hash_signature="0xd4d9bdcd"
	# => `abi.encodePacked(bytes4(keccak256("approveHash(bytes32)")), bytes32(safeTxHash));`
	local data="${approve_hash_signature}${safe_tx_hash#0x}"
	local operation="0"
	local safe_tx_gas="0"
	local base_gas="0"
	local gas_price="0"
	local gas_token="$ZERO_ADDRESS"
	local refund_receiver="$ZERO_ADDRESS"
	local nonce="$nested_safe_nonce"
	local data_decoded="{\"method\": \"approveHash\", \"parameters\": [{\"name\": \"hashToApprove\", \"type\": \"bytes32\", \"value\": \"$safe_tx_hash\"}]}"

	echo -e "\n${BOLD}${UNDERLINE}Nested Safe \`approveHash\` Transaction Data and Computed Hashes${RESET}"
	cat <<EOF

${YELLOW}The specified nested Safe at $nested_safe_address will use the following transaction to approve the primary transaction.${RESET}
EOF

	# Calculate the domain and message hashes for the specified nested Safe multisig address.
	calculate_hashes "$chain_id" \
		"$nested_safe_address" \
		"$to" \
		"$value" \
		"$data" \
		"$operation" \
		"$safe_tx_gas" \
		"$base_gas" \
		"$gas_price" \
		"$gas_token" \
		"$refund_receiver" \
		"$nonce" \
		"$data_decoded" \
		"$nested_safe_version"
}

# Utility function to validate the network name.
validate_network() {
	local network="$1"

	if [[ -z "$network" ]]; then
		echo -e "${BOLD}${RED}Network name is empty!${RESET}\n" >&2
		calculate_safe_hashes --list-networks >&2
		exit 1
	fi

	if [[ -z "${API_URLS[$network]:-}" || -z "${CHAIN_IDS[$network]:-}" ]]; then
		echo -e "${BOLD}${RED}Invalid network name: \"${network}\"${RESET}\n" >&2
		calculate_safe_hashes --list-networks >&2
		exit 1
	fi
}

# Utility function to retrieve the API URL of the selected network.
get_api_url() {
	local network="$1"
	validate_network "$network"
	echo "${API_URLS[$network]}"
}

# Utility function to retrieve the chain ID of the selected network.
get_chain_id() {
	local network="$1"
	validate_network "$network"
	echo "${CHAIN_IDS[$network]}"
}

# Utility function to validate the multisig address.
validate_address() {
	local address="$1"
	if [[ -z "$address" || ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
		echo -e "${BOLD}${RED}Invalid Ethereum address format: \"${address}\"${RESET}" >&2
		exit 1
	fi
}

# Utility function to validate a value parameter.
validate_value() {
	local value="$1"
	local name="$2"
	if [[ -z "$value" || ! "$value" =~ ^[0-9]+$ ]]; then
		echo -e "${BOLD}${RED}Invalid \`${name}\` value: \"${value}\". Must be a non-negative integer!${RESET}" >&2
		exit 1
	fi
}

# Utility function to warn the user if the transaction includes an untrusted delegate call.
warn_if_delegate_call() {
	local operation="$1"
	local to="$2"

	# Warn the user if `operation` equals `1`, implying a `delegatecall`, and if the `to` address is untrusted.
	# See: https://github.com/safe-global/safe-smart-account/blob/34359e8305d618b7d74e39ed370a6b59ab14f827/contracts/libraries/Enum.sol.
	if [[ "$operation" -eq 1 && ! " ${TRUSTED_FOR_DELEGATE_CALL[@]} " =~ " ${to} " ]]; then
		cat <<EOF

${RED}WARNING: The transaction includes an untrusted delegate call to address $to!
This may lead to unexpected behaviour or vulnerabilities. Please review it carefully before you sign!${RESET}

EOF
		delegate_call_warning_shown="true"
		readonly delegate_call_warning_shown
	fi
}

# Utility function to check for a potential gas token attack.
check_gas_token_attack() {
	local gas_price="$1"
	local gas_token="$2"
	local refund_receiver="$3"
	local warning_message=""

	if [[ "$gas_token" != "$ZERO_ADDRESS" && "$refund_receiver" != "$ZERO_ADDRESS" ]]; then
		warning_message+="${RED}WARNING: This transaction uses a custom gas token and a custom refund receiver.
This combination can be used to hide a rerouting of funds through gas refunds.${RESET}\n"
		if [[ "$gas_price" != "0" ]]; then
			warning_message+="${RED}Furthermore, the gas price is non-zero, which increases the potential for hidden value transfers.${RESET}\n"
		fi
	elif [[ "$gas_token" != "$ZERO_ADDRESS" ]]; then
		warning_message+="${YELLOW}WARNING: This transaction uses a custom gas token. Please verify that this is intended.${RESET}\n"
	elif [[ "$refund_receiver" != "$ZERO_ADDRESS" ]]; then
		warning_message+="${YELLOW}WARNING: This transaction uses a custom refund receiver. Please verify that this is intended.${RESET}\n"
	fi

	if [[ -n "$warning_message" ]]; then
		if [[ "$delegate_call_warning_shown" != "true" ]]; then
			echo -e "\n$warning_message"
		else
			echo -e "$warning_message"
		fi
	fi
}

# Utility function to locally simulate a transaction using `cast call` and print its execution trace.
simulate_transaction() {
	local address="$1"
	local to="$2"
	local value="$3"
	local data="$4"
	local operation="$5"
	local safe_tx_gas="$6"
	local base_gas="$7"
	local gas_price="$8"
	local gas_token="$9"
	local refund_receiver="${10}"
	local nonce="${11}"
	local rpc_url="${12}"

	# Generate a random signing wallet.
	local signer_wallet=$(cast wallet new)
	local signer_private_key=$(echo "$signer_wallet" | grep "Private key:" | awk '{print $3}')
	local signer_address=$(echo "$signer_wallet" | grep "Address:" | awk '{print $2}')

	# Set `nonce` equal to the current on-chain value `$current_nonce` of the configured multisig address `$address`.
	local current_nonce=$(cast call "$address" "nonce()(uint256)" --rpc-url "$rpc_url")
	if [[ "$nonce" != "$current_nonce" ]]; then
		nonce="$current_nonce"
	fi

	# Calculate the primary Safe transaction hash using the overridden `nonce`.
	# Suppress normal output (`stdout`) while still allowing errors (`stderr`) to be printed.
	calculate_hashes \
		"$chain_id" \
		"$address" \
		"$to" \
		"$value" \
		"$data" \
		"$operation" \
		"$safe_tx_gas" \
		"$base_gas" \
		"$gas_price" \
		"$gas_token" \
		"$refund_receiver" \
		"$nonce" \
		"$data_decoded" \
		"$version" \
		"" \
		"true" \
		>/dev/null

	# Sign the Safe transaction hash with the random signer's private key.
	local signature=$(cast wallet sign --private-key "$signer_private_key" --no-hash "$global_safe_tx_hash_simulated")

	# Generate the calldata for the `execTransaction` transaction.
	local safe_tx_payload=$(cast calldata "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)" \
		"$to" \
		"$value" \
		"$data" \
		"$operation" \
		"$safe_tx_gas" \
		"$base_gas" \
		"$gas_price" \
		"$gas_token" \
		"$refund_receiver" \
		"$signature")

	# The (partial) storage layout of the Safe contracts (since `v0.1.0`):
	# See: https://github.com/safe-global/safe-smart-account/blob/333f84083e58df8e70b03e7f7df1947c1d77b262/contracts/libraries/SafeStorage.sol.
	# - `masterCopy` (slot: 0, offset: 0, size: 20 bytes),
	# - `modules`    (slot: 1, offset: 0, size: 32 bytes),
	# - `owners`     (slot: 2, offset: 0, size: 32 bytes),
	# - `ownerCount` (slot: 3, offset: 0, size: 32 bytes),
	# - `threshold`  (slot: 4, offset: 0, size: 32 bytes),
	# - `nonce`      (slot: 5, offset: 0, size: 32 bytes).

	# The Solidity `mapping` slots are computed as `keccak256(abi.encode(key, mappingS​lot))` for value types.
	# See: https://docs.soliditylang.org/en/v0.8.30/internals/layout_in_storage.html#mappings-and-dynamic-arrays.
	# Calculate the storage slot for `signer_address` in the `owners` mapping.
	local owner_slot=$(cast keccak $(cast abi-encode "mappingOwnerSlot(address,uint256)" "$signer_address" "2"))

	echo -e "\n=========================="
	echo "= Transaction Simulation ="
	echo -e "==========================\n"

	cat <<EOF
${YELLOW}This simulation, run against the latest block, depends on data provided by your RPC provider. Using your own node is always recommended.

Please note that we override specific Safe contract storage slots for this call:
  - Set \`owners[signer_address] = address(0x1)\` to make a random \`signer_address\` address \`$signer_address\` an \`owner\`,
  - Set \`threshold = 1\` to allow single-owner execution,
  - Set \`nonce\` equal to the current on-chain value \`$current_nonce\` of the configured multisig address \`$address\`,
  - Disable the configured transaction and module guards.

Then execute the \`cast call --trace\` command with the transaction payload from \`signer_address\` address \`$signer_address\` using the overridden states:${RESET}
\`\`\`bash
${GREEN}cast call --trace --from "$signer_address" \\
  "$address" \\
  --data "$safe_tx_payload" \\
  --override-state-diff "$address:$owner_slot:1,$address:4:1,$address:$GUARD_STORAGE_SLOT:0,$address:$MODULE_GUARD_STORAGE_SLOT:0" \\
  --rpc-url "$rpc_url"
${RESET}\`\`\`
EOF

	print_header "Execution Traces"
	# Override specific Safe contract storage slots for this call:
	# - Set `owners[signer_address] = address(0x1)` to make `signer_address` an `owner`,
	# - Set `threshold = 1` to allow single-owner execution,
	# - Set `nonce` equal to the current on-chain value `current_nonce` of the configured multisig address `address`,
	# - Disable the configured transaction and module guards.
	# Then execute the `cast call --trace` command with the transaction payload from
	# `signer_address` using the overridden state.
	cast call --trace --from "$signer_address" \
		"$address" \
		--data "$safe_tx_payload" \
		--override-state-diff "$address:$owner_slot:1,$address:4:1,$address:5:$nonce,$address:$GUARD_STORAGE_SLOT:0,$address:$MODULE_GUARD_STORAGE_SLOT:0" \
		--rpc-url "$rpc_url"
}

# Utility function to validate the message file.
validate_message_file() {
	local message_file="$1"
	if [[ ! -f "$message_file" ]]; then
		echo -e "${BOLD}${RED}Message file not found: \"${message_file}\"!${RESET}" >&2
		exit 1
	fi
	if [[ ! -s "$message_file" ]]; then
		echo -e "${BOLD}${RED}Message file is empty: \"${message_file}\"!${RESET}" >&2
		exit 1
	fi
}

# Utility function to calculate the domain and message hashes for off-chain messages.
calculate_offchain_message_hashes() {
	local network="$1"
	local chain_id="$2"
	local address="$3"
	local message_file="$4"
	local version="$5"

	validate_message_file "$message_file"

	# Validate the Safe multisig version.
	validate_version "$version"

	local message_raw=$(<"$message_file")
	# Normalise line endings to `LF` (`\n`).
	message_raw=$(printf "%s" "$message_raw" | tr -d "\r")
	local hashed_message=$(printf "%s" "$message_raw" | cast hash-message)

	local domain_separator_typehash="$DOMAIN_SEPARATOR_TYPEHASH"
	local domain_hash_args="$domain_separator_typehash, $chain_id, $address"

	# Calculate the domain hash.
	local domain_hash=$(calculate_domain_hash "$version" "$domain_separator_typehash" "$domain_hash_args")

	# Calculate the message hash.
	local message_hash=$(chisel eval "keccak256(abi.encode(bytes32($SAFE_MSG_TYPEHASH), keccak256(abi.encode(bytes32($hashed_message)))))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

	# Calculate the Safe message hash.
	local safe_msg_hash=$(chisel eval "keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), bytes32($domain_hash), bytes32($message_hash)))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

	# Calculate and display the hashes.
	echo "==================================="
	echo "= Selected Network Configurations ="
	echo -e "===================================\n"
	print_field "Network" "$network"
	print_field "Chain ID" "$chain_id" true
	echo "===================================="
	echo "= Message Data and Computed Hashes ="
	echo "===================================="
	print_header "Message Data"
	print_field "Multisig address" "$address"
	print_field "Message" "$message_raw"
	print_header "Hashes"
	print_field "Safe message" "$hashed_message"
	print_field "Domain hash" "$(format_hash "$domain_hash")"
	print_field "Message hash" "$(format_hash "$message_hash")"
	print_field "Safe message hash" "$safe_msg_hash"
}

# Utility function to calculate the domain and message hashes for off-chain messages,
# using a nested Safe multisig address. Please note that off-chain messages are hashed
# and passed to a nested Safe via EIP-712 (https://eips.ethereum.org/EIPS/eip-712) objects.
calculate_nested_safe_offchain_message_hashes() {
	local chain_id="$1"
	local address="$2"
	local nested_safe_address="$3"
	local message_file="$4"
	local nested_safe_version="$5"

	validate_message_file "$message_file"

	# Validate the Safe multisig version.
	validate_version "$nested_safe_version"

	local message_raw=$(<"$message_file")
	# Normalise line endings to `LF` (`\n`).
	message_raw=$(printf "%s" "$message_raw" | tr -d "\r")
	local hashed_message=$(printf "%s" "$message_raw" | cast hash-message)

	local domain_separator_typehash="$DOMAIN_SEPARATOR_TYPEHASH"
	local domain_hash_args="$domain_separator_typehash, $chain_id, $nested_safe_address"

	# Calculate the Safe multisig domain hash.
	local safe_domain_hash=$(calculate_domain_hash "$nested_safe_version" "$domain_separator_typehash" "$domain_hash_args")

	# Calculate the EIP-712 message domain hash.
	local message_domain_hash=$(chisel eval "keccak256(abi.encode(bytes32($domain_separator_typehash), uint256($chain_id), address($address)))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

	# Encode the message. Please note the value `hashed_message` is treated as a string and encoded
	# as a `keccak256` hash of its content according to EIP-712 (https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata).
	local message=$(cast abi-encode "SafeMessage(bytes32,bytes32)" "$SAFE_MSG_TYPEHASH" "$(cast keccak "$hashed_message")")

	# Hash the message.
	local hashed_encoded_message=$(cast keccak "$message")

	# Calculate the Safe message.
	local safe_msg=$(chisel eval "keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), bytes32($message_domain_hash), bytes32($hashed_encoded_message)))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

	# Calculate the message hash.
	local message_hash=$(chisel eval "keccak256(abi.encode(bytes32($SAFE_MSG_TYPEHASH), keccak256(abi.encode(bytes32($safe_msg)))))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

	# Calculate the Safe message hash.
	local safe_msg_hash=$(chisel eval "keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), bytes32($safe_domain_hash), bytes32($message_hash)))" |
		awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

	echo -e "\n${BOLD}${UNDERLINE}Nested Safe Computed Hashes${RESET}"

	cat <<EOF

${YELLOW}The specified nested Safe at $nested_safe_address will sign the above displayed Safe message $hashed_message via an EIP-712 message object.${RESET}
EOF

	# Calculate and display the hashes.
	print_header "Hashes"
	print_field "Safe message" "$safe_msg"
	print_field "Domain hash" "$(format_hash "$safe_domain_hash")"
	print_field "Message hash" "$(format_hash "$message_hash")"
	print_field "Safe message hash" "$safe_msg_hash"
}

##############################################
# Safe Transaction/Message Hashes Calculator #
##############################################
# This function orchestrates the entire process of calculating the Safe transaction/message hashes:
# 1. Parses command-line arguments (`help`, `version`, `list-networks`, `network`, `address`, `nonce`,
#    `nested-safe-address`, `nested-safe-nonce`, `message`, `interactive`, `simulate`).
# 2. Validates that all required parameters are provided.
# 3. Retrieves the API URL and chain ID for the specified network.
# 4. Constructs the API endpoint URL.
# 5. If a message file is provided:
#    - Validates that no interactive mode is specified (as it's not applicable for off-chain message hashes).
#    - Validates that no simulation mode is specified (as it's not applicable for off-chain message hashes).
#    - Validates that no `nonce` or `nested-safe-nonce` is specified (as it's not applicable for off-chain message hashes).
#    - Calls `calculate_offchain_message_hashes` to compute and display the message hashes.
#    - If a nested Safe address is provided, invokes the `calculate_nested_safe_offchain_message_hashes` function with the nested
#      parameter values and displays the resulting hashes.
# 6. If a `nonce` is provided:
#    - Fetches the transaction data from the Safe transaction service API.
#    - Extracts the relevant transaction details from the API response.
#    - If the interactive mode is specified, overrides the desired parameter values.
#    - Warns the user if the transaction includes an untrusted delegate call.
#    - Checks for a potential gas token attack.
#    - Calls the `calculate_hashes` function to compute and display the results.
#    - If nested Safe parameters are provided, invokes the `calculate_nested_safe_hashes` function with the approval transaction
#      data and displays the resulting hashes.
#    - If the simulation mode is specified, invokes the `simulate_transaction` function with the transaction data and displays the
#      execution trace.
calculate_safe_hashes() {
	# Display the help message if no arguments are provided.
	if [[ $# -eq 0 ]]; then
		usage
	fi

	# Initialise the CLI parameters.
	local network=""
	local address=""
	local nonce=""
	local nested_safe_address=""
	local nested_safe_nonce=""
	local message_file=""
	local interactive=""
	local rpc_url=""

	# Parse the command line arguments.
	# Please note that `--help`, `--version`, and `--list-networks` can be used
	# independently or alongside other options without causing the script to fail.
	# They are special options that can be called without affecting the rest of
	# the command processing.
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help) usage 0 ;;
		--version) get_latest_git_commit_hash ;;
		--list-networks) list_networks ;;
		--network)
			network="$2"
			shift 2
			;;
		--address)
			address="$2"
			shift 2
			;;
		--nonce)
			nonce="$2"
			shift 2
			;;
		--nested-safe-address)
			nested_safe_address="$2"
			shift 2
			;;
		--nested-safe-nonce)
			nested_safe_nonce="$2"
			shift 2
			;;
		--message)
			message_file="$2"
			shift 2
			;;
		--interactive)
			interactive="1"
			shift
			;;
		--simulate)
			rpc_url="$2"
			shift 2
			;;
		*)
			echo "Unknown option: $1" >&2
			usage
			;;
		esac
	done

	# Validate if the required parameters have the correct format.
	validate_network "$network"
	validate_address "$address"

	# Get the API URL and chain ID for the specified network.
	local api_url=$(get_api_url "$network")
	local chain_id=$(get_chain_id "$network")
	local endpoint="${api_url}/api/v2/safes/${address}/multisig-transactions/?nonce=${nonce}"

	# Get the Safe multisig version.
	local version=$(curl -sf "${api_url}/api/v1/safes/${address}/" | jq -r ".version // \"0.0.0\"" || echo "0.0.0")

	# Safe's API allows 1 request per second without authentication.
	# Wait slightly longer to allow for potential future requests without hitting rate limits.
	sleep 1.2

	# Validate the nested Safe address if provided.
	local nested_safe_version=""
	if [[ -n "$nested_safe_address" ]]; then
		# Validate the nested Safe address.
		validate_address "$nested_safe_address"

		# Get the nested Safe multisig version.
		nested_safe_version=$(curl -sf "${api_url}/api/v1/safes/${nested_safe_address}/" | jq -r ".version // \"0.0.0\"" || echo "0.0.0")

		# Safe's API allows 1 request per second without authentication.
		# Wait slightly longer to allow for potential future requests without hitting rate limits.
		sleep 1.2
	fi

	# If --interactive mode is enabled, the version value can be overridden by the user's input.
	if [[ -n "$interactive" ]]; then
		cat <<EOF

Interactive mode is enabled. You will be prompted to enter values for parameters such as \`version\`, \`to\`, \`value\`, and others.

${RED}If it's not already obvious: This is YOLO mode – BE VERY CAREFUL!${RESET}

${YELLOW}IMPORTANT:
- Leaving a parameter empty will use the value retrieved from the Safe transaction service API, displayed as the "default value".
  If the value is unavailable (e.g. if the API endpoint is down), it will default to zero.
- If multiple transactions share the same nonce, the first transaction in the array will be selected to provide the default values.
- No warnings will be shown if multiple transactions share the same nonce. It's recommended to first run a validation without interactive mode enabled!
- Some parameters (e.g., \`version\`, \`to\`, \`operation\`) enforce valid options, but not all inputs are strictly validated.
  Please double-check your entries before proceeding.${RESET}

EOF
		read -rp "Enter the Safe multisig version (default: $version): " user_version
		if [[ -n "$user_version" ]]; then
			version="$user_version"
		fi
		validate_version $version

		# If a nested Safe is used, allow overriding its version as well.
		if [[ -n "$nested_safe_address" ]]; then
			read -rp "Enter the nested Safe multisig version (default: $nested_safe_version): " user_nested_version
			if [[ -n "$user_nested_version" ]]; then
				nested_safe_version="$user_nested_version"
			fi
			validate_version $nested_safe_version
		fi
	fi

	# Calculate the domain and message hashes for off-chain messages.
	if [[ -n "$message_file" ]]; then
		if [[ -n "$interactive" ]]; then
			echo -e "${RED}Error: When calculating off-chain message hashes, do not specify the \`--interactive\` mode!${RESET}" >&2
			exit 1
		fi
		if [[ -n "$rpc_url" ]]; then
			echo -e "${RED}Error: When calculating off-chain message hashes, do not specify the \`--simulate\` mode!${RESET}" >&2
			exit 1
		fi
		if [[ -n "$nonce" ]]; then
			echo -e "${RED}Error: When calculating off-chain message hashes, do not specify a nonce!${RESET}" >&2
			exit 1
		fi
		calculate_offchain_message_hashes "$network" "$chain_id" "$address" "$message_file" "$version"
		# If a nested Safe address is provided, calculate the domain and message hashes for off-chain messages
		# using the nested Safe multisig address.
		if [[ -n "$nested_safe_nonce" ]]; then
			echo -e "${RED}Error: When calculating off-chain message hashes using a nested Safe, do not specify a nonce for the nested Safe!${RESET}" >&2
			exit 1
		elif [[ -n "$nested_safe_address" ]]; then
			calculate_nested_safe_offchain_message_hashes "$chain_id" "$address" "$nested_safe_address" "$message_file" "$nested_safe_version"
		fi
		exit 0
	fi

	# Validate if the nonce parameter has the correct format.
	# Please note that the nonce validation is intentionally placed
	# after the domain and message hash calculations for off-chain
	# messages, where a `nonce` (and `nested-safe-nonce`) is not required.
	validate_value "$nonce" "nonce"
	if [[ -n "$nested_safe_address" ]]; then
		validate_value "$nested_safe_nonce" "nested-safe-nonce"
	fi

	# Fetch the transaction data from the API.
	local response=$(curl -sf "$endpoint" || echo "{}")

	# Set the default index value for the transaction array.
	local idx=0

	if [[ -z "$interactive" ]]; then
		local count=$(echo "$response" | jq -r ".count // \"0\"")

		# Inform the user that no transactions are available for the specified nonce.
		if [[ $count -eq 0 ]]; then
			echo "${YELLOW}No transaction is available for this nonce!${RESET}"
			exit 0
		# Notify the user about multiple transactions with identical nonce values and prompt for user input.
		elif [[ $count -gt 1 ]]; then
			cat <<EOF
${YELLOW}Several transactions with identical nonce values have been detected.
This occurrence is normal if you are deliberately replacing an existing transaction.
However, if your Safe interface displays only a single transaction, this could indicate
potential irregular activity requiring your attention.${RESET}

Kindly specify the transaction's array value (available range: 0-$((${count} - 1))).
You can find the array values at the following endpoint:
${GREEN}$endpoint${RESET}

Please enter the index of the array:
EOF

			while true; do
				read -r idx

				# Validate if user input is a number.
				if ! [[ $idx =~ ^[0-9]+$ ]]; then
					echo "${RED}Error: Please enter a valid number!${RESET}"
					continue
				fi

				local array_value=$(echo "$response" | jq ".results[$idx]")

				if [[ $array_value == null ]]; then
					echo "${RED}Error: No transaction found at index $idx! Please try again.${RESET}"
					continue
				fi

				printf "\n"

				break
			done
		fi
	fi

	local to=$(echo "$response" | jq -r ".results[$idx].to // \"$ZERO_ADDRESS\"")
	local value=$(echo "$response" | jq -r ".results[$idx].value // \"0\"")
	local data=$(echo "$response" | jq -r ".results[$idx].data // \"0x\"")
	local operation=$(echo "$response" | jq -r ".results[$idx].operation // \"0\"")
	local safe_tx_gas=$(echo "$response" | jq -r ".results[$idx].safeTxGas // \"0\"")
	local base_gas=$(echo "$response" | jq -r ".results[$idx].baseGas // \"0\"")
	local gas_price=$(echo "$response" | jq -r ".results[$idx].gasPrice // \"0\"")
	local gas_token=$(echo "$response" | jq -r ".results[$idx].gasToken // \"$ZERO_ADDRESS\"")
	local refund_receiver=$(echo "$response" | jq -r ".results[$idx].refundReceiver // \"$ZERO_ADDRESS\"")
	local data_decoded=$(echo "$response" | jq -r ".results[$idx].dataDecoded // \"0x\"")

	# If --interactive mode is enabled, the parameter values can be overridden by the user's input.
	# Overriding nested Safe transaction values is not allowed.
	if [[ -n "$interactive" ]]; then
		read -rp "Enter the \`to\` address (default: $to): " to_input
		to="${to_input:-$to}"
		validate_address "$to"

		read -rp "Enter the \`value\` (default: $value): " value_input
		value="${value_input:-$value}"
		validate_value $value "value"

		read -rp "Enter the \`data\` (default: $data): " data_input
		data="${data_input:-$data}"

		while true; do
			read -rp "Enter the \`operation\` (default: $operation; 0 = CALL, 1 = DELEGATECALL): " operation_input
			operation_input="${operation_input:-$operation}"
			if [[ "$operation_input" == "0" || "$operation_input" == "1" ]]; then
				operation="$operation_input"
				break
			else
				cat <<EOF
${YELLOW}Invalid input. Please enter either 0 (CALL) or 1 (DELEGATECALL).${RESET}
EOF
			fi
		done

		read -rp "Enter the \`safeTxGas\` (default: $safe_tx_gas): " safe_tx_gas_input
		safe_tx_gas="${safe_tx_gas_input:-$safe_tx_gas}"
		validate_value $safe_tx_gas "safeTxGas"

		read -rp "Enter the \`baseGas\` (default: $base_gas): " base_gas_input
		base_gas="${base_gas_input:-$base_gas}"
		validate_value $base_gas "baseGas"

		read -rp "Enter the \`gasPrice\` (default: $gas_price): " gas_price_input
		gas_price="${gas_price_input:-$gas_price}"
		validate_value $gas_price "gasPrice"

		read -rp "Enter the \`gasToken\` (default: $gas_token): " gas_token_input
		gas_token="${gas_token_input:-$gas_token}"
		validate_address "$gas_token"

		read -rp "Enter the \`refundReceiver\` (default: $refund_receiver): " refund_receiver_input
		refund_receiver="${refund_receiver_input:-$refund_receiver}"
		validate_address "$refund_receiver"

		data_decoded="interactive"
	fi

	# Warn the user if the transaction includes an untrusted delegate call.
	warn_if_delegate_call "$operation" "$to"
	# Check for a potential gas token attack.
	check_gas_token_attack "$gas_price" "$gas_token" "$refund_receiver"

	# Calculate and display the hashes.
	echo "==================================="
	echo "= Selected Network Configurations ="
	echo -e "===================================\n"
	print_field "Network" "$network"
	print_field "Chain ID" "$chain_id" true

	echo "========================================"
	echo "= Transaction Data and Computed Hashes ="
	echo "========================================"

	# Add a header to indicate that this is the primary transaction when using a nested Safe.
	if [[ -n "$nested_safe_address" ]]; then
		echo -e "\n${BOLD}${UNDERLINE}Primary Safe Transaction Data and Computed Hashes${RESET}"
	fi

	# Calculate the primary Safe transaction hash and display the data.
	calculate_hashes "$chain_id" \
		"$address" \
		"$to" \
		"$value" \
		"$data" \
		"$operation" \
		"$safe_tx_gas" \
		"$base_gas" \
		"$gas_price" \
		"$gas_token" \
		"$refund_receiver" \
		"$nonce" \
		"$data_decoded" \
		"$version" \
		"true"

	# Calculate the `approveHash` transaction hash if nested Safe parameters are provided.
	if [[ -n "$nested_safe_address" && -n "$nested_safe_nonce" ]]; then
		calculate_nested_safe_hashes "$chain_id" "$address" "$nested_safe_address" "$nested_safe_nonce" "$global_safe_tx_hash" "$nested_safe_version"
	elif [[ -n "$nested_safe_nonce" && -z "$nested_safe_address" ]]; then
		echo -e "${RED}Error: The \`--nested-safe-address\` parameter is missing!${RESET}" >&2
		echo -e "${RED}Both \`--nested-safe-address\` and \`--nested-safe-nonce\` must be provided for transaction hashes!${RESET}" >&2
		exit 1
	fi

	# Simulate the transaction locally with `cast call` and print its trace if an RPC URL is provided.
	if [[ -n "$rpc_url" ]]; then
		simulate_transaction "$address" \
			"$to" \
			"$value" \
			"$data" \
			"$operation" \
			"$safe_tx_gas" \
			"$base_gas" \
			"$gas_price" \
			"$gas_token" \
			"$refund_receiver" \
			"$nonce" \
			"$rpc_url"
	fi

	exit 0
}

calculate_safe_hashes "$@"
