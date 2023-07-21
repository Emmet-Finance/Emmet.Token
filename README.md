# Emmet.Token

The official repository of the `Emmet.Finance`'s token.

## Testing Emmet.Token
Flattening Emmet.Token

```bash
npx hardhat flatten contracts/Emmet.Token.sol > contracts/Flat.Emmet.Token.sol
```

## Compiling Emmet.Token

1. Remove duplicated SPDX license identifiers
2. Remove duplicated solidity versions 

```bash
npx hardhat compile
```

## Deploying Emmet.Token

### Testnet BSC:
```bash
npx hardhat run --network tbsc scripts/deploy.ts
```
Deployed contract: https://testnet.bscscan.com/address/0x11b8DF9c0906a44141F47245F6eA52A5553431C8#code

### Mainnet BSC:
```bash
npx hardhat run --network bsc scripts/deploy.ts
```