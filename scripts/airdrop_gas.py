
from scripts.deploy_utils import *

Accs = setup_mainnet_accounts()
network.gas_limit(11111111)

TOKENS = {
    "WETH": "0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB",
    "USDC": "0xB12BFcA5A55806AaF64E99521918A4bf0fC40802",
    "USDT": "0x4988a896b1227218e4A686fdE5EabdcAbd91571f",
    "NEAR": "0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d",
    "UST": "0x5ce9F0B6AFb36135b5ddBF11705cEB65E634A9dC",
    "AURORA": "0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79",
    "LUNA": "0xC4bdd27c33ec7daa6fcfd8532ddB524Bf4038096",
    "stNEAR": "0x07F9F7f963C5cD2BBFFd30CcfB964Be114332E30",
    "WBTC": "0xF4eB217Ba2454613b15dBdea6e5f22276410e89e",
    "AVAX": "0x80A16016cC4A2E6a2CACA8a4a498b1699fF0f844",
    "ONE": "",
    "FTM": "0xB44a9B6905aF7c801311e8F4E76932ee959c663C",
    "BNB": "0x2bF9b864cdc97b08B6D79ad4663e71B8aB65c45c",
    "MATIC": "0x6aB6d61428fde76768D7b45D8BFeec19c6eF91A8",
}


weth = Contract.from_abi("WETH", TOKENS["WETH"], WETH9.abi)
usdc = interface.ERC20(TOKENS["USDC"])
near = interface.ERC20(TOKENS["NEAR"])
aurora = interface.ERC20(TOKENS["AURORA"])
ust = interface.ERC20(TOKENS["UST"])
usdt = interface.ERC20(TOKENS["USDT"])

price_eth = 3390
price_near = 14
price_aurora = 9.2


def get_acc_balance_usd(addr):
    bal = web3.eth.get_balance(addr)/1e18*price_eth
    bal += usdc.balanceOf(addr)/10**usdc.decimals()
    bal += ust.balanceOf(addr)/10**ust.decimals()
    bal += usdt.balanceOf(addr)/10**usdt.decimals()
    bal += near.balanceOf(addr)/10**near.decimals()*price_near
    bal += aurora.balanceOf(addr)/10**aurora.decimals()*price_aurora
    return bal


already_seen = set()

amount = 140000000000000
eth_price = 3390

addr_list = """0xpepega
0x4ff9B7C1424b9E4375BbbDF3357a318412c02E0c"""


print()
bal = Accs.deployer.balance()
print(f"Deployer Balance: {bal/1e18:.5f} ETH (${bal/1e18*eth_price:.2f})")
print()
for addr in addr_list.split("\n"):
    if addr in already_seen:
        print(f"Account {addr}")
        print(f"  Already seen account")
    try:
        bal = web3.eth.get_balance(addr)
        if bal > amount/3:
            print(f"Account {addr}")
            print(f"  Skipping. They already have gas: {bal/1e18:.5f} ETH (${bal/1e18*eth_price:.2f})")
        else:
            print(f"Account {addr}")
            if bal == 0:
                print(f"  Sending ETH. They have 0 ETH")
            else:
                print(f"  Sending ETH. They only have {bal/1e18:.5f} ETH (${bal/1e18*eth_price:.2f})")
            Accs.deployer.transfer(addr, amount)
    except:
        print(f"Account {addr}")
        print(f"  Bad Address")
    already_seen.add(addr)
print()



for addr in addr_list.split("\n"):
    try:
        bal = get_acc_balance_usd(addr)
        print(f"{addr}\t${bal:,.2f}")
    except:
        print(f"{addr}\tBroke")

