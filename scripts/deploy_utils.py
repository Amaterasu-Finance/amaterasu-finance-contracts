
from dataclasses import dataclass
import json

from brownie import accounts, interface, Contract
from brownie.network.account import LocalAccount


@dataclass
class Accounts:
    deployer: LocalAccount
    dev: LocalAccount
    user1: LocalAccount = None
    user2: LocalAccount = None
    user3: LocalAccount = None

    def from_deployer(self, gas=None, allow_revert=False):
        output = {'from': self.deployer}
        if gas:
            output['gas'] = gas
        if allow_revert:
            output['allow_revert'] = allow_revert
        return output

    def from_dev(self, gas=None, allow_revert=False):
        output = {'from': self.dev}
        if gas:
            output['gas'] = gas
        if allow_revert:
            output['allow_revert'] = allow_revert
        return output


def setup_mainnet_accounts(dev_only=False):
    deployer = dev = accounts.load('mainnet-dev')
    if not dev_only:
        deployer = accounts.load('mainnet-deployer')
    return Accounts(deployer, dev)


def setup_testnet_accounts():
    return Accounts(accounts[0], accounts[1])


def send(coin, amt, to_, from_):
    return interface.IERC20(coin).transfer(to_, amt, {'from': from_})


def approve(coin, spender, from_, amt=1e44):
    return interface.IERC20(coin).approve(spender, int(amt), {'from': from_})


def balanceOf(coin, acc):
    return interface.IERC20(coin).balanceOf(acc)


def save_verification_json(contract):
    name = contract.get_verification_info()['contract_name']
    print(f"Saving {name} verification info")
    with open(f'reports/{name}.json', 'w') as f:
        json.dump(contract.get_verification_info()['standard_json_input'], f)
