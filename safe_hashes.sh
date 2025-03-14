#!/usr/bin/env bash

########################
# Don't trust, verify! #
########################

# @license GNU Affero General Public License v3.0 only
# @author pcaversaccio

# Set the terminal formatting constants.
readonly GREEN="\e[32m"
readonly RED="\e[31m"
readonly UNDERLINE="\e[4m"
readonly BOLD="\e[1m"
readonly RESET="\e[0m"

# Check the Bash version compatibility.
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
    echo -e "${BOLD}${RED}Error: This script requires Bash 4.0 or higher.${RESET}"
    echo -e "${BOLD}${RED}Current version: $BASH_VERSION${RESET}"
    echo -e "${BOLD}${RED}Please upgrade your Bash installation.${RESET}"
    echo -e "${BOLD}${RED}If you've already upgraded via Homebrew, try running:${RESET}"
    echo -e "${BOLD}${RED}/opt/homebrew/bin/bash $0 $@${RESET}"
    exit 1
fi

# Utility function to ensure all required tools are installed.
check_required_tools() {
    local tools=("curl" "jq" "chisel" "cast")
    local missing_tools=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
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

# Set the zero address as a global constant.
readonly ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

# Set a global flag indicating whether a delegate call warning was already displayed
# to the user. Used to determine proper spacing between multiple warnings.
delegate_call_warning_shown=false

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

# Set the trusted (i.e. for delegate calls) `MultiSend` addresses:
# MultiSend `v1.1.1` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.1.1/multi_send.json#L7,
# MultiSend `v1.3.0` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/multi_send.json#L7,
# MultiSend `v1.3.0` (eip155): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/multi_send.json#L11,
# MultiSend `v1.3.0` (zksync): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/multi_send.json#L15,
# Multisend `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.4.1/multi_send.json#L7.
declare -a -r MultiSend=(
    "0x8D29bE29923b68abfDD21e541b9374737B49cdAD" # MultiSend `v1.1.1` (canonical).
    "0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761" # MultiSend `v1.3.0` (canonical).
    "0x998739BFdAAdde7C933B942a68053933098f9EDa" # MultiSend `v1.3.0` (eip155).
    "0x0dFcccB95225ffB03c6FBB2559B530C2B7C8A912" # MultiSend `v1.3.0` (zksync).
    "0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526" # MultiSend `v1.4.1` (canonical).
)

# Set the trusted (i.e. for delegate calls) `MultiSendCallOnly` addresses:
# MultiSendCallOnly `v1.3.0` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/multi_send_call_only.json#L7,
# MultiSendCallOnly `v1.3.0` (eip155): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/multi_send_call_only.json#L11,
# MultiSendCallOnly `v1.3.0` (zksync): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/multi_send_call_only.json#L15,
# MultiSendCallOnly `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.4.1/multi_send_call_only.json#L7.
declare -a -r MultiSendCallOnly=(
    "0x40A2aCCbd92BCA938b02010E17A5b8929b49130D" # MultiSendCallOnly `v1.3.0` (canonical).
    "0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B" # MultiSendCallOnly `v1.3.0` (eip155).
    "0xf220D3b4DFb23C4ade8C88E526C1353AbAcbC38F" # MultiSendCallOnly `v1.3.0` (zksync).
    "0x9641d764fc13c8B624c04430C7356C1C7C8102e2" # MultiSendCallOnly `v1.4.1` (canonical).
)

# Set the trusted (i.e. for delegate calls) `SafeMigration` addresses:
# SafeMigration `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.4.1/safe_migration.json#L7.
declare -a -r SafeMigration=(
    "0x526643F69b81B008F46d95CD5ced5eC0edFFDaC6" # SafeMigration `v1.4.1` (canonical).
)

# Set the trusted (i.e. for delegate calls) `SafeToL2Migration` addresses:
# SafeToL2Migration `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.4.1/safe_to_l2_migration.json#L7.
declare -a -r SafeToL2Migration=(
    "0xfF83F6335d8930cBad1c0D439A841f01888D9f69" # SafeToL2Migration `v1.4.1` (canonical).
)

# Set the trusted (i.e. for delegate calls) `SignMessageLib` addresses:
# SignMessageLib `v1.3.0` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/sign_message_lib.json#L7,
# SignMessageLib `v1.3.0` (eip155): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/sign_message_lib.json#L11,
# SignMessageLib `v1.3.0` (zksync): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.3.0/sign_message_lib.json#L15,
# SignMessageLib `v1.4.1` (canonical): https://github.com/safe-global/safe-deployments/blob/4e25b09f62a4acec92b4ebe6b8ae496b3852d440/src/assets/v1.4.1/sign_message_lib.json#L7.
declare -a -r SignMessageLib=(
    "0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2" # SignMessageLib `v1.3.0` (canonical).
    "0x98FFBBF51bb33A056B08ddf711f289936AafF717" # SignMessageLib `v1.3.0` (eip155).
    "0x357147caf9C0cCa67DfA0CF5369318d8193c8407" # SignMessageLib `v1.3.0` (zksync).
    "0xd53cd0aB83D845Ac265BE939c57F53AD838012c9" # SignMessageLib `v1.4.1` (canonical).
)

# Set the trusted (i.e. for delegate calls) contract addresses.
# See: https://github.com/safe-global/safe-transaction-service/blob/c3b42f0bebff74b99fcdd958aee54b149e27eca5/safe_transaction_service/contracts/management/commands/setup_safe_contracts.py#L10-L16.
declare -A -r TRUSTED_FOR_DELEGATE_CALL=(
    ["MultiSend"]="${MultiSend[@]}"
    ["MultiSendCallOnly"]="${MultiSendCallOnly[@]}"
    ["SafeMigration"]="${SafeMigration[@]}"
    ["SafeToL2Migration"]="${SafeToL2Migration[@]}"
    ["SignMessageLib"]="${SignMessageLib[@]}"
)

# Define the supported networks from the Safe transaction service.
# See https://docs.safe.global/advanced/smart-account-supported-networks?service=Transaction+Service.
declare -A -r API_URLS=(
    ["arbitrum"]="https://safe-transaction-arbitrum.safe.global"
    ["aurora"]="https://safe-transaction-aurora.safe.global"
    ["avalanche"]="https://safe-transaction-avalanche.safe.global"
    ["base"]="https://safe-transaction-base.safe.global"
    ["base-sepolia"]="https://safe-transaction-base-sepolia.safe.global"
    ["blast"]="https://safe-transaction-blast.safe.global"
    ["bsc"]="https://safe-transaction-bsc.safe.global"
    ["celo"]="https://safe-transaction-celo.safe.global"
    ["ethereum"]="https://safe-transaction-mainnet.safe.global"
    ["gnosis"]="https://safe-transaction-gnosis-chain.safe.global"
    ["gnosis-chiado"]="https://safe-transaction-chiado.safe.global"
    ["linea"]="https://safe-transaction-linea.safe.global"
    ["mantle"]="https://safe-transaction-mantle.safe.global"
    ["optimism"]="https://safe-transaction-optimism.safe.global"
    ["polygon"]="https://safe-transaction-polygon.safe.global"
    ["polygon-zkevm"]="https://safe-transaction-zkevm.safe.global"
    ["scroll"]="https://safe-transaction-scroll.safe.global"
    ["sepolia"]="https://safe-transaction-sepolia.safe.global"
    ["worldchain"]="https://safe-transaction-worldchain.safe.global"
    ["xlayer"]="https://safe-transaction-xlayer.safe.global"
    ["zksync"]="https://safe-transaction-zksync.safe.global"
)

# Define the chain IDs of the supported networks from the Safe transaction service.
declare -A -r CHAIN_IDS=(
    ["arbitrum"]="42161"
    ["aurora"]="1313161554"
    ["avalanche"]="43114"
    ["base"]="8453"
    ["base-sepolia"]="84532"
    ["blast"]="81457"
    ["bsc"]="56"
    ["celo"]="42220"
    ["ethereum"]="1"
    ["gnosis"]="100"
    ["gnosis-chiado"]="10200"
    ["linea"]="59144"
    ["mantle"]="5000"
    ["optimism"]="10"
    ["polygon"]="137"
    ["polygon-zkevm"]="1101"
    ["scroll"]="534352"
    ["sepolia"]="11155111"
    ["worldchain"]="480"
    ["xlayer"]="196"
    ["zksync"]="324"
)

# Utility function to display the usage information.
usage() {
    cat <<EOF
Usage: $0 [--help] [--list-networks]
       --network <network> --address <address> --nonce <nonce>
       --message <file> --interactive

Options:
  --help              Display this help message
  --version           Display the latest local commit hash (=version) of the script
  --list-networks     List all supported networks and their chain IDs
  --network <network> Specify the network (required)
  --address <address> Specify the Safe multisig address (required)
  --nonce <nonce>     Specify the transaction nonce (required for transaction hashes)
  --message <file>    Specify the message file (required for off-chain message hashes)
  --interactive       Use the interactive mode (optional for transaction hashes)

Example for transaction hashes:
  $0 --network ethereum --address 0x1234...5678 --nonce 42

Example for transaction hashes (interactive mode):
  $0 --network ethereum --address 0x1234...5678 --nonce 42 --interactive

Example for off-chain message hashes:
  $0 --network ethereum --address 0x1234...5678 --message message.txt
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
    local header=$1
    if [[ -t 1 ]] && tput sgr0 >/dev/null 2>&1; then
        # Terminal supports formatting.
        printf "\n${UNDERLINE}%s${RESET}\n" "$header"
    else
        # Fallback for terminals without formatting support.
        printf "\n%s\n" "> $header:"
    fi
}

# Utility function to print a labelled value.
print_field() {
    local label=$1
    local value=$2
    local empty_line="${3:-false}"

    if [[ -t 1 ]] && tput sgr0 >/dev/null 2>&1; then
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
    local address=$1
    local to=$2
    local value=$3
    local data=$4
    local operation=$5
    local safe_tx_gas=$6
    local base_gas=$7
    local gas_price=$8
    local gas_token=$9
    local refund_receiver=${10}
    local nonce=${11}
    local message=${12}

    print_header "Transaction Data"
    print_field "Multisig address" "$address"
    print_field "To" "$to"
    print_field "Value" "$value"
    print_field "Data" "$data"
    case "$operation" in
        1) 
            if [[ "$operation" -eq 1 && ! " ${TRUSTED_FOR_DELEGATE_CALL[@]} " =~ " ${to} " ]]; then
                print_field "Operation" "Delegatecall $(tput setaf 1)(UNTRUSTED delegatecall; carefully verify before proceeding!)$(tput sgr0)"
            else
                print_field "Operation" "Delegatecall $(tput setaf 3)(trusted delegatecall)$(tput sgr0)"
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
    local hash=$1
    local prefix="${hash:0:2}"
    local rest="${hash:2}"
    echo "${prefix,,}${rest^^}"
}

# Utility function to print the hash information.
print_hash_info() {
    local domain_hash=$1
    local message_hash=$2
    local safe_tx_hash=$3

    print_header "Hashes"
    print_field "Domain hash" "$(format_hash "$domain_hash")"
    print_field "Message hash" "$(format_hash "$message_hash")"
    print_field "Safe transaction hash" "$safe_tx_hash"
}

# Utility function to print the ABI-decoded transaction data.
print_decoded_data() {
    local data=$1
    local data_decoded=$2

    if [[ "$data" == "0x" && "$data_decoded" == "0x" ]]; then
        print_field "Method" "0x (ETH Transfer)"
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
            echo
            echo -e "${BOLD}${RED}WARNING: The \"$method\" function modifies the owners or threshold of the Safe. Proceed with caution!${RESET}"
            ;;
        esac

        # Check for sensitive functions in nested transactions.
        echo "$parameters" | jq -c ".[] | .valueDecoded[]? | select(.dataDecoded != null)" | while read -r nested_param; do
            nested_method=$(echo "$nested_param" | jq -r ".dataDecoded.method")

            if [[ "$nested_method" =~ ^(addOwnerWithThreshold|removeOwner|swapOwner|changeThreshold)$ ]]; then
                echo
                echo -e "${BOLD}${RED}WARNING: The \"$nested_method\" function modifies the owners or threshold of the Safe! Proceed with caution!${RESET}"
            fi
        done
    fi
}

# Utility function to extract the clean Safe multisig version.
get_version() {
    local version=$1
    # Safe multisig versions can have the format `X.Y.Z+L2`.
    # Remove any suffix after and including the `+` in the version string for comparison.
    local clean_version=$(echo "$version" | sed "s/+.*//")
    echo "$clean_version"
}

# Utility function to validate the Safe multisig version.
validate_version() {
    local version=$1
    if [[ -z "$version" ]]; then
        echo "$(tput setaf 3)No Safe multisig contract found for the specified network. Please ensure that you have selected the correct network.$(tput sgr0)"
        exit 0
    fi

    local clean_version=$(get_version "$version")

    # Ensure that the Safe multisig version is `>= 0.1.0`.
    if [[ "$(printf "%s\n%s" "$clean_version" "0.1.0" | sort -V | head -n1)" == "$clean_version" && "$clean_version" != "0.1.0" ]]; then
        echo "$(tput setaf 3)Safe multisig version \"${clean_version}\" is not supported!$(tput sgr0)"
        exit 0
    fi
}

# Utility function to calculate the domain hash.
calculate_domain_hash() {
    local version=$1
    local domain_separator_typehash=$2
    local domain_hash_args=$3

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
    local chain_id=$1
    local address=$2
    local to=$3
    local value=$4
    local data=$5
    local operation=$6
    local safe_tx_gas=$7
    local base_gas=$8
    local gas_price=$9
    local gas_token=${10}
    local refund_receiver=${11}
    local nonce=${12}
    local data_decoded=${13}
    local version=${14}

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
    local data_hashed=$(cast keccak "$data")

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
    print_decoded_data "$data" "$data_decoded"
    # Print the results with the same formatting for "Domain hash" and "Message hash" as a Ledger hardware device.
    print_hash_info "$domain_hash" "$message_hash" "$safe_tx_hash"
}

# Utility function to validate the network name.
validate_network() {
    local network="$1"

    if [[ -z "$network" ]]; then
        echo -e "${BOLD}${RED}Network name is empty!${RESET}" >&2
        echo
        calculate_safe_hashes --list-networks >&2
        exit 1
    fi

    if [[ -z "${API_URLS[$network]:-}" || -z "${CHAIN_IDS[$network]:-}" ]]; then
        echo -e "${BOLD}${RED}Invalid network name: \"${network}\"${RESET}\n" >&2
        echo
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

$(tput setaf 1)WARNING: The transaction includes an untrusted delegate call to address $to!
This may lead to unexpected behaviour or vulnerabilities. Please review it carefully before you sign!$(tput sgr0)

EOF
        delegate_call_warning_shown=true
        readonly delegate_call_warning_shown
    fi
}

# Utility function to check for a potential gas token attack.
check_gas_token_attack() {
    local gas_price=$1
    local gas_token=$2
    local refund_receiver=$3
    local warning_message=""

    if [[ "$gas_token" != "$ZERO_ADDRESS" && "$refund_receiver" != "$ZERO_ADDRESS" ]]; then
        warning_message+="$(tput setaf 1)WARNING: This transaction uses a custom gas token and a custom refund receiver.
This combination can be used to hide a rerouting of funds through gas refunds.$(tput sgr0)\n"
        if [[ "$gas_price" != "0" ]]; then
            warning_message+="$(tput setaf 1)Furthermore, the gas price is non-zero, which increases the potential for hidden value transfers.$(tput sgr0)\n"
        fi
    elif [[ "$gas_token" != "$ZERO_ADDRESS" ]]; then
        warning_message+="$(tput setaf 3)WARNING: This transaction uses a custom gas token. Please verify that this is intended.$(tput sgr0)\n"
    elif [[ "$refund_receiver" != "$ZERO_ADDRESS" ]]; then
        warning_message+="$(tput setaf 3)WARNING: This transaction uses a custom refund receiver. Please verify that this is intended.$(tput sgr0)\n"
    fi

    if [[ -n "$warning_message" ]]; then
        if [[ "$delegate_call_warning_shown" != "true" ]]; then
            echo -e "\n$warning_message"
        else
            echo -e "$warning_message"
        fi
    fi
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
    local network=$1
    local chain_id=$2
    local address=$3
    local message_file=$4
    local version=$5

    validate_message_file "$message_file"

    # Validate the Safe multisig version.
    validate_version "$version"

    local message_raw=$(< "$message_file")
    # Normalise line endings to `LF` (`\n`).
    message_raw=$(echo "$message_raw" | tr -d "\r")
    local hashed_message=$(cast hash-message "$message_raw")

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
    print_field "Raw message hash" "$hashed_message"
    print_field "Domain hash" "$(format_hash "$domain_hash")"
    print_field "Message hash" "$(format_hash "$message_hash")"
    print_field "Safe message hash" "$safe_msg_hash"
}

# Safe Transaction/Message Hashes Calculator
# This function orchestrates the entire process of calculating the Safe transaction/message hashes:
# 1. Parses command-line arguments (`help`, `version`, `list-networks`, `network`, `address`, `nonce`, `message`, `interactive`).
# 2. Validates that all required parameters are provided.
# 3. Retrieves the API URL and chain ID for the specified network.
# 4. Constructs the API endpoint URL.
# 5. If a message file is provided:
#    - Validates that no interactive mode is specified (as it's not applicable for off-chain message hashes).
#    - Validates that no nonce is specified (as it's not applicable for off-chain message hashes).
#    - Calls `calculate_offchain_message_hashes` to compute and display the message hashes.
# 6. If a nonce is provided:
#    - Fetches the transaction data from the Safe transaction service API.
#    - Extracts the relevant transaction details from the API response.
#    - If the interactive mode is specified, overrides the desired parameter values.
#    - Warns the user if the transaction includes an untrusted delegate call.
#    - Checks for a potential gas token attack.
#    - Calls the `calculate_hashes` function to compute and display the results.
calculate_safe_hashes() {
    # Display the help message if no arguments are provided.
    if [[ $# -eq 0 ]]; then
        usage
    fi

    local network="" address="" nonce="" message_file="" interactive=""

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
            --network) network="$2"; shift 2 ;;
            --address) address="$2"; shift 2 ;;
            --nonce) nonce="$2"; shift 2 ;;
            --message) message_file="$2"; shift 2 ;;
            --interactive) interactive="1"; shift ;;
            *) echo "Unknown option: $1" >&2; usage ;;
        esac
    done

    # Validate if the required parameters have the correct format.
    validate_network "$network"
    validate_address "$address"

    # Get the API URL and chain ID for the specified network.
    local api_url=$(get_api_url "$network")
    local chain_id=$(get_chain_id "$network")
    local endpoint="${api_url}/api/v1/safes/${address}/multisig-transactions/?nonce=${nonce}"

    # Get the Safe multisig version.
    local version=$(curl -sf "${api_url}/api/v1/safes/${address}/" | jq -r ".version // \"0.0.0\"" || echo "0.0.0")

    # If --interactive mode is enabled, the version value can be overridden by the user's input.
    if [[ -n "$interactive" ]]; then
            cat <<EOF

Interactive mode is enabled. You will be prompted to enter values for parameters such as \`version\`, \`to\`, \`value\`, and others.

$(tput setaf 1)If it's not already obvious: This is YOLO mode – BE VERY CAREFUL!$(tput sgr0)

$(tput setaf 3)IMPORTANT:
- Leaving a parameter empty will use the value retrieved from the Safe transaction service API, displayed as the "default value".
  If the value is unavailable (e.g. if the API endpoint is down), it will default to zero.
- If multiple transactions share the same nonce, the first transaction in the array will be selected to provide the default values.
- No warnings will be shown if multiple transactions share the same nonce. It's recommended to first run a validation without interactive mode enabled!
- Some parameters (e.g., \`version\`, \`to\`, \`operation\`) enforce valid options, but not all inputs are strictly validated.
  Please double-check your entries before proceeding.$(tput sgr0)

EOF
        read -rp "Enter the Safe multisig version (default: $version): " user_version
        if [[ -n "$user_version" ]]; then
            version="$user_version"
        fi
        validate_version $version
    fi

    # Calculate the domain and message hashes for off-chain messages.
    if [[ -n "$message_file" ]]; then
        if [[ -n "$interactive" ]]; then
            echo -e "${RED}Error: When calculating off-chain message hashes, do not specify the \`--interactive\` mode.${RESET}" >&2
            exit 1
        fi
        if [[ -n "$nonce" ]]; then
            echo -e "${RED}Error: When calculating off-chain message hashes, do not specify a nonce.${RESET}" >&2
            exit 1
        fi
        calculate_offchain_message_hashes "$network" "$chain_id" "$address" "$message_file" "$version"
        exit 0
    fi

    # Validate if the nonce parameter has the correct format.
    # Please note that the nonce validation is intentionally placed
    # after the domain and message hash calculations for off-chain
    # messages, where a nonce is not required.
    validate_value "$nonce" "nonce"

    # Fetch the transaction data from the API.
    local response=$(curl -sf "$endpoint" || echo "{}")

    # Set the default index value for the transaction array.
    local idx=0

    if [[ -z "$interactive" ]]; then
        local count=$(echo "$response" | jq -r ".count // \"0\"")

        # Inform the user that no transactions are available for the specified nonce.
        if [[ $count -eq 0 ]]; then
            echo "$(tput setaf 3)No transaction is available for this nonce!$(tput sgr0)"
            exit 0
        # Notify the user about multiple transactions with identical nonce values and prompt for user input.
        elif [[ $count -gt 1 ]]; then
            cat <<EOF
$(tput setaf 3)Several transactions with identical nonce values have been detected.
This occurrence is normal if you are deliberately replacing an existing transaction.
However, if your Safe interface displays only a single transaction, this could indicate
potential irregular activity requiring your attention.$(tput sgr0)

Kindly specify the transaction's array value (available range: 0-$((${count} - 1))).
You can find the array values at the following endpoint:
$(tput setaf 2)$endpoint$(tput sgr0)

Please enter the index of the array:
EOF

            while true; do
                read -r idx

                # Validate if user input is a number.
                if ! [[ $idx =~ ^[0-9]+$ ]]; then
                    echo "$(tput setaf 1)Error: Please enter a valid number!$(tput sgr0)"
                    continue
                fi

                local array_value=$(echo "$response" | jq ".results[$idx]")

                if [[ $array_value == null ]]; then
                    echo "$(tput setaf 1)Error: No transaction found at index $idx. Please try again.$(tput sgr0)"
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
$(tput setaf 3)Invalid input. Please enter either 0 (CALL) or 1 (DELEGATECALL).$(tput sgr0)
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
        "$version"
}

calculate_safe_hashes "$@"
