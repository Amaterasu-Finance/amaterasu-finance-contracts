
import time
from scripts.deploy_utils import *

Accs = setup_mainnet_accounts()

INITIAL_IZA_MINT = '1000' + '000000000000000000'
INITIAL_MTV_LIQ = '1000' + '000000000000000000'

MARKETING_WALLET = ""

# TOKENS
WMTV = "0x8E321596267a4727746b2F48BC8736DB5Da26977"
BUSD = "0xCd65eb7630e5A2C46E1b99c0F3a45611be4960B2"
ONE = "0x4E51774CB9704109f6Ff8F9a9DfFd8fAF823C38f"

USDC = "0xEa1199d50Ee09fA8062fd9dA3D55C6F90C1bABd2"
WETH = "0x3b6e35574Fe60D7CeB9CA70DcA56D7294EF28926"
AVAX = "0x175E9B026cf31fbE181628C9BDAb3DF6143b6F18"
USDT = "0x2f9c74d3C42023C533437c9EE743D4a6329e78Df"
BNB = "0x25009A734EfFE43cf7609Bc313E987d7ee8ee346"
MOVR = "0x91c57B70EcD17DB27d22EaD74Cc86781936115E7"
MATIC = "0x185B1FF9878D27DdE302A511FC2f80765232ADB7"
FTM = "0x67558D91654A6ccbe88a3cc4e1DB862BC51fc322"
CRO = "0x282A0c6a96747bfF4BAa80eBa6CE6744aafaBEbB"
DIRT = "0x2eb19db032dc60039d35e36918d33197d9f7d7b9"

iza = Contract.from_abi("IZA", IZA, IzaToken.abi)
wmtv = Contract.from_abi("WMTV", WMTV, WETH9.abi)
busd = interface.ERC20(BUSD)
one = interface.ERC20(ONE)

payout = DevPayouts[-1]

# Deploy AMM
factory = Factory.deploy(Accs.deployer, Accs.from_deployer())
router = Router02.deploy(factory, WMTV, Accs.from_deployer())
#factory = Factory[-1]
#router = Router02[-1]

# Deploy Token + Masterchef
# iza = IzaToken.deploy(Accs.from_deployer())
# resp = iza.setExcludedFromAntiWhale(Accs.deployer, True, Accs.from_deployer())
# resp = iza.addAuthorized(Accs.deployer, Accs.from_deployer())
# iza.mint(Accs.deployer, INITIAL_IZA_MINT, Accs.from_deployer())

_start_block = chain.height + 300
_dev_address = payout.address
_feeAddress = Accs.deployer
_marketingAddress = MARKETING_WALLET

chef = MasterChef.deploy(iza, _start_block, _dev_address, _feeAddress, _marketingAddress, Accs.from_deployer())
resp = iza.setExcludedFromAntiWhale(chef, True, Accs.from_deployer())

# Deploy xIZA contracts
xiza = xToken.deploy("IZA Governance Token", "xIZA", iza.address, chef.address, Accs.deployer, Accs.from_deployer())
sun_maker = SunMaker.deploy(factory, xiza, iza, WMTV, Accs.from_deployer())
resp = iza.setExcludedFromAntiWhale(xiza, True, Accs.from_deployer())
resp = iza.setExcludedFromAntiWhale(sun_maker, True, Accs.from_deployer())
# Set SunMaker to fee address
resp = factory.setFeeTo(sun_maker, Accs.from_deployer())

# Set staking address
chef.setStakingAddress(xiza, Accs.from_deployer())

# Approve router to spend everything
approve(WMTV, router, Accs.deployer)
approve(busd, router, Accs.deployer)
approve(one, router, Accs.deployer)
approve(iza, router, Accs.deployer)
approve(xiza, router, Accs.deployer)

# Create LP tokens
resp = factory.createPair(WMTV, busd, Accs.from_deployer())
lp_mtv_busd = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, busd, Accs.from_deployer())
lp_iza_busd = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, WMTV, Accs.from_deployer())
lp_iza_mtv = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, one, Accs.from_deployer())
lp_iza_one = resp.events['PairCreated']['pair']

# Add LPs to masterchef
assert chef.poolLength() == 0, f"already have pools?? {chef.poolLength()}"
# Pool 0 needs to be IZA
chef.add(30, iza, 0, Accs.from_deployer())
chef.add(100, lp_iza_mtv, 0, Accs.from_deployer())  # 1
chef.add(50, lp_iza_busd, 0, Accs.from_deployer())  # 2
chef.add(20, lp_iza_one, 0, Accs.from_deployer())  # 3
chef.add(0, lp_mtv_busd, 0, Accs.from_deployer())  # 4

assert chef.poolLength() == 5, "bad pool length"

print(f"""
Contract Addresses
------------------------------
DEX:
WMTV     \t{WMTV}
factory  \t{factory}
router   \t{router}
pair hash\t{factory.pairCodeHash()}

Farm:
IZA       \t{iza}
masterchef\t{chef}
xIZA      \t{xiza}
sunmaker  \t{sun_maker}

LP Addresses:
IZA/MTV LP \t{lp_iza_mtv}
IZA/BUSD LP\t{lp_iza_busd}
IZA/ONE LP \t{lp_iza_one}
MTV/BUSD LP\t{lp_mtv_busd}

""")


# Go Live

INITIAL_IZA_MINT = '30000' + '000000000000000000'
INITIAL_MTV_LIQ = '820000' + '000000000000000000'  # TODO - finalize

# Transfer ownership of token to masterchef
iza.transferOwnership(chef, Accs.from_deployer())

# Set anti-whale
resp = iza.updateMaxTransferAmountRate(100, Accs.from_deployer())
print(f"IZA max transfer rate = {iza.maxTransferAmountRate()/100:.2f}%")
# Add liquidity
resp = router.addLiquidity(iza, WMTV, INITIAL_IZA_MINT, INITIAL_MTV_LIQ, 0, 0, Accs.deployer, int(chain.time()+3000), Accs.from_deployer())




