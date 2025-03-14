# Safe Multisig Transaction Hashes <!-- omit from toc -->

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
- [Safe Transaction Hashes](#safe-transaction-hashes)
  - [Interactive Mode](#interactive-mode)
- [Safe Message Hashes](#safe-message-hashes)
- [Trust Assumptions](#trust-assumptions)
- [Community-Maintained User Interface Implementations](#community-maintained-user-interface-implementations)
- [💸 Donation](#-donation)

## Security Best Practices for Using This Script

**Read This Before Proceeding!**

- **Rule 1**: Use a dedicated device running a secure operating system, such as [Tails](https://tails.net) or [Qubes OS](https://www.qubes-os.org), solely for verifying and signing transactions. This device **must not** be used for any other activities, such as browsing, messaging, emailing, or social media. It should only be powered on to connect to the multisig interface, execute this Bash [script](./safe_hashes.sh), verify the transaction, sign it, and then shut down immediately afterward. If you feel the urge to check X, don't, or I'll appear in your dreams!
- **Rule 2**: Always independently decode and verify transaction calldata. Don't sign _untrusted_ delegate calls (see the main [script](./safe_hashes.sh) for a list of trusted `delegatecall`able contracts). Do not copy calldata from the Safe UI's copy button. Instead, manually copy the calldata directly from your wallet extension (e.g., MetaMask). You can decode the calldata using Etherscan's [Input Data Decoder](https://etherscan.io/inputdatadecoder). For further guidance on verifying Safe wallet transactions and performing basic transaction checks, **READ THESE RESOURCES AND ACT ON THEM**: [How to verify Safe wallet transactions on a hardware wallet](https://help.safe.global/en/articles/276344-how-to-verify-safe-wallet-transactions-on-a-hardware-wallet) and [How to perform basic transaction checks on Safe wallet](https://help.safe.global/en/articles/276343-how-to-perform-basic-transactions-checks-on-safe-wallet). **Do not skip this step!**
- **Rule 3**: Adhere strictly to Rule 1 and Rule 2.

## Supported Networks

- Arbitrum (identifier: `arbitrum`, chain ID: `42161`)
- Aurora (identifier: `aurora`, chain ID: `1313161554`)
- Avalanche (identifier: `avalanche`, chain ID: `43114`)
- Base (identifier: `base`, chain ID: `8453`)
- Base Sepolia (identifier: `base-sepolia`, chain ID: `84532`)
- Blast (identifier: `blast`, chain ID: `81457`)
- BSC (BNB Smart Chain) (identifier: `bsc`, chain ID: `56`)
- Celo (identifier: `celo`, chain ID: `42220`)
- Ethereum (identifier: `ethereum`, chain ID: `1`)
- Gnosis (identifier: `gnosis`, chain ID: `100`)
- Gnosis Chiado (identifier: `gnosis-chiado`, chain ID: `10200`)
- Linea (identifier: `linea`, chain ID: `59144`)
- Mantle (identifier: `mantle`, chain ID: `5000`)
- OP (Optimism) (identifier: `optimism`, chain ID: `10`)
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
./safe_hashes.sh [--help] [--list-networks] --network <network> --address <address> --nonce <nonce> --message <file> --interactive
```

**Options:**

- `--help`: Display this help message.
- `--version`: Display the latest local commit hash (=version) of the script.
- `--list-networks`: List all supported networks and their chain IDs.
- `--network <network>`: Specify the network (e.g., `ethereum`, `polygon`).
- `--address <address>`: Specify the Safe multisig address.
- `--nonce <nonce>`: Specify the transaction nonce (required for transaction hashes).
- `--message <file>`: Specify the message file (required for off-chain message hashes).
- `--interactive`: Use the interactive mode (optional for transaction hashes).

> [!NOTE]
> Please note that `--help`, `--version`, and `--list-networks` can be used independently or alongside other options without causing the script to fail. They are special options that can be called without affecting the rest of the command processing.

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

WARNING: The transaction includes an untrusted delegate call to address 0x111CEEee040739fD91D29C34C33E6B3E112F2177!
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

> [!IMPORTANT]
> You can remove the trust assumption _"4. You trust the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview)."_ by enabling `--interactive` mode and verifying the calldata independently (this should always be done!).

## Community-Maintained User Interface Implementations

> [!IMPORTANT]
> Please be aware that user interface implementations may introduce additional trust assumptions, such as relying on `npm` dependencies that have not undergone thorough review or a deployment process that could be compromised by an attacker. Always verify and cross-reference with the main [script](./safe_hashes.sh).

- [`safeutils.openzeppelin.com`](https://safeutils.openzeppelin.com):
  - Code: [`OpenZeppelin/safe-utils`](https://github.com/OpenZeppelin/safe-utils)
  - Authors: [`josepchetrit12`](https://github.com/josepchetrit12), [`xaler5`](https://github.com/xaler5)

## 💸 Donation

I am a strong advocate of the open-source and free software paradigm. However, if you feel my work deserves a donation, you can send it to this address: [`0xe9Fa0c8B5d7F79DeC36D3F448B1Ac4cEdedE4e69`](https://etherscan.io/address/0xe9Fa0c8B5d7F79DeC36D3F448B1Ac4cEdedE4e69). I can pledge that I will use this money to help fix more existing challenges in the Ethereum ecosystem 🤝.

[^1]: It is theoretically possible to query transactions prior to the first signature; however, this functionality is not incorporated into the main [script](https://github.com/pcaversaccio/safe-tx-hashes-util/blob/main/safe_hashes.sh). To do so, you would proceed through the [Safe UI](https://app.safe.global) as usual, stopping at the page where the transaction is signed or executed. At this point, the action is recorded in the [Safe Transaction Service API](https://docs.safe.global/core-api/transaction-service-overview), allowing you to retrieve the unsigned transaction by setting `trusted=false` in the [API](https://docs.safe.global/core-api/transaction-service-reference/mainnet#List-a-Safe's-Multisig-Transactions) query within your Bash script. For example, you might use a query such as: `https://safe-transaction-arbitrum.safe.global/api/v1/safes/0xB24A3AA250E209bC95A4a9afFDF10c6D099B3d34/multisig-transactions/?trusted=false&nonce=4`. This decision to not implement this feature avoids potential confusion caused by unsigned transactions in the queue, especially when multiple transactions share the same nonce, making it unclear which one to act upon. If this feature aligns with your needs, feel free to fork the [script](https://github.com/pcaversaccio/safe-tx-hashes-util/blob/main/safe_hashes.sh) and modify it as necessary.
