
import time
from scripts.deploy_utils import *

Accs = setup_mainnet_accounts()

network.gas_limit(11111111)

# WETH
# weth = WETH9.deploy(Accs.from_dev())

# # Deploy and Mint test tokens
# usdc = USDC.deploy(Accs.from_dev(allow_revert=True))
# usdt = USDT.deploy(Accs.from_dev(allow_revert=True))
# near = NEAR.deploy(Accs.from_dev(allow_revert=True))
# ust = UST.deploy(Accs.from_dev(allow_revert=True))
# aurora = AURORA.deploy(Accs.from_dev(allow_revert=True))
#
# usdc.mint(Accs.dev, int(1e12), Accs.from_dev(allow_revert=True))
# usdt.mint(Accs.dev, int(1e12), Accs.from_dev(allow_revert=True))
# near.mint(Accs.dev, int(1e30), Accs.from_dev(allow_revert=True))
# ust.mint(Accs.dev, int(1e24), Accs.from_dev(allow_revert=True))
# aurora.mint(Accs.dev, int(1e24), Accs.from_dev(allow_revert=True))

weth = WETH9[0]
usdc = USDC[0]
usdt = USDT[0]
near = NEAR[0]
ust = UST[0]
aurora = AURORA[0]
iza = IzaToken[-1]

# Deploy AMM
factory = Factory.deploy(Accs.dev, Accs.from_dev(allow_revert=True))
router = Router02.deploy(factory, weth, Accs.from_dev(allow_revert=True))
factory = Factory[-1]
router = Router02[-1]

# Deploy Token + Masterchef
iza = IzaToken.deploy(Accs.from_dev(allow_revert=True))
resp = iza.addAuthorized(Accs.dev, Accs.from_dev(allow_revert=True))
iza.mint(Accs.dev, int(1e24+1e8))

_start_time = int(chain.time() + 300)
_dev_address = '0x39CeFDd2ED8E8bD62f893810A0E2E75A6C0d9E15'  # Payout addr
_feeAddress = Accs.dev
_marketingAddress = Accs.dev

chef = MasterChef.deploy(iza, _start_time, _dev_address, _feeAddress, _marketingAddress, Accs.from_dev(allow_revert=True))
# Transfer ownership of token to masterchef
iza.transferOwnership(chef, Accs.from_dev())
chef = MasterChef[-1]

# Deploy xIZA contracts
xiza = xToken.deploy("IZA Governance Token", "xIZA", iza.address, chef.address, Accs.dev, Accs.from_dev(allow_revert=True))
sun_maker = SunMaker.deploy(factory, xiza, iza, near, Accs.from_dev(allow_revert=True))
# Set SunMaker to fee address
resp = factory.setFeeTo(sun_maker, Accs.from_dev(allow_revert=True))

# Set staking address
chef.setStakingAddress(xiza, Accs.from_dev(allow_revert=True))

resp = iza.setExcludedFromAntiWhale(chef, True, Accs.from_dev(allow_revert=True))
resp = iza.setExcludedFromAntiWhale(xiza, True, Accs.from_dev(allow_revert=True))
resp = iza.setExcludedFromAntiWhale(sun_maker, True, Accs.from_dev(allow_revert=True))

# Create LP tokens and masterchef pools
# Pool 0 needs to be IZA
chef.add(10, iza, 0, Accs.from_dev(allow_revert=True))

# Approve router to spend everything
approve(weth, router, Accs.dev)
approve(usdc, router, Accs.dev)
approve(usdt, router, Accs.dev)
approve(near, router, Accs.dev)
approve(ust, router, Accs.dev)
approve(aurora, router, Accs.dev)
approve(iza, router, Accs.dev)
approve(xiza, router, Accs.dev)

# Create LP tokens
resp = factory.createPair(weth, usdc, Accs.from_dev())
lp_usdc_weth = resp.events['PairCreated']['pair']

resp = factory.createPair(ust, usdc, Accs.from_dev())
lp_usdc_ust = resp.events['PairCreated']['pair']

resp = factory.createPair(usdt, usdc, Accs.from_dev())
lp_usdc_usdt = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, usdc, Accs.from_dev())
lp_iza_usdc = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, weth, Accs.from_dev())
lp_iza_weth = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, near, Accs.from_dev())
lp_iza_near = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, aurora, Accs.from_dev())
lp_iza_aurora = resp.events['PairCreated']['pair']

price_eth = 2607
price_near = 10.21
price_aurora = 6.93

# Add liquidity
resp = router.addLiquidity(iza, weth, int(price_eth*1e13*5), int(1e13), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(usdc, weth, int(price_eth*1e1), int(1e13), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(usdc, usdt, 1e10, 1e10, 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(usdc, ust, 1e10, 1e22, 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(iza, usdc, int(5e22), int(1e10), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(iza, aurora, 5e22, int(1e22/price_aurora), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(iza, near, 5e22, int(1e28/price_near), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())


# Add LPs to masterchef
assert chef.poolLength() == 1, f"already have pools?? {chef.poolLength()}"
chef.add(10, lp_iza_usdc, 0, Accs.from_dev())  # 1
chef.add(9, lp_iza_weth, 60, Accs.from_dev())  # 2
chef.add(8, lp_iza_near, 120, Accs.from_dev())  # 3
chef.add(8, lp_iza_aurora, 420, Accs.from_dev())  # 4

assert chef.poolLength() == 5, "bad pool length"

for cont in [IzaToken, Factory, Router02, xToken, SunMaker, MasterChef]:
    save_verification_json(cont)

print(f"""
Contract Addresses
------------------------------
Tokens:
WETH    \t{weth}
USDC    \t{usdc}
USDT    \t{usdt}
NEAR    \t{near}
AURORA  \t{aurora}

AMM:
factory \t{factory}
router  \t{router}
pair hash\t{factory.pairCodeHash()}

Farm:
IZA     \t{iza}
xIZA    \t{xiza}
masterchef\t{chef}
sunmaker\t{sun_maker}

LP Addresses:
USDC/WETH LP\t{lp_usdc_weth}
USDC/USDT LP\t{lp_usdc_usdt}
USDC/UST LP\t{lp_usdc_ust}
IZA/USDC LP\t{lp_iza_usdc}
IZA/WETH LP\t{lp_iza_weth}
IZA/NEAR LP\t{lp_iza_near}
IZA/AURORA LP\t{lp_iza_aurora}

""")


for pid in range(1, chef.poolLength()):
    lp = chef.poolInfo(pid)[0]
    bal = balanceOf(lp, Accs.dev)
    if bal > 0:
        approve(lp, chef, Accs.dev)
        chef.deposit(pid, int(bal/2), Accs.dev, Accs.from_dev())




addr = addrs[-1]
for tok in [tusdc, tone, teth, tftm, tmim]:
    tok.mint(addr, int(1e22), Accs.from_dev())
iza.transfer(addr, 1e21, Accs.from_dev())
Accs.dev.transfer(addr, 1e19)


# Print out all pool names
for pid in range(1, chef.poolLength()):
    lp = Contract.from_abi("lp", chef.poolInfo(pid)[0], UniswapV2Pair.abi)
    print(f"{interface.ERC20(lp.token0()).symbol()}/{interface.ERC20(lp.token1()).symbol()}")



print(xiza.balanceOf(Accs.dev)/1e18)
print(iza.balanceOf(Accs.dev)/1e18)
print(iza.balanceOf(xiza)/1e18)
print(chef.pendingToken(0, Accs.dev)/1e18)
print(chef.pendingToken(0, xiza)/1e18)
print(chef.userInfo(0, Accs.dev)[0]/1e18)
print(chef.userInfo(0, xiza)[0]/1e18)

print()
print(xiza.balanceOf(Accs.dev)/1e18)
print(chef.pendingToken(2, Accs.dev)/1e18)
print(chef.pendingToken(0, xiza)/1e18)
print(xiza.balanceOfThis()/1e18)
print(xiza.totalSupply()/1e18)
print(xiza.getPricePerFullShare()/1e18)
print()
