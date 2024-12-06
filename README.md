# Safe Multisig Transaction Hashes

```console
|)0/\/'T TR|\_|5T, \/3R1FY! 🫡
```

This Bash [script](./safe_hashes.sh) calculates the Safe transaction hashes by retrieving transaction details from the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview) and computing both the domain and message hashes using the [EIP-712](https://eips.ethereum.org/EIPS/eip-712) standard.

> [!NOTE]
> This Bash [script](./safe_hashes.sh) relies on the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview), which requires transactions to be proposed and _logged_ in the service before they can be retrieved. Consequently, the initial transaction proposer cannot access the transaction at the proposal stage, making this approach incompatible with 1-of-1 multisigs.

> [!IMPORTANT]
> All Safe multisig versions starting from `0.1.0` and newer are supported.

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
- X Layer (identifier: `xlayer`, chain ID: `195`)
- ZKsync Era (identifier: `zksync`, chain ID: `324`)

## Usage

> [!NOTE]
> Ensure that [`cast`](https://github.com/foundry-rs/foundry/tree/master/crates/cast) and [`chisel`](https://github.com/foundry-rs/foundry/tree/master/crates/chisel) are installed locally. For installation instructions, refer to this [guide](https://book.getfoundry.sh/getting-started/installation).

> [!TIP]
> For macOS users, please refer to the [macOS Users: Upgrading Bash](#macos-users-upgrading-bash) section.

```console
./safe_hashes.sh [--help] [--list-networks] --network <network> --address <address> --nonce <nonce>
```

**Options:**

- `--help`: Display this help message.
- `--list-networks`: List all supported networks and their chain IDs.
- `--network <network>`: Specify the network (e.g., `ethereum`, `polygon`).
- `--address <address>`: Specify the Safe multisig address.
- `--nonce <nonce>`: Specify the transaction nonce.

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

3. Add the new shell to the list of allowed shells:

```console
sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
```

4. Optionally, make it your default shell:

```console
chsh -s /usr/local/bin/bash
```

You can verify your Bash version after the installation:

```console
bash --version
```

## Example

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

## Trust Assumptions

1. You trust my [script](./safe_hashes.sh) 😃.
2. You trust Linux.
3. You trust [Foundry](https://github.com/foundry-rs/foundry).
4. You trust the [Safe transaction service API](https://docs.safe.global/core-api/transaction-service-overview).
5. You trust [Ledger's secure screen](https://www.ledger.com/academy/topics/ledgersolutions/ledger-wallets-secure-screen-security-model).

## Community-Maintained User Interface Implementations

> [!IMPORTANT]
> Please be aware that user interface implementations may introduce additional trust assumptions, such as relying on `npm` dependencies that have not undergone thorough review. Always verify and cross-reference with the main [script](./safe_hashes.sh).

- [`safehashpreview.com`](https://www.safehashpreview.com):
  - Code: [`josepchetrit12/safe-tx-hashes-util`](https://github.com/josepchetrit12/safe-tx-hashes-util)
  - Authors: [`josepchetrit12`](https://github.com/josepchetrit12), [`xaler5`](https://github.com/xaler5)
