# Safe Multisig Transaction Hashes <!-- omit from toc -->

[![👮‍♂️ Sanity checks](https://github.com/pcaversaccio/safe-tx-hashes-util/actions/workflows/checks.yml/badge.svg)](https://github.com/pcaversaccio/safe-tx-hashes-util/actions/workflows/checks.yml)
[![License: AGPL-3.0-only](https://img.shields.io/badge/License-AGPL--3.0--only-blue)](https://www.gnu.org/licenses/agpl-3.0)

```console
|)0/\/'T TR|\_|5T, \/3R1FY! 🫡
```

This Bash [script](./safe_hashes.sh) calculates the Safe transaction hashes by retrieving transaction details from the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview) and computing both the domain and message hashes using the [EIP-712](https://eips.ethereum.org/EIPS/eip-712) standard.

> [!NOTE]
> This Bash [script](./safe_hashes.sh) relies on the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview), which requires transactions to be proposed and _logged_ in the service before they can be retrieved. Consequently, the initial transaction proposer cannot access the transaction at the proposal stage, making this approach incompatible with 1-of-1 multisigs.[^1] A simple and effective solution is to use the [`--interactive` mode](#interactive-mode), which gracefully defaults to zero values when no transaction is logged, allowing you to fully customise all transaction parameters.

> [!IMPORTANT]
> All Safe multisig versions starting from `0.1.0` and newer are supported.

- [Security Best Practices for Using This Script](#security-best-practices-for-using-this-script)
- [Supported Networks](#supported-networks)
- [Usage](#usage)
  - [macOS Users: Upgrading Bash](#macos-users-upgrading-bash)
    - [Optional: Set the New Bash as Your Default Shell](#optional-set-the-new-bash-as-your-default-shell)
  - [Docker Usage](#docker-usage)
    - [Building the Docker Image](#building-the-docker-image)
    - [Basic Usage](#basic-usage)
    - [Using Message Files](#using-message-files)
    - [With Environment Variables](#with-environment-variables)
- [Safe Transaction Hashes](#safe-transaction-hashes)
  - [Interactive Mode](#interactive-mode)
  - [Transaction Simulation](#transaction-simulation)
  - [Nested Safes](#nested-safes)
- [Safe Message Hashes](#safe-message-hashes)
- [Trust Assumptions](#trust-assumptions)
- [Community-Maintained User Interface Implementations](#community-maintained-user-interface-implementations)
- [💸 Donation](#-donation)

## Security Best Practices for Using This Script

**Read This Before Proceeding!**

- **Rule 1**: Use a dedicated device running a secure operating system, such as [Tails](https://tails.net) or [Qubes OS](https://www.qubes-os.org), solely for verifying and signing transactions. This device **must not** be used for any other activities, such as browsing, messaging, emailing, or social media. It should only be powered on to connect to the multisig interface, execute this Bash [script](./safe_hashes.sh), verify the transaction, sign it, and then shut down immediately afterward. If you feel the urge to check X, don't, or I'll appear in your dreams!
- **Rule 2**: Always independently decode and verify transaction calldata. Don't sign _untrusted_ delegate calls (see the main [script](./safe_hashes.sh) for a list of trusted `delegatecall`able contracts). Do not copy calldata from the Safe UI's copy button. Instead, manually copy the calldata directly from your wallet extension (e.g., MetaMask). You can decode the calldata using Etherscan's [Input Data Decoder](https://etherscan.io/inputdatadecoder). For further guidance on verifying Safe wallet transactions and performing basic transaction checks, **READ THESE RESOURCES AND ACT ON THEM**: [How to verify Safe wallet transactions on a hardware wallet](https://help.safe.global/en/articles/276344-how-to-verify-safe-wallet-transactions-on-a-hardware-wallet) and [How to perform basic transaction checks on Safe wallet](https://help.safe.global/en/articles/276343-how-to-perform-basic-transactions-checks-on-safe-wallet). **Do not skip this step!**
- **Rule 3**: Adhere strictly to Rule 1 and Rule 2, and follow [How to Multisig](https://howtomultisig.com) carefully.

## Supported Networks

> [!NOTE]
> The supported networks are ordered alphabetically by their identifier.

- Arbitrum (identifier: `arbitrum`, chain ID: `42161`)
- Aurora (identifier: `aurora`, chain ID: `1313161554`)
- Avalanche (identifier: `avalanche`, chain ID: `43114`)
- Base (identifier: `base`, chain ID: `8453`)
- Base Sepolia (identifier: `base-sepolia`, chain ID: `84532`)
- Berachain (identifier: `berachain`, chain ID: `80094`)
- Botanix (identifier: `botanix`, chain ID: `3637`)
- BSC (BNB Smart Chain) (identifier: `bsc`, chain ID: `56`)
- Celo (identifier: `celo`, chain ID: `42220`)
- Codex (identifier: `codex`, chain ID: `81224`)
- Ethereum (identifier: `ethereum`, chain ID: `1`)
- Gnosis (identifier: `gnosis`, chain ID: `100`)
- Gnosis Chiado (identifier: `gnosis-chiado`, chain ID: `10200`)
- Hemi (identifier: `hemi`, chain ID: `43111`)
- Ink (identifier: `ink`, chain ID: `57073`)
- Katana (identifier: `katana`, chain ID: `747474`)
- Lens (identifier: `lens`, chain ID: `232`)
- Linea (identifier: `linea`, chain ID: `59144`)
- Mantle (identifier: `mantle`, chain ID: `5000`)
- opBNB (identifier: `opbnb`, chain ID: `204`)
- OP (Optimism) (identifier: `optimism`, chain ID: `10`)
- peaq (identifier: `peaq`, chain ID: `3338`)
- Polygon (identifier: `polygon`, chain ID: `137`)
- Polygon zkEVM (identifier: `polygon-zkevm`, chain ID: `1101`)
- Scroll (identifier: `scroll`, chain ID: `534352`)
- Sepolia (identifier: `sepolia`, chain ID: `11155111`)
- Sonic (identifier: `sonic`, chain ID: `146`)
- Unichain (identifier: `unichain`, chain ID: `130`)
- World Chain (identifier: `worldchain`, chain ID: `480`)
- XDC Network (identifier: `xdc`, chain ID: `50`)
- X Layer (identifier: `xlayer`, chain ID: `196`)
- ZKsync Era (identifier: `zksync`, chain ID: `324`)

## Usage

> [!NOTE]
> Ensure that [`cast`](https://github.com/foundry-rs/foundry/tree/master/crates/cast) and [`chisel`](https://github.com/foundry-rs/foundry/tree/master/crates/chisel) are installed locally. For installation instructions, refer to this [guide](https://getfoundry.sh/introduction/installation/). This [script](./safe_hashes.sh) is designed to work with the latest _stable_ versions of [`cast`](https://github.com/foundry-rs/foundry/tree/master/crates/cast) and [`chisel`](https://github.com/foundry-rs/foundry/tree/master/crates/chisel), starting from version [`1.3.5`](https://github.com/foundry-rs/foundry/releases/tag/v1.3.5).

> [!TIP]
> For macOS users, please refer to the [macOS Users: Upgrading Bash](#macos-users-upgrading-bash) section. Alternatively, you can use the Docker container, which comes pre-installed with all required dependencies. For details, see the [Docker Usage](#docker-usage) section below.

```console
./safe_hashes.sh [--help] [--version] [--list-networks] --network <network> --address <address>
                 [--nonce <nonce>] [--nested-safe-address <address>] [--nested-safe-nonce <nonce>]
                 [--message <file>] [--interactive] [--simulate <rpc_url>]
```

**Options:**

- `--help`: Display this help message.
- `--version`: Display the latest local commit hash (=version) of the script.
- `--list-networks`: List all supported networks and their chain IDs.
- `--network <network>`: Specify the network (e.g., `ethereum`, `polygon`) (**required**).
- `--address <address>`: Specify the Safe multisig address (**required**).
- `--nonce <nonce>`: Specify the transaction nonce (required for transaction hashes).
- `--nested-safe-address <address>`: Specify the nested Safe multisig address (optional for transaction hashes or off-chain message hashes).
- `--nested-safe-nonce <nonce>`: Specify the nonce for the nested Safe transaction (optional for transaction hashes).
- `--message <file>`: Specify the message file (required for off-chain message hashes).
- `--interactive`: Use the interactive mode (optional for transaction hashes).
- `--simulate <rpc_url>`: Output the `cast call --trace` result in addition to the transaction hashes using the specified RPC URL (optional for transaction hashes).

> [!NOTE]
> Please note that `--help`, `--version`, and `--list-networks` can be used independently or alongside other options without causing the script to fail. They are special options that can be called without affecting the rest of the command processing.

Before you invoke the [script](./safe_hashes.sh), make it executable:

```console
chmod +x safe_hashes.sh
```

> [!TIP]
> The [script](./safe_hashes.sh) is already set as _executable_ in the repository, so you can run it immediately after cloning or pulling the repository without needing to change permissions.

If you feel fancy, you can also try:

```console
curl -fsSL https://raw.githubusercontent.com/pcaversaccio/safe-tx-hashes-util/main/install.sh | bash
```

To enable _debug mode_, set the `DEBUG` environment variable to `true` before running the [script](./safe_hashes.sh):

```console
DEBUG=true ./safe_hashes.sh ...
```

This will print each command before it is executed, which is helpful when troubleshooting.

The colour output is auto-detected and can be controlled with:

- [`NO_COLOR=true`](https://no-color.org) — disables all colours,

```console
NO_COLOR=true ./safe_hashes.sh ...
```

- [`FORCE_COLOR=true`](https://force-color.org) — forces colour output.

```console
FORCE_COLOR=true ./safe_hashes.sh ...
```

Only the exact value `true` is accepted to avoid accidental activation. If both are set, `NO_COLOR` takes precedence and disables all formatting. Otherwise, colour is enabled only if output is to a terminal, [`tput`](https://linux.die.net/man/1/tput) is available, and the terminal supports at least the 8 standard ANSI colours.

### macOS Users: Upgrading Bash

This [script](./safe_hashes.sh) requires Bash [`4.0`](https://tldp.org/LDP/abs/html/bashver4.html) or higher due to its use of associative arrays (introduced in Bash [`4.0`](https://tldp.org/LDP/abs/html/bashver4.html)). Unfortunately, macOS ships by default with Bash `3.2` due to licensing requirements. To use this [script](./safe_hashes.sh), install a newer version of Bash through [Homebrew](https://brew.sh):

1. Install [Homebrew](https://brew.sh) if you haven't already:

```console
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Install the latest version of Bash:

```console
brew install bash
```

3. Verify that you are using Bash version [`4.0`](https://tldp.org/LDP/abs/html/bashver4.html) or higher:

```console
bash --version
```

#### Optional: Set the New Bash as Your Default Shell

1. Find the path to your Bash installation (`BASH_PATH`):

```console
which bash
```

2. Add the new shell to the list of allowed shells:

Depending on your Mac's architecture and where [Homebrew](https://brew.sh) installs Bash, you will use one of the following commands:

```console
# For Intel-based Macs or if Homebrew is installed in the default location.
sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
```

or

```console
# For Apple Silicon (M1/M2) Macs or if you installed Homebrew using the default path for Apple Silicon.
sudo bash -c 'echo /opt/homebrew/bin/bash >> /etc/shells'
```

3. Set the new Bash as your default shell:

```console
chsh -s BASH_PATH
```

Make sure to replace `BASH_PATH` with the actual path you retrieved in step 1.

### Docker Usage

Using [Docker](https://www.docker.com), you can run the [script](./safe_hashes.sh) in a containerised environment with all dependencies pre-installed. This is useful if you do not wish to install the required tools locally, or if you are on a system where installation is difficult.

#### Building the Docker Image

Build the [Docker](https://www.docker.com) image using [Docker Compose](https://docs.docker.com/compose/):

```console
docker-compose build
```

#### Basic Usage

To run the [script](./safe_hashes.sh) using [Docker Compose](https://docs.docker.com/compose/), use the [`docker-compose.yml](./docker-compose.yml) file provided in the repository. The container is named `safe-tx-hashes-util`.

Example displaying help:

```console
docker-compose run --rm safe-tx-hashes-util --help
```

Example calculating the Safe transaction hashes:

```console
docker-compose run --rm safe-tx-hashes-util --network arbitrum --address 0x111CEEee040739fD91D29C34C33E6B3E112F2177 --nonce 234
```

#### Using Message Files

When calculating message hashes, you need to provide a local directory containing your message file. The included [`docker-compose.yml`](./docker-compose.yml) configuration mounts the `./data` directory by default.

```console
# First, create a `data` directory and add your message file.
~$ mkdir -p data
~$ echo "Your message content here" > data/message.txt

# Run the container with the mounted directory.
~$ docker-compose run --rm safe-tx-hashes-util \
  --network sepolia \
  --address 0x657ff0D4eC65D82b2bC1247b0a558bcd2f80A0f1 \
  --message /data/message.txt
```

#### With Environment Variables

You can pass environment variables directly via [Docker Compose](https://docs.docker.com/compose/):

```console
# Disable all formatting.
docker-compose run --rm -e NO_COLOR=true safe-tx-hashes-util \
  --network arbitrum \
  --address 0x111CEEee040739fD91D29C34C33E6B3E112F2177 \
  --nonce 234
```

> [!IMPORTANT]
> Running in a [Docker](https://www.docker.com) container offers isolation, but it is important to always follow the [Security Best Practices](#security-best-practices-for-using-this-script).

## Safe Transaction Hashes

To calculate the Safe transaction hashes for a specific transaction, you need to specify the `network`, `address`, and `nonce` parameters. An example:

```console
./safe_hashes.sh --network arbitrum --address 0x111CEEee040739fD91D29C34C33E6B3E112F2177 --nonce 234
```

The [script](./safe_hashes.sh) will output the domain, message, and Safe transaction hashes, allowing you to easily verify them against the values displayed on your Ledger hardware wallet screen:

```console
===================================
= Selected Network Configurations =
===================================

Network: arbitrum
Chain ID: 42161

========================================
= Transaction Data and Computed Hashes =
========================================

> Transaction Data:
Multisig address: 0x111CEEee040739fD91D29C34C33E6B3E112F2177
To: 0x111CEEee040739fD91D29C34C33E6B3E112F2177
Value: 0
Data: 0x0d582f130000000000000000000000000c75fa5a5f1c0997e3eea425cfa13184ed0ec9e50000000000000000000000000000000000000000000000000000000000000003
Operation: Call
Safe Transaction Gas: 0
Base Gas: 0
Gas Price: 0
Gas Token: 0x0000000000000000000000000000000000000000
Refund Receiver: 0x0000000000000000000000000000000000000000
Nonce: 234
Encoded message: 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8000000000000000000000000111ceeee040739fd91d29c34c33e6b3e112f21770000000000000000000000000000000000000000000000000000000000000000b34f85cea7c4d9f384d502fc86474cd71ff27a674d785ebd23a4387871b8cbfe00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ea
Method: addOwnerWithThreshold
Parameters: [
  {
    "name": "owner",
    "type": "address",
    "value": "0x0c75Fa5a5F1C0997e3eEA425cFA13184ed0eC9e5"
  },
  {
    "name": "_threshold",
    "type": "uint256",
    "value": "3"
  }
]

WARNING: The "addOwnerWithThreshold" function modifies the owners or threshold of the Safe. Proceed with caution!

> Hashes:
Domain hash: 0x1CF7F9B1EFE3BC47FE02FD27C649FEA19E79D66040683A1C86C7490C80BF7291
Message hash: 0xD9109EA63C50ECD3B80B6B27ED5C5A9FD3D546C2169DFB69BFA7BA24CD14C7A5
Safe transaction hash: 0x0cb7250b8becd7069223c54e2839feaed4cee156363fbfe5dd0a48e75c4e25b3
```

> To see an example of a standard ETH transfer, run the command: `./safe_hashes.sh --network ethereum --address 0x8FA3b4570B4C96f8036C13b64971BA65867eEB48 --nonce 39` and review the output.

To list all supported networks:

```console
./safe_hashes.sh --list-networks
```

### Interactive Mode

> [!WARNING]
> If it's not already obvious: This is YOLO mode – BE VERY CAREFUL!

When using `--interactive` mode, you will be prompted to provide values for various parameters such as `version`, `to`, `value`, and others. If you leave any parameter empty, the default value displayed in the terminal will be used. These defaults are either retrieved from the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview) or, in case of failure, fall back to zero values. This allows you to customise the parameters or proceed with the API-sourced defaults.

**Read This Before Proceeding:**

- Leaving a parameter empty will use the value retrieved from the Safe transaction service API, displayed as the "default value". If the value is unavailable (e.g. if the API endpoint is down), it will default to zero.
- If multiple transactions share the same nonce, the first transaction in the array will be selected to provide the default values.
- **No warnings will be shown if multiple transactions share the same nonce.** It's recommended to first run a validation without interactive mode enabled!
- Some parameters (e.g., `version`, `to`, `operation`) enforce valid options, but not all inputs are strictly validated. **Please double-check your entries before proceeding.**

As an example, invoke the following command:

```console
./safe_hashes.sh --network arbitrum --address 0x111CEEee040739fD91D29C34C33E6B3E112F2177 --nonce 234 --interactive
```

The final output will look like this:

```console
Interactive mode is enabled. You will be prompted to enter values for parameters such as `version`, `to`, `value`, and others.

If it's not already obvious: This is YOLO mode – BE VERY CAREFUL!

IMPORTANT:
- Leaving a parameter empty will use the value retrieved from the Safe transaction service API, displayed as the "default value".
  If the value is unavailable (e.g. if the API endpoint is down), it will default to zero.
- If multiple transactions share the same nonce, the first transaction in the array will be selected to provide the default values.
- No warnings will be shown if multiple transactions share the same nonce. It's recommended to first run a validation without interactive mode enabled!
- Some parameters (e.g., `version`, `to`, `operation`) enforce valid options, but not all inputs are strictly validated.
  Please double-check your entries before proceeding.

Enter the Safe multisig version (default: 1.3.0+L2):
Enter the `to` address (default: 0x111CEEee040739fD91D29C34C33E6B3E112F2177):
Enter the `value` (default: 0): 1000
Enter the `data` (default: 0x0d582f130000000000000000000000000c75fa5a5f1c0997e3eea425cfa13184ed0ec9e50000000000000000000000000000000000000000000000000000000000000003):
Enter the `operation` (default: 0; 0 = CALL, 1 = DELEGATECALL): 1
Enter the `safeTxGas` (default: 0):
Enter the `baseGas` (default: 0):
Enter the `gasPrice` (default: 0): 50
Enter the `gasToken` (default: 0x0000000000000000000000000000000000000000): 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
Enter the `refundReceiver` (default: 0x0000000000000000000000000000000000000000): 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

WARNING: The transaction includes an untrusted delegate call to address `0x111CEEee040739fD91D29C34C33E6B3E112F2177`!
This may lead to unexpected behaviour or vulnerabilities. Please review it carefully before you sign!

WARNING: This transaction uses a custom gas token and a custom refund receiver.
This combination can be used to hide a rerouting of funds through gas refunds.
Furthermore, the gas price is non-zero, which increases the potential for hidden value transfers.

===================================
= Selected Network Configurations =
===================================

Network: arbitrum
Chain ID: 42161

========================================
= Transaction Data and Computed Hashes =
========================================

> Transaction Data:
Multisig address: 0x111CEEee040739fD91D29C34C33E6B3E112F2177
To: 0x111CEEee040739fD91D29C34C33E6B3E112F2177
Value: 1000
Data: 0x0d582f130000000000000000000000000c75fa5a5f1c0997e3eea425cfa13184ed0ec9e50000000000000000000000000000000000000000000000000000000000000003
Operation: Delegatecall (UNTRUSTED delegatecall; carefully verify before proceeding!)
Safe Transaction Gas: 0
Base Gas: 0
Gas Price: 50
Gas Token: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
Refund Receiver: 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
Nonce: 234
Encoded message: 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8000000000000000000000000111ceeee040739fd91d29c34c33e6b3e112f217700000000000000000000000000000000000000000000000000000000000003e8b34f85cea7c4d9f384d502fc86474cd71ff27a674d785ebd23a4387871b8cbfe0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000032000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa9604500000000000000000000000000000000000000000000000000000000000000ea
Method: Unavailable in interactive mode
Parameters: Unavailable in interactive mode

> Hashes:
Domain hash: 0x1CF7F9B1EFE3BC47FE02FD27C649FEA19E79D66040683A1C86C7490C80BF7291
Message hash: 0xC7E826933DA60E6AC3E2246ED0563A26A920A65BEAA9089D784AC96234141BB3
Safe transaction hash: 0xc818fceb1cace51c1a4039c4c66fc73d95eccc298104c9c52debac604b9f4e04
```

### Transaction Simulation

> [!WARNING]
> A simulation depends on data provided by your RPC provider. Using your own node is always recommended.

You can simulate a transaction using the `--simulate` option with an RPC URL. This runs [`cast call --trace`](https://getfoundry.sh/cast/reference/call/) against the _latest_ block to produce a detailed execution trace. Use this option to check exactly how the transaction will execute _before_ signing. As an example, invoke the following command:

```console
./safe_hashes.sh --network ethereum --address 0x5EA1d9A6dDC3A0329378a327746D71A2019eC332 --nonce 6 --simulate https://eth.llamarpc.com
```

The [script](./safe_hashes.sh) produces the following output:

````console
...

> Hashes:
Domain hash: 0x58122EA8F001782FACC66EE5495A6B8B29730FADF352D8608CA86BD31569FCF5
Message hash: 0xE992E061576268328FAC9175D6AEA3DEFD4C3BEF83A0C6FE08F6AA5A222CBC45
Safe transaction hash: 0x27a0c4abf624b15b776f544a4b31ed4d50dee2b677c6497fbadf4f7a73be705e

==========================
= Transaction Simulation =
==========================

This simulation, run against the latest block, depends on data provided by your RPC provider. Using your own node is always recommended.

Please note that we override specific Safe contract storage slots for this call:
  - Set `owners[signer_address] = address(0x1)` to make a random `signer_address` address `0xD5AEB612f43919FCbfFd0eEa734D0E9130D14b2e` an `owner`,
  - Set `threshold = 1` to allow single-owner execution,
  - Set `nonce` equal to the current on-chain value `6` of the configured multisig address `0x5EA1d9A6dDC3A0329378a327746D71A2019eC332`,
  - Disable the configured transaction and module guards.

Then execute the `cast call --trace` command with the transaction payload from `signer_address` address `0xD5AEB612f43919FCbfFd0eEa734D0E9130D14b2e` using the overridden states:
```bash
cast call --trace --from "0xD5AEB612f43919FCbfFd0eEa734D0E9130D14b2e" \
  "0x5EA1d9A6dDC3A0329378a327746D71A2019eC332" \
  --data "0x6a7612020000000000000000000000009641d764fc13c8b624c04430c7356c1c7c8102e200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001848d80ff0a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000013200cfbfac74c26f8647cbdb8c5caf80bb5b32e4313400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044dd43a79f000000000000000000000000f46c6d6e62f59d9222f3812874211df07cf7b318000000000000000000000000000000000000000000000000000000000000000100a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000001fe27a73cd9f0b3c53b6e936d0b4f9b2f8ca3367000000000000000000000000000000000000000000000000000000002faf0800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004101427eae1606844b055aabb63778fc9e523e48b25dff5dbd1db76752c68f338a14ef6bb18733969e9db45e96d89fab546609f9404e1f779d15248203d7c7c5a91b00000000000000000000000000000000000000000000000000000000000000" \
  --override-state-diff "0x5EA1d9A6dDC3A0329378a327746D71A2019eC332:0x269bb0dc23923a25a8c39074e6cb0c85f1f29fd13f8dfa05d81baf046ed3b9af:1,0x5EA1d9A6dDC3A0329378a327746D71A2019eC332:4:1,0x5EA1d9A6dDC3A0329378a327746D71A2019eC332:0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8:0,0x5EA1d9A6dDC3A0329378a327746D71A2019eC332:0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947:0" \
  --rpc-url "https://eth.llamarpc.com"
```

> Execution Traces:
Traces:
  [104531] 0x5EA1d9A6dDC3A0329378a327746D71A2019eC332::execTransaction(0x9641d764fc13c8B624c04430C7356C1C7C8102e2, 0, 0x8d80ff0a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000013200cfbfac74c26f8647cbdb8c5caf80bb5b32e4313400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044dd43a79f000000000000000000000000f46c6d6e62f59d9222f3812874211df07cf7b318000000000000000000000000000000000000000000000000000000000000000100a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000001fe27a73cd9f0b3c53b6e936d0b4f9b2f8ca3367000000000000000000000000000000000000000000000000000000002faf08000000000000000000000000000000, 1, 0, 0, 0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x01427eae1606844b055aabb63778fc9e523e48b25dff5dbd1db76752c68f338a14ef6bb18733969e9db45e96d89fab546609f9404e1f779d15248203d7c7c5a91b)
    ├─ [99537] 0x41675C099F32341bf84BFc5382aF534df5C7461a::execTransaction(0x9641d764fc13c8B624c04430C7356C1C7C8102e2, 0, 0x8d80ff0a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000013200cfbfac74c26f8647cbdb8c5caf80bb5b32e4313400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044dd43a79f000000000000000000000000f46c6d6e62f59d9222f3812874211df07cf7b318000000000000000000000000000000000000000000000000000000000000000100a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000001fe27a73cd9f0b3c53b6e936d0b4f9b2f8ca3367000000000000000000000000000000000000000000000000000000002faf08000000000000000000000000000000, 1, 0, 0, 0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x01427eae1606844b055aabb63778fc9e523e48b25dff5dbd1db76752c68f338a14ef6bb18733969e9db45e96d89fab546609f9404e1f779d15248203d7c7c5a91b) [delegatecall]
    │   ├─ [3000] PRECOMPILES::ecrecover(0x27a0c4abf624b15b776f544a4b31ed4d50dee2b677c6497fbadf4f7a73be705e, 27, 569799068248606709654359279365657811530712758201901254503339124358604862346, 9469276693155409892942073865840739087499944749595054468651068267378848023977) [staticcall]
    │   │   └─ ← [Return] 0x000000000000000000000000d5aeb612f43919fcbffd0eea734d0e9130d14b2e
    │   ├─ [76339] 0x9641d764fc13c8B624c04430C7356C1C7C8102e2::multiSend(0x00cfbfac74c26f8647cbdb8c5caf80bb5b32e4313400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044dd43a79f000000000000000000000000f46c6d6e62f59d9222f3812874211df07cf7b318000000000000000000000000000000000000000000000000000000000000000100a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000001fe27a73cd9f0b3c53b6e936d0b4f9b2f8ca3367000000000000000000000000000000000000000000000000000000002faf0800) [delegatecall]
    │   │   ├─ [29368] 0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134::removeDelegate(0xf46c6d6e62f59D9222F3812874211dF07cF7b318, true)
    │   │   │   ├─  emit topic 0: 0x9a9bc79dd7e42545ba12d5659704d73a9364d4a18e0a98ca1c992a3bc999d271
    │   │   │   │        topic 1: 0x0000000000000000000000005ea1d9a6ddc3a0329378a327746d71a2019ec332
    │   │   │   │           data: 0x000000000000000000000000f46c6d6e62f59d9222f3812874211df07cf7b318000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
    │   │   │   ├─  emit topic 0: 0xdccc2d936ded24d2153d2760581a7f0dcb23ec71190c9726b3584cdd700214d4
    │   │   │   │        topic 1: 0x0000000000000000000000005ea1d9a6ddc3a0329378a327746d71a2019ec332
    │   │   │   │           data: 0x000000000000000000000000f46c6d6e62f59d9222f3812874211df07cf7b318
    │   │   │   └─ ← [Stop]
    │   │   ├─ [40652] 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48::transfer(0x1FE27A73Cd9f0b3C53b6E936D0b4F9B2f8ca3367, 800000000 [8e8])
    │   │   │   ├─ [33363] 0x43506849D7C04F9138D1A2050bbF3A0c054402dd::transfer(0x1FE27A73Cd9f0b3C53b6E936D0b4F9B2f8ca3367, 800000000 [8e8]) [delegatecall]
    │   │   │   │   ├─ emit Transfer(from: 0x5EA1d9A6dDC3A0329378a327746D71A2019eC332, to: 0x1FE27A73Cd9f0b3C53b6E936D0b4F9B2f8ca3367, value: 800000000 [8e8])
    │   │   │   │   └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000001
    │   │   │   └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000001
    │   │   └─ ← [Stop]
    │   ├─  emit topic 0: 0x442e715f626346e8c54381002da614f62bee8d27386535b2521ec8540898556e
    │   │        topic 1: 0x27a0c4abf624b15b776f544a4b31ed4d50dee2b677c6497fbadf4f7a73be705e
    │   │           data: 0x0000000000000000000000000000000000000000000000000000000000000000
    │   └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000001
    └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000001


Transaction successfully executed.
Gas used: 126695
````

### Nested Safes

This [script](./safe_hashes.sh) supports calculating the Safe transaction hashes for nested Safe (i.e. use a Safe as a signatory to another Safe) approval transactions. When a nested Safe needs to approve a transaction on the primary Safe, it must call the [`approveHash(bytes32)`](https://github.com/safe-global/safe-smart-account/blob/bdcfce3a76c4d1dfb256ac2ca971be7cfd6e493a/contracts/Safe.sol#L372-L379) function on the target Safe with the Safe transaction hash to approve:

```solidity
function approveHash(bytes32 hashToApprove) external override {
    if (owners[msg.sender] == address(0)) revertWithError("GS030");
    approvedHashes[msg.sender][hashToApprove] = 1;
    emit ApproveHash(hashToApprove, msg.sender);
}
```

To calculate both the primary transaction hash and the nested Safe `approveHash` transaction hash, specify the `network`, `address`, `nonce`, `nested-safe-address`, and `nested-safe-nonce` parameters:

```console
./safe_hashes.sh --network sepolia --address 0x657ff0D4eC65D82b2bC1247b0a558bcd2f80A0f1 --nonce 4 --nested-safe-address 0x6bc56d6CE87C86CB0756c616bECFD3Cd32b09251 --nested-safe-nonce 4
```

The [script](./safe_hashes.sh) will first calculate and display the primary transaction hashes. Then, it will construct and calculate the hashes for the `approveHash` transaction:

```console
===================================
= Selected Network Configurations =
===================================

Network: sepolia
Chain ID: 11155111

========================================
= Transaction Data and Computed Hashes =
========================================

Primary Safe Transaction Data and Computed Hashes

> Transaction Data:
Multisig address: 0x657ff0D4eC65D82b2bC1247b0a558bcd2f80A0f1
To: 0x255C3912f91eF11bFDadd405F13144a823Da8cc5
Value: 100000000000000000
Data: 0x
Operation: Call
Safe Transaction Gas: 0
Base Gas: 0
Gas Price: 0
Gas Token: 0x0000000000000000000000000000000000000000
Refund Receiver: 0x0000000000000000000000000000000000000000
Nonce: 4
Encoded message: 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8000000000000000000000000255c3912f91ef11bfdadd405f13144a823da8cc5000000000000000000000000000000000000000000000000016345785d8a0000c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a4700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004
Method: 0x (ETH Transfer)
Parameters: []

> Hashes:
Domain hash: 0x611379C19940CAEE095CDB12BEBE6A9FA9ABB74CDB1FBD7377C49A1F198DC24F
Message hash: 0x565BBA8B51924FFA64953596D0A2DD5C2CAD39649F7DE0BF2C8DBC903BD03258
Safe transaction hash: 0xcb8bbe7bf8f8a1f3f57658e450d07d4422356ac042d96a87ba425b19e67a78a1

Nested Safe `approveHash` Transaction Data and Computed Hashes

The specified nested Safe at `0x6bc56d6CE87C86CB0756c616bECFD3Cd32b09251` will use the following transaction to approve the primary transaction.

> Transaction Data:
Multisig address: 0x6bc56d6CE87C86CB0756c616bECFD3Cd32b09251
To: 0x657ff0D4eC65D82b2bC1247b0a558bcd2f80A0f1
Value: 0
Data: 0xd4d9bdcdcb8bbe7bf8f8a1f3f57658e450d07d4422356ac042d96a87ba425b19e67a78a1
Operation: Call
Safe Transaction Gas: 0
Base Gas: 0
Gas Price: 0
Gas Token: 0x0000000000000000000000000000000000000000
Refund Receiver: 0x0000000000000000000000000000000000000000
Nonce: 4
Encoded message: 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8000000000000000000000000657ff0d4ec65d82b2bc1247b0a558bcd2f80a0f10000000000000000000000000000000000000000000000000000000000000000873d41be4be44b68a3ad9cb19bf644be0f02392498d3a81d46d9f0741c9426640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004
Method: approveHash
Parameters: [
  {
    "name": "hashToApprove",
    "type": "bytes32",
    "value": "0xcb8bbe7bf8f8a1f3f57658e450d07d4422356ac042d96a87ba425b19e67a78a1"
  }
]

> Hashes:
Domain hash: 0x55F6C329A7834E2A4E789F5526F328FA75D14FE75B97B0001BE40CAF46CA92A1
Message hash: 0xCD411EE5D49344391EF8D37B76E19DFACF505BBB20E856AC907ACB5958ECBDF0
Safe transaction hash: 0x86eb3f93f2670d119a4ecb8eeaa4dafe31a28abcafe06688d47e195a3dd7abb0
```

The nested Safe `approveHash` transaction is constructed with the following parameters:

- `to`: The primary Safe multisig address.
- `data`: Encoded `approveHash(bytes32)` function call with the Safe transaction hash as argument.
- `value`: Set to `0`.
- `operation`: Set to `0` (i.e. `CALL`).
- All other parameters are set to their default values (`0` or the zero address `0x0000000000000000000000000000000000000000`).

> [!NOTE]
> The `--interactive` mode supports nested Safe transactions but only allows overriding the nested Safe version, not other transaction values in the `approveHash` transaction. You can also use the `--simulate` mode with nested Safe transactions, but it simulates only the main transaction (the one you approve) and not the Safe `approveHash` transaction itself.

## Safe Message Hashes

> [!IMPORTANT]
> At present, this [script](./safe_hashes.sh) does not support calculating Safe message hashes for [EIP-712](https://eips.ethereum.org/EIPS/eip-712)-based messages due to the inherent complexity of parsing the message and identifying the relevant type hashes. However, you can find my easily adjustable Bash script version [here](https://github.com/pcaversaccio/zksync-emergency-upgrades/blob/main/safe_hashes.sh) to calculate Safe message hashes for [EIP-712](https://eips.ethereum.org/EIPS/eip-712)-based messages.

This [script](./safe_hashes.sh) not only calculates Safe transaction hashes but also supports computing the corresponding hashes for off-chain messages following the [EIP-712](https://eips.ethereum.org/EIPS/eip-712) standard. To calculate the Safe message hashes for a specific message, specify the `network`, `address`, and `message` parameters. The `message` parameter must specify a valid file containing the raw message. This can be either the file name or a relative path (e.g., `path/to/message.txt`). Note that the [script](./safe_hashes.sh) normalises line endings to `LF` (`\n`) in the message file.

An example: Save the following message to a file named `message.txt`:

```txt
Welcome to OpenSea!

Click to sign in and accept the OpenSea Terms of Service (https://opensea.io/tos) and Privacy Policy (https://opensea.io/privacy).

This request will not trigger a blockchain transaction or cost any gas fees.

Wallet address:
0x657ff0d4ec65d82b2bc1247b0a558bcd2f80a0f1

Nonce:
ea499f2f-fdbc-4d04-92c4-b60aba887e06
```

Then, invoke the following command:

```console
./safe_hashes.sh --network sepolia --address 0x657ff0D4eC65D82b2bC1247b0a558bcd2f80A0f1 --message message.txt
```

The [script](./safe_hashes.sh) will output the raw message, along with the domain, message, and Safe message hashes, allowing you to easily verify them against the values displayed on your Ledger hardware wallet screen:

```console
===================================
= Selected Network Configurations =
===================================

Network: sepolia
Chain ID: 11155111

====================================
= Message Data and Computed Hashes =
====================================

> Message Data:
Multisig address: 0x657ff0D4eC65D82b2bC1247b0a558bcd2f80A0f1
Message: Welcome to OpenSea!

Click to sign in and accept the OpenSea Terms of Service (https://opensea.io/tos) and Privacy Policy (https://opensea.io/privacy).

This request will not trigger a blockchain transaction or cost any gas fees.

Wallet address:
0x657ff0d4ec65d82b2bc1247b0a558bcd2f80a0f1

Nonce:
ea499f2f-fdbc-4d04-92c4-b60aba887e06

> Hashes:
Safe message: 0xcb1a9208c1a7c191185938c7d304ed01db68677eea4e689d688469aa72e34236
Domain hash: 0x611379C19940CAEE095CDB12BEBE6A9FA9ABB74CDB1FBD7377C49A1F198DC24F
Message hash: 0xA5D2F507A16279357446768DB4BD47A03BCA0B6ACAC4632A4C2C96AF20D6F6E5
Safe message hash: 0x1866b559f56261ada63528391b93a1fe8e2e33baf7cace94fc6b42202d16ea08
```

> [!NOTE]
> The `--interactive` mode is not supported when calculating Safe message hashes. If using a nested Safe as the signer for the primary message, you must provide the `--nested-safe-address` argument along with the other parameters to retrieve the additional computed hashes for the nested Safe.

## Trust Assumptions

1. You trust my [script](./safe_hashes.sh) 😃.
2. You trust Linux.
3. You trust [Foundry](https://github.com/foundry-rs/foundry).
4. You trust the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview).
5. You trust [Ledger's secure screen](https://www.ledger.com/academy/topics/ledgersolutions/ledger-wallets-secure-screen-security-model).
6. You trust the data provided by your RPC provider when using `--simulate` mode.

> [!IMPORTANT]
> You can remove the trust assumption _"4. You trust the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview)."_ by enabling `--interactive` mode and verifying the calldata independently (this should always be done!). You can also remove the trust assumption _"6. You trust the data provided by your RPC provider when using `--simulate` mode."_ by running your own node.

## Community-Maintained User Interface Implementations

> [!IMPORTANT]
> Please be aware that user interface implementations may introduce additional trust assumptions, such as relying on `npm` dependencies that have not undergone thorough review or a deployment process that could be compromised by an attacker. Always verify and cross-reference with the main [script](./safe_hashes.sh).

- [`safeutils.openzeppelin.com`](https://safeutils.openzeppelin.com):
  - Code: [`OpenZeppelin/safe-utils`](https://github.com/OpenZeppelin/safe-utils)
  - Authors: [`josepchetrit12`](https://github.com/josepchetrit12), [`xaler5`](https://github.com/xaler5)

## 💸 Donation

I am a strong advocate of the open-source and free software paradigm. However, if you feel my work deserves a donation, you can send it to this address: [`0xe9Fa0c8B5d7F79DeC36D3F448B1Ac4cEdedE4e69`](https://etherscan.io/address/0xe9Fa0c8B5d7F79DeC36D3F448B1Ac4cEdedE4e69). I can pledge that I will use this money to help fix more existing challenges in the Ethereum ecosystem 🤝.

[^1]: It is theoretically possible to query transactions prior to the first signature; however, this functionality is not incorporated into the main [script](https://github.com/pcaversaccio/safe-tx-hashes-util/blob/main/safe_hashes.sh). To do so, you would proceed through the [Safe UI](https://app.safe.global) as usual, stopping at the page where the transaction is signed or executed. At this point, the action is recorded in the [Safe Transaction Service API](https://docs.safe.global/core-api/transaction-service-overview), allowing you to retrieve the unsigned transaction by setting `trusted=false` in the [API](https://docs.safe.global/core-api/transaction-service-reference/mainnet#List-a-Safe's-Multisig-Transactions) query within your Bash script. For example, you might use a query such as: `https://safe-transaction-arbitrum.safe.global/api/v2/safes/0xB24A3AA250E209bC95A4a9afFDF10c6D099B3d34/multisig-transactions/?trusted=false&nonce=4`. This decision to not implement this feature avoids potential confusion caused by unsigned transactions in the queue, especially when multiple transactions share the same nonce, making it unclear which one to act upon. If this feature aligns with your needs, feel free to fork the [script](https://github.com/pcaversaccio/safe-tx-hashes-util/blob/main/safe_hashes.sh) and modify it as necessary.
