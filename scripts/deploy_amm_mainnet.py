
import time
from scripts.deploy_utils import *

Accs = setup_mainnet_accounts()

print(f"Deployer ETH balance: {Accs.deployer.balance()/1e18:.5f}")

network.gas_limit(11111111)

INITIAL_IZA_MINT_AMOUNT = int(60000000000000000000000)
FARM_START_TIME = 1648762200
MARKETING_REWARD_ADDRESS = "0x495eac04d8947342d422cCfd69297d251780D498"

# Tokens
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
    "ONE": "0xDAe6c2A48BFAA66b43815c5548b10800919c993E",
    "FTM": "0xB44a9B6905aF7c801311e8F4E76932ee959c663C",
    "BNB": "0x2bF9b864cdc97b08B6D79ad4663e71B8aB65c45c",
    "MATIC": "0x6aB6d61428fde76768D7b45D8BFeec19c6eF91A8",
}


weth = Contract.from_abi("WETH", TOKENS["WETH"], WETH9.abi)
usdc = interface.ERC20(TOKENS["USDC"])
near = interface.ERC20(TOKENS["NEAR"])
aurora = interface.ERC20(TOKENS["AURORA"])
ust = interface.ERC20(TOKENS["UST"])
one = interface.ERC20(TOKENS["ONE"])
iza = Contract.from_abi("IzaToken", "0x0017Be3E7e36ABF49FE67a78D08bf465bB755120", IzaToken.abi)
dev_payout = Contract.from_abi("DevPayout", "0x84521183A3Be71e4A4C2dF5630982142fb47625E", DevPayouts.abi)

factory = Contract.from_abi("Factory", "0x34696b6cE48051048f07f4cAfa39e3381242c3eD", Factory.abi)
router = Router02[-1]  # 0x3d99B2F578d94f61adcD899DE55F2991522cefE1

chef = Contract.from_abi("MasterChef", "0xAE20c9F0c4a7E0098D322F690DFea6534E105614", MasterChef.abi)
xiza = Contract.from_abi("xToken", "0x00a761b10B4Ff8Fc205E685484a1da60451857e1", xToken.abi)
sun_maker = Contract.from_abi("SunMaker", "0x2f4e4F2f514F15230BE9fFb2F56285A6aeaD47F1", SunMaker.abi)


# Setup dev payout address
# dev_payout = DevPayouts.deploy(Accs.from_deployer(allow_revert=True))
# assert dev_payout.totalAllocPoint() == 1050, f"Bad totalAllocPoint, got {dev_payout.totalAllocPoint()} instead of 1050"

# Deploy AMM
# factory = Factory.deploy(Accs.deployer, Accs.from_deployer(allow_revert=True))
# router = Router02.deploy(factory, weth, Accs.from_deployer(allow_revert=True))


# Deploy Token + Masterchef
# iza = IzaToken.deploy(Accs.from_deployer(allow_revert=True))
# resp = iza.addAuthorized(Accs.deployer, Accs.from_deployer(allow_revert=True))

_start_time = FARM_START_TIME
_dev_address = dev_payout
_feeAddress = Accs.deployer
_marketingAddress = MARKETING_REWARD_ADDRESS
chef = MasterChef.deploy(iza, _start_time, _dev_address, _feeAddress, _marketingAddress, Accs.from_deployer(allow_revert=True))


# Deploy xIZA contracts
# xiza = xToken.deploy("IZA Governance Token", "xIZA", iza.address, chef.address, Accs.deployer, Accs.from_deployer(allow_revert=True))
# sun_maker = SunMaker.deploy(factory, xiza, iza, near, Accs.from_deployer(allow_revert=True))
# Set SunMaker to fee address
resp = factory.setFeeTo(sun_maker, Accs.from_deployer(allow_revert=True))

# Set staking address
chef.setStakingAddress(xiza, Accs.from_deployer(allow_revert=True))

resp = iza.setExcludedFromAntiWhale(Accs.deployer, True, Accs.from_deployer(allow_revert=True))
resp = iza.setExcludedFromAntiWhale(dev_payout, True, Accs.from_deployer(allow_revert=True))
resp = iza.setExcludedFromAntiWhale(chef, True, Accs.from_deployer(allow_revert=True))
resp = iza.setExcludedFromAntiWhale(xiza, True, Accs.from_deployer(allow_revert=True))
resp = iza.setExcludedFromAntiWhale(sun_maker, True, Accs.from_deployer(allow_revert=True))

# Create LP tokens and masterchef pools
# Pool 0 needs to be IZA
chef.add(50, iza, 0, Accs.from_deployer(allow_revert=True))

# Approve router to spend everything
approve(weth, router, Accs.deployer)
approve(usdc, router, Accs.deployer)
approve(near, router, Accs.deployer)
approve(aurora, router, Accs.deployer)
approve(iza, router, Accs.deployer)
approve(xiza, router, Accs.deployer)

# Create LP tokens
lp_usdc_weth = factory.getPair(weth, usdc)
if lp_usdc_weth == ZERO_ADDRESS:
    resp = factory.createPair(weth, usdc, Accs.from_deployer())
    lp_usdc_weth = resp.events['PairCreated']['pair']

lp_iza_usdc = factory.getPair(iza, usdc)
if lp_iza_usdc == ZERO_ADDRESS:
    resp = factory.createPair(iza, usdc, Accs.from_deployer())
    lp_iza_usdc = resp.events['PairCreated']['pair']

lp_iza_weth = factory.getPair(iza, weth)
if lp_iza_weth == ZERO_ADDRESS:
    resp = factory.createPair(iza, weth, Accs.from_deployer())
    lp_iza_weth = resp.events['PairCreated']['pair']

lp_iza_near = factory.getPair(iza, near)
if lp_iza_near == ZERO_ADDRESS:
    resp = factory.createPair(iza, near, Accs.from_deployer())
    lp_iza_near = resp.events['PairCreated']['pair']

lp_iza_aurora = factory.getPair(iza, aurora)
if lp_iza_aurora == ZERO_ADDRESS:
    resp = factory.createPair(iza, aurora, Accs.from_deployer())
    lp_iza_aurora = resp.events['PairCreated']['pair']

# Add LPs to masterchef
assert chef.poolLength() == 1, f"already have pools?? {chef.poolLength()}"
chef.add(150, lp_iza_usdc, 0, Accs.from_deployer())  # 1
chef.add(175, lp_iza_weth, 0, Accs.from_deployer())  # 2
chef.add(225, lp_iza_near, 0, Accs.from_deployer())  # 3
chef.add(275, lp_iza_aurora, 0, Accs.from_deployer())  # 4
chef.add(125, lp_iza_one, 0, Accs.from_deployer())  # 5

assert chef.poolLength() == 5, "bad pool length"

for cont in [IzaToken, Factory, Router02, xToken, SunMaker, MasterChef]:
    save_verification_json(cont)

print(f"""
Contract Addresses
------------------------------
Tokens:
WETH    \t{weth}
USDC    \t{usdc}
NEAR    \t{near}
AURORA  \t{aurora}

AMM:
factory \t{factory}
router  \t{router}
pair hash\t{factory.pairCodeHash()}

Farm:
IZA       \t{iza}
xIZA      \t{xiza}
masterchef\t{chef}
sunmaker  \t{sun_maker}
dev payout\t{dev_payout}

LP Addresses:
USDC/WETH LP\t{lp_usdc_weth}
IZA/USDC LP\t{lp_iza_usdc}
IZA/WETH LP\t{lp_iza_weth}
IZA/NEAR LP\t{lp_iza_near}
IZA/AURORA LP\t{lp_iza_aurora}

""")

##################################################################
##################################################################
# Launch
##################################################################
##################################################################

# Mint and transfer ownership of token to masterchef
assert iza.totalSupply() == 0, "Already minted"
iza.mint(Accs.deployer, INITIAL_IZA_MINT_AMOUNT, Accs.from_deployer())
assert iza.totalSupply() == INITIAL_IZA_MINT_AMOUNT
assert iza.balanceOf(Accs.deployer) == INITIAL_IZA_MINT_AMOUNT

iza.transferOwnership(chef, Accs.from_deployer())

price_eth = 3293
price_aurora = 9.103

# Set Anti-whale
print(f"IZA max transfer rate = {iza.maxTransferAmountRate()/100:.2f}%")
resp = iza.updateMaxTransferAmountRate(100, Accs.from_deployer())
print(f"IZA max transfer rate = {iza.maxTransferAmountRate()/100:.2f}%")

# Add liquidity
resp = router.addLiquidity(iza, aurora, INITIAL_IZA_MINT_AMOUNT, balanceOf(aurora, Accs.deployer), 0, 0, Accs.deployer, int(time.time()+3000), Accs.from_deployer())


# reset anti-whale - 1%
resp = iza.updateMaxTransferAmountRate(500, Accs.from_deployer())



xiza_output = {}

for i in range(200):
    nonce = Accs.deployer.nonce
    xiza = xToken.deploy("IZA Governance Token", "xIZA", iza.address, chef, Accs.deployer, Accs.from_deployer(allow_revert=True))
    xiza_output[xiza.address] = nonce


# nonce = Accs.deployer.nonce
while Accs.deployer.nonce < 256:
    print(f"Accs.deployer nonce = {Accs.deployer.nonce}")
    print(f"Accs.deployer bal   = {Accs.deployer.balance()}")
    # iza = IzaToken.deploy(Accs.from_deployer())
    Accs.deployer.transfer(Accs.deployer, 0)
    # nonce += 1
