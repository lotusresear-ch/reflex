# Lotus Reflex

![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red.svg)
![License](https://img.shields.io/badge/License-BUSL--1.1-yellow.svg)
![MEV](https://img.shields.io/badge/MEV-Capture%20Engine-green.svg)
![DeFi](https://img.shields.io/badge/DeFi-Integration-purple.svg)
![Tests](https://img.shields.io/badge/Tests-105%20Passing-brightgreen.svg)

**Lotus Reflex**
An on-chain MEV capture engine designed for seamless integration into DEX protocols.
This system focuses on the core functionality of capturing Maximum Extractable Value (MEV) while maintaining safety, decentralization, and ensuring it does not interfere with the pool's state or user experience.

## Key Features

- **Non-Intrusive Design**: The system operates without affecting pool state or user transactions
- **Decentralized Architecture**: Built with decentralization principles at its core
- **Seamless Integration**: Designed for easy integration into existing DEX protocols
- **MEV Capture**: Efficiently captures and redistributes MEV opportunities
- **Safety First**: Implements robust failsafe mechanisms to prevent disruption

## Technical Foundation

This project is built using **Foundry** - a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
