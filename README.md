## Cove's multisig scripts repo

## Usage

### Set .env File 
   - Set `WALLET_TYPE` to `local`, `ledger`, `trezor`, or `account` depending on your wallet
   - If `WALLET_TYPE` is `local`:
     - Set `PRIVATE_KEY` to your private key
   - If `WALLET_TYPE` is `ledger` or `trezor`:
     - Set `MNEMONIC_INDEX` to the index of the mnemonic
   - If `WALLET_TYPE` is `account`:
     - Set `ACCOUNT_NAME` to the name of the account saved in the forge cast wallet

### Install

```shell
forge install
```

### Run scripts

* Multisig scripts
```shell
# simulate only
forge script --fork-url <your_fork_url> script/ops/GnosisSafeScript.s.sol -s "run(bool)" false
```
```shell
# queue up the multisig transaction
forge script --fork-url <your_fork_url> script/ops/GnosisSafeScript.s.sol -s "run(bool)" true 
```

* Deployer scripts
```shell
# simulate only
forge script --fork-url <your_fork_url> script/deployer/DeployerScript.s.sol
```
```shell
# execute and broadcast tx
forge script --fork-url <your_fork_url> script/deployer/DeployerScript.s.sol --broadcast --account deployer 
```
