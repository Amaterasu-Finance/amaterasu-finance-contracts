
from dataclasses import dataclass

from brownie import accounts, interface, Contract
from brownie.network.account import LocalAccount


@dataclass
class Accounts:
    deployer: LocalAccount
    dev: LocalAccount
    user1: LocalAccount = None
    user2: LocalAccount = None
    user3: LocalAccount = None

    def from_deployer(self):
        return {'from': self.deployer}

    def from_dev(self):
        return {'from': self.dev}


def setup_mainnet_accounts(dev_only=False):
    deployer = dev = accounts.load('mainnet-dev')
    if not dev_only:
        deployer = accounts.load('mainnet-deployer')
    return Accounts(deployer, dev)


def send(coin, amt, to_, from_):
    return interface.IERC20(coin).transfer(to_, amt, {'from': from_})


def approve(coin, spender, from_, amt=1e27):
    return interface.IERC20(coin).approve(spender, int(amt), {'from': from_})


def balanceOf(coin, acc):
    return interface.IERC20(coin).balanceOf(acc)
