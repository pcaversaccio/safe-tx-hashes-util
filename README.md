# Safe Multisig Transaction Hashes <!-- omit from toc -->

[![License: AGPL-3.0-only](https://img.shields.io/badge/License-AGPL--3.0--only-blue)](https://www.gnu.org/licenses/agpl-3.0)

```console
|)0/\/'T TR|\_|5T, \/3R1FY! 🫡
```

This Bash [script](./safe_hashes.sh) calculates the Safe transaction hashes by retrieving transaction details from the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview) and computing both the domain and message hashes using the [EIP-712](https://eips.ethereum.org/EIPS/eip-712) standard.

> [!NOTE]
> This Bash [script](./safe_hashes.sh) relies on the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview), which requires transactions to be proposed and _logged_ in the service before they can be retrieved. Consequently, the initial transaction proposer cannot access the transaction at the proposal stage, making this approach incompatible with 1-of-1 multisigs.[^1]

> [!IMPORTANT]
> All Safe multisig versions starting from `0.1.0` and newer are supported.

- [Supported Networks](#supported-networks)
- [Usage](#usage)
  - [macOS Users: Upgrading Bash](#macos-users-upgrading-bash)
    - [Optional: Set the New Bash as Your Default Shell](#optional-set-the-new-bash-as-your-default-shell)
- [Safe Transaction Hashes](#safe-transaction-hashes)
- [Safe Message Hashes](#safe-message-hashes)
- [Trust Assumptions](#trust-assumptions)
- [Community-Maintained User Interface Implementations](#community-maintained-user-interface-implementations)

## Supported Networks

- Arbitrum (identifier: `arbitrum`, chain ID: `42161`)
- Aurora (identifier: `aurora`, chain ID: `1313161554`)
- Avalanche (identifier: `avalanche`, chain ID: `43114`)
- Base (identifier: `base`, chain ID: `8453`)
- Base Sepolia (identifier: `base-sepolia`, chain ID: `84532`)
- Blast (identifier: `blast`, chain ID: `81457`)
- BSC (Binance Smart Chain) (identifier: `bsc`, chain ID: `56`)
- Celo (identifier: `celo`, chain ID: `42220`)
- Ethereum (identifier: `ethereum`, chain ID: `1`)
- Gnosis (identifier: `gnosis`, chain ID: `100`)
- Gnosis Chiado (identifier: `gnosis-chiado`, chain ID: `10200`)
- Linea (identifier: `linea`, chain ID: `59144`)
- Mantle (identifier: `mantle`, chain ID: `5000`)
- Optimism (identifier: `optimism`, chain ID: `10`)
- Polygon (identifier: `polygon`, chain ID: `137`)
- Polygon zkEVM (identifier: `polygon-zkevm`, chain ID: `1101`)
- Scroll (identifier: `scroll`, chain ID: `534352`)
- Sepolia (identifier: `sepolia`, chain ID: `11155111`)
- World Chain (identifier: `worldchain`, chain ID: `480`)
- X Layer (identifier: `xlayer`, chain ID: `196`)
- ZKsync Era (identifier: `zksync`, chain ID: `324`)

## Usage

> [!NOTE]
> Ensure that [`cast`](https://github.com/foundry-rs/foundry/tree/master/crates/cast) and [`chisel`](https://github.com/foundry-rs/foundry/tree/master/crates/chisel) are installed locally. For installation instructions, refer to this [guide](https://book.getfoundry.sh/getting-started/installation).

> [!TIP]
> For macOS users, please refer to the [macOS Users: Upgrading Bash](#macos-users-upgrading-bash) section.

```console
./safe_hashes.sh [--help] [--list-networks] --network <network> --address <address> --nonce <nonce> --message <file>
```

**Options:**

- `--help`: Display this help message.
- `--list-networks`: List all supported networks and their chain IDs.
- `--network <network>`: Specify the network (e.g., `ethereum`, `polygon`).
- `--address <address>`: Specify the Safe multisig address.
- `--nonce <nonce>`: Specify the transaction nonce (required for transaction hashes).
- `--message <file>`: Specify the message file (required for off-chain message hashes).

Before you invoke the [script](./safe_hashes.sh), make it executable:

```console
chmod +x safe_hashes.sh
```

> [!TIP]
> The [script](./safe_hashes.sh) is already set as _executable_ in the repository, so you can run it immediately after cloning or pulling the repository without needing to change permissions.

To enable _debug mode_, set the `DEBUG` environment variable to `true` before running the [script](./safe_hashes.sh):

```console
DEBUG=true ./safe_hashes.sh ...
```

This will print each command before it is executed, which is helpful when troubleshooting.

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

## Safe Message Hashes

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
Raw message hash: 0xcb1a9208c1a7c191185938c7d304ed01db68677eea4e689d688469aa72e34236
Domain hash: 0x611379C19940CAEE095CDB12BEBE6A9FA9ABB74CDB1FBD7377C49A1F198DC24F
Message hash: 0xA5D2F507A16279357446768DB4BD47A03BCA0B6ACAC4632A4C2C96AF20D6F6E5
Safe message hash: 0x1866b559f56261ada63528391b93a1fe8e2e33baf7cace94fc6b42202d16ea08
```

## Trust Assumptions

1. You trust my [script](./safe_hashes.sh) 😃.
2. You trust Linux.
3. You trust [Foundry](https://github.com/foundry-rs/foundry).
4. You trust the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview).
5. You trust [Ledger's secure screen](https://www.ledger.com/academy/topics/ledgersolutions/ledger-wallets-secure-screen-security-model).

## Community-Maintained User Interface Implementations

> [!IMPORTANT]
> Please be aware that user interface implementations may introduce additional trust assumptions, such as relying on `npm` dependencies that have not undergone thorough review or a deployment process that could be compromised by an attacker. Always verify and cross-reference with the main [script](./safe_hashes.sh).

- [`safeutils.openzeppelin.com`](https://safeutils.openzeppelin.com):
  - Code: [`OpenZeppelin/safe-utils`](https://github.com/OpenZeppelin/safe-utils)
  - Authors: [`josepchetrit12`](https://github.com/josepchetrit12), [`xaler5`](https://github.com/xaler5)

[^1]: It is theoretically possible to query transactions prior to the first signature; however, this functionality is not incorporated into the main [script](https://github.com/pcaversaccio/safe-tx-hashes-util/blob/main/safe_hashes.sh). To do so, you would proceed through the [Safe UI](https://app.safe.global) as usual, stopping at the page where the transaction is signed or executed. At this point, the action is recorded in the [Safe Transaction Service API](https://docs.safe.global/core-api/transaction-service-overview), allowing you to retrieve the unsigned transaction by setting `trusted=false` in the [API](https://docs.safe.global/core-api/transaction-service-reference/mainnet#List-a-Safe's-Multisig-Transactions) query within your Bash script. For example, you might use a query such as: `https://safe-transaction-arbitrum.safe.global/api/v1/safes/0xB24A3AA250E209bC95A4a9afFDF10c6D099B3d34/multisig-transactions/?trusted=false&nonce=4`. This decision to not implement this feature avoids potential confusion caused by unsigned transactions in the queue, especially when multiple transactions share the same nonce, making it unclear which one to act upon. If this feature aligns with your needs, feel free to fork the [script](https://github.com/pcaversaccio/safe-tx-hashes-util/blob/main/safe_hashes.sh) and modify it as necessary.
