USD+ contracts
================

[![codecov](https://codecov.io/gh/dinaricrypto/usdplus-contracts/graph/badge.svg?token=qlNTf7dlc2)](https://codecov.io/gh/dinaricrypto/usdplus-contracts)

## Development

### Build

```shell
$ forge build
```

### Test

```shell
$ yarn test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

## Deployment

### Testing

```shell
docker-compose up -d
export ENVIRONMENT="staging"
export RPC_URL="http://localhost:8545"
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
./script/release.sh
```

## Internal Audit

### 2024-11-18

- Audit performed by @ykim, @jaketimothy, @joshualyguessennd
