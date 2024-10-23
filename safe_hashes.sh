#!/bin/bash

########################
# Don't trust, verify! #
########################

# @license GNU Affero General Public License v3.0 only
# @author pcaversaccio

# Enable strict error handling:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit.
# -o pipefail: Return the exit status of the first failed command in a pipeline.
set -euo pipefail

# Set the terminal formatting constants.
readonly GREEN="\e[32m"
readonly UNDERLINE="\e[4m"
readonly RESET="\e[0m"

# Set the type hash constants.
# => `keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");`
# See: https://github.com/safe-global/safe-smart-account/blob/a0a1d4292006e26c4dbd52282f4c932e1ffca40f/contracts/Safe.sol#L54-L57.
DOMAIN_SEPARATOR_TYPEHASH="0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218"
# => `keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)");`
# See: https://github.com/safe-global/safe-smart-account/blob/a0a1d4292006e26c4dbd52282f4c932e1ffca40f/contracts/Safe.sol#L59-L62.
SAFE_TX_TYPEHASH="0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8"

# Define the supported networks from the Safe transaction service.
# See https://docs.safe.global/core-api/transaction-service-supported-networks.
declare -A API_URLS=(
    [arbitrum]="https://safe-transaction-arbitrum.safe.global"
    [aurora]="https://safe-transaction-aurora.safe.global"
    [avalanche]="https://safe-transaction-avalanche.safe.global"
    [base]="https://safe-transaction-base.safe.global"
    [base-sepolia]="https://safe-transaction-base-sepolia.safe.global"
    [blast]="https://safe-transaction-blast.safe.global"
    [bsc]="https://safe-transaction-bsc.safe.global"
    [celo]="https://safe-transaction-celo.safe.global"
    [ethereum]="https://safe-transaction-mainnet.safe.global"
    [gnosis]="https://safe-transaction-gnosis-chain.safe.global"
    [gnosis-chiado]="https://safe-transaction-chiado.safe.global"
    [linea]="https://safe-transaction-linea.safe.global"
    [mantle]="https://safe-transaction-mantle.safe.global"
    [optimism]="https://safe-transaction-optimism.safe.global"
    [polygon]="https://safe-transaction-polygon.safe.global"
    [polygon-zkevm]="https://safe-transaction-zkevm.safe.global"
    [scroll]="https://safe-transaction-scroll.safe.global"
    [sepolia]="https://safe-transaction-sepolia.safe.global"
    [worldchain]="https://safe-transaction-worldchain.safe.global"
    [xlayer]="https://safe-transaction-xlayer.safe.global"
    [zksync]="https://safe-transaction-zksync.safe.global"
)

# Define the chain IDs of the supported networks from the Safe transaction service.
declare -A CHAIN_IDS=(
    [arbitrum]=42161
    [aurora]=1313161554
    [avalanche]=43114
    [base]=8453
    [base-sepolia]=84532
    [blast]=81457
    [bsc]=56
    [celo]=42220
    [ethereum]=1
    [gnosis]=100
    [gnosis-chiado]=10200
    [linea]=59144
    [mantle]=5000
    [optimism]=10
    [polygon]=137
    [polygon-zkevm]=1101
    [scroll]=534352
    [sepolia]=11155111
    [worldchain]=480
    [xlayer]=195
    [zksync]=324
)

# Utility function to display the usage information.
usage() {
    echo "Usage: $0 [--help] [--list-networks] --network <network> --address <address> --nonce <nonce>"
    echo
    echo "Options:"
    echo "  --help              Display this help message"
    echo "  --list-networks     List all supported networks and their chain IDs"
    echo "  --network <network> Specify the network (required)"
    echo "  --address <address> Specify the Safe multisig address (required)"
    echo "  --nonce <nonce>     Specify the transaction nonce (required)"
    echo
    echo "Example:"
    echo "  $0 --network ethereum --address 0x1234...5678 --nonce 42"
    exit 1
}

# Utility function to list all supported networks.
list_networks() {
    echo "Supported Networks:"
    for network in "${!CHAIN_IDS[@]}"; do
        echo "  $network (${CHAIN_IDS[$network]})"
    done
    exit 0
}

# Utility function to print a section header.
print_header() {
    local header=$1
    if [ -t 1 ] && tput sgr0 >/dev/null 2>&1; then
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
    local empty_line=${3:-false}
    if [ -t 1 ] && tput sgr0 >/dev/null 2>&1; then
        # Terminal supports formatting.
        printf "%s: ${GREEN}%s${RESET}\n" "$label" "$value"
    else
        # Fallback for terminals without formatting support.
        printf "%s: %s\n" "$label" "$value"
    fi

    # Print an empty line if requested.
    if [ "$empty_line" == "true" ]; then
        echo
    fi
}

# Utility function to print the transaction data.
print_transaction_data() {
    local address=$1
    local to=$2
    local data=$3
    local message=$4

    print_header "Data"
    print_field "Address" "$address"
    print_field "To" "$to"
    print_field "Data" "$data"
    print_field "Message" "$message"
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

    # Calculate the domain hash.
    local domain_hash=$(chisel eval "keccak256(abi.encode($DOMAIN_SEPARATOR_TYPEHASH, $chain_id, $address))" | awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

    # Calculate the data hash.
    # The dynamic value `bytes` is encoded as a `keccak256` hash of its content.
    # See: https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata.
    local data_hashed=$(cast keccak "$data")
    # Encode the message.
    local message=$(cast abi-encode "SafeTxStruct(bytes32,address,uint256,bytes32,uint8,uint256,uint256,uint256,address,address,uint256)" "$SAFE_TX_TYPEHASH" "$to" "$value" "$data_hashed" "$operation" "$safe_tx_gas" "$base_gas" "$gas_price" "$gas_token" "$refund_receiver" "$nonce")
    # Calculate the message hash.
    local message_hash=$(cast keccak "$message")

    # Calculate the Safe transaction hash.
    local safe_tx_hash=$(chisel eval "keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), bytes32($domain_hash), bytes32($message_hash)))" | awk '/Data:/ {gsub(/\x1b\[[0-9;]*m/, "", $3); print $3}')

    # Print the retrieved transaction data.
    print_transaction_data "$address" "$to" "$data" "$message"
    # Print the results with the same formatting for "Domain hash" and "Message hash" as a Ledger hardware device.
    print_hash_info "$domain_hash" "$message_hash" "$safe_tx_hash"
}

# Utility function to retrieve the API URL of the selected network.
get_api_url() {
    echo "${API_URLS[$1]:-Invalid network}" || exit 1
}

# Utility function to retrieve the chain ID of the selected network.
get_chain_id() {
    echo "${CHAIN_IDS[$1]:-Invalid network}" || exit 1
}

# Safe Transaction Hashes Calculator
# This function orchestrates the entire process of calculating the Safe transaction hash:
# 1. Parses command-line arguments (`network`, `address`, `nonce`).
# 2. Validates that all required parameters are provided.
# 3. Retrieves the API URL and chain ID for the specified network.
# 4. Constructs the API endpoint URL.
# 5. Fetches the transaction data from the Safe transaction service API.
# 6. Extracts the relevant transaction details from the API response.
# 7. Calls the `calculate_hashes` function to compute and display the results.
calculate_safe_tx_hashes() {
    local network="" address="" nonce=""

    # Parse the command line arguments.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) usage ;;
            --network) network="$2"; shift 2 ;;
            --address) address="$2"; shift 2 ;;
            --nonce) nonce="$2"; shift 2 ;;
            --list-networks) list_networks ;;
            *) echo "Unknown option: $1" >&2; usage ;;
        esac
    done

    # Check if the required parameters are provided.
    [[ -z "$network" || -z "$address" || -z "$nonce" ]] && usage

    # Get the API URL and chain ID for the specified network.
    local api_url=$(get_api_url "$network")
    local chain_id=$(get_chain_id "$network")
    local endpoint="${api_url}/api/v1/safes/${address}/multisig-transactions/?nonce=${nonce}"

    # Fetch the transaction data from the API.
    local response=$(curl -s "$endpoint")
    local to=$(echo "$response" | jq -r '.results[0].to // "0x0000000000000000000000000000000000000000"')
    local value=$(echo "$response" | jq -r '.results[0].value // "0"')
    local data=$(echo "$response" | jq -r '.results[0].data // "0x"')
    local operation=$(echo "$response" | jq -r '.results[0].operation // "0"')
    local safe_tx_gas=$(echo "$response" | jq -r '.results[0].safeTxGas // "0"')
    local base_gas=$(echo "$response" | jq -r '.results[0].baseGas // "0"')
    local gas_price=$(echo "$response" | jq -r '.results[0].gasPrice // "0"')
    local gas_token=$(echo "$response" | jq -r '.results[0].gasToken // "0x0000000000000000000000000000000000000000"')
    local refund_receiver=$(echo "$response" | jq -r '.results[0].refundReceiver // "0x0000000000000000000000000000000000000000"')
    local nonce=$(echo "$response" | jq -r '.results[0].nonce // "0"')

    # Calculate and display the hashes.
    echo "==================================="
    echo "= Selected Network Configurations ="
    echo -e "===================================\n"
    print_field "Network" "$network"
    print_field "Chain ID" "$chain_id" true
    echo "============================"
    echo "= Data and Computed Hashes ="
    echo "============================"
    calculate_hashes "$chain_id" "$address" "$to" "$value" "$data" "$operation" "$safe_tx_gas" "$base_gas" "$gas_price" "$gas_token" "$refund_receiver" "$nonce"
}

calculate_safe_tx_hashes "$@"
