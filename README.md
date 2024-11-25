## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

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
$ forge script script/deploy/DeployAnimelRole.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
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

## Example
### Install lib
```shell
forge install ProjectOpenSea/operator-filter-registry@v1.4.2 --no-git
forge install OpenZeppelin/openzeppelin-contracts@v5.1.0 --no-git
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.1.0  --no-git
forge install foundry-rs/forge-std --no-git
forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-git
```
### Init Smart Contract
```shell
cp env/localhostchain/.env_localhostchain .env
forge clean && forge build
```
### Deploy
#### Start the Anvil Network
```shell
anvil --port 9545
```
#### Connect with MetaMask
1. Choose any Private Key to import MetaMask
  - Open MetaMask
  - Click on the account icon
  - Select "Import Account"
  - Paste one of the private keys from Anvil (without the 0x prefix)
2. Add Anvil Network
  - Network Name: Anvil
  - RPC URL: http://127.0.0.1:9545
  - Chain ID: 31337
  - Currency Symbol: ETH

#### Deploy Smart Contract
```shell
forge script script/deploy/DeployAnimelRole.s.sol:DeployAnimelRole --rpc-url http://127.0.0.1:9545 --private-key <your_private_key>
```
### Script
```shell
forge script script/deploy/DeployAnimelRole.s.sol --chain-id 31337 --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 -vvvv
模拟购买NFT
```
