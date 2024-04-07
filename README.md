# multisig-scripts

Scripts for queuing Gnosis Safe txs using ApeWorkX https://github.com/ApeWorX/ape-safe

## Setup

Setup a virtual environment and install dependencies

```bash
pyenv install 3.11.6
pyenv virtualenv 3.11.6 ape
pyenv local ape
pip install --upgrade pip
pip install -r requirements.txt
```

Export the infura API key and add relevant safe addresses and accounts

```bash
export INFURA_API_KEY=your_infura_api_key
ape safe add --network ethereum:mainnet:infura 0x7Bd578354b0B2f02E656f1bDC0e41a80f860534b cove-community-multisig
ape safe add --network ethereum:mainnet:infura 0x71BDC5F3AbA49538C76d58Bc2ab4E3A1118dAe4c cove-ops-multisig
ape accounts import cove-deployer
```
