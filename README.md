# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

## Test Emmet.Token

```shell
REPORT_GAS=true npx hardhat test
```

## Flattenning Emmet.Token

```bash
npx hardhat flatten contracts/Emmet.Token.sol > contracts/Flat.Emmet.Token.sol
```

## Compile Emmet.Token

1. Remove duplicated SPDX license identifiers
2. Remove duplicated solidity versions 

```bash
npx hardhat compile
```

## Deploy Emmet.Token

### Testnet BSC:
```bash
npx hardhat run --network tbsc scripts/deploy.ts
```
Deployed contract: https://testnet.bscscan.com/address/0x11b8DF9c0906a44141F47245F6eA52A5553431C8#code

### Mainnet BSC:
```bash
npx hardhat run --network bsc scripts/deploy.ts
```