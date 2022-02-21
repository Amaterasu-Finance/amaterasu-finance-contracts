
import time
from scripts.deploy_utils import *

Accs = setup_mainnet_accounts()


# WMTV
WETH = "0x8E321596267a4727746b2F48BC8736DB5Da26977"

# # Deploy and Mint test tokens
tusdc = tUSDC.deploy(Accs.from_dev())
tmim = tMIM.deploy(Accs.from_dev())
teth = tETH.deploy(Accs.from_dev())
tftm = tFTM.deploy(Accs.from_dev())
tone = tONE.deploy(Accs.from_dev())

tusdc.mint(Accs.dev, int(1e24))
tmim.mint(Accs.dev, int(1e24))
teth.mint(Accs.dev, int(1e24))
tftm.mint(Accs.dev, int(1e24))
tone.mint(Accs.dev, int(1e24))

tusdc = tUSDC[0]
tmim = tMIM[0]
teth = tETH[0]
tftm = tFTM[0]
tone = tONE[0]

# Deploy AMM
factory = Factory.deploy(Accs.dev, Accs.from_dev())
router = Router02.deploy(factory, WETH, Accs.from_dev())
#factory = Factory[-1]
#router = Router02[-1]

# Deploy Token + Masterchef
iza = IzaToken.deploy(Accs.from_dev())
iza.mint(Accs.dev, int(1e24+1e8))

_start_block = chain.height + 30
_dev_address = Accs.dev
_feeAddress = Accs.dev
_marketingAddress = Accs.dev

chef = MasterChef.deploy(iza, _start_block, _dev_address, _feeAddress, _marketingAddress, Accs.from_dev())
# Transfer ownership of token to masterchef
iza.transferOwnership(chef, Accs.from_dev())

# Deploy xIZA contracts
xiza = xToken.deploy("IZA Governance Token", "xIZA", iza.address, chef.address, Accs.dev, Accs.from_dev())
sun_maker = SunMaker.deploy(factory, xiza, iza, WETH, Accs.from_dev())
# Set SunMaker to fee address
resp = factory.setFeeTo(sun_maker, Accs.from_dev())

# Set staking address
chef.setStakingAddress(xiza, Accs.from_dev())

# Create LP tokens and masterchef pools
# Pool 0 needs to be IZA
chef.add(10, iza, 0, Accs.from_dev())

# Approve router to spend everything
approve(WETH, router, Accs.dev)
approve(tusdc, router, Accs.dev)
approve(tmim, router, Accs.dev)
approve(teth, router, Accs.dev)
approve(tftm, router, Accs.dev)
approve(tone, router, Accs.dev)
approve(iza, router, Accs.dev)
approve(xiza, router, Accs.dev)

# Create LP tokens
resp = factory.createPair(WETH, tusdc, Accs.from_dev())
lp_usdc_mtv = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, tusdc, Accs.from_dev())
lp_iza_usdc = resp.events['PairCreated']['pair']

resp = factory.createPair(iza, WETH, Accs.from_dev())
lp_iza_mtv = resp.events['PairCreated']['pair']

resp = factory.createPair(tusdc, tmim, Accs.from_dev())
lp_usdc_mim = resp.events['PairCreated']['pair']

resp = factory.createPair(tusdc, teth, Accs.from_dev())
lp_usdc_eth = resp.events['PairCreated']['pair']

resp = factory.createPair(tusdc, tftm, Accs.from_dev())
lp_usdc_ftm = resp.events['PairCreated']['pair']

resp = factory.createPair(tusdc, tone, Accs.from_dev())
lp_usdc_one = resp.events['PairCreated']['pair']


price_eth = 3145
price_ftm = 2.31
price_one = 0.222
price_mtv = 0.01

# Add liquidity
resp = router.addLiquidity(iza, WETH, int(price_mtv*1e18/2), int(1e18), 0, 0, Accs.dev, int(chain.time()+3000), Accs.from_dev())
resp = router.addLiquidity(iza, tusdc, 1e22, 2e22, 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(tusdc, WETH, int(price_mtv*1e18), int(1e18), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(tusdc, tmim, 1e22, 1e22, 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(tusdc, teth, 1e22, int(1e22/price_eth), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(tusdc, tftm, 1e22, int(1e22/price_ftm), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())
resp = router.addLiquidity(tusdc, tone, 1e22, int(1e22/price_one), 0, 0, Accs.dev, int(time.time()+3000), Accs.from_dev())


# Add LPs to masterchef
assert chef.poolLength() == 1, f"already have pools?? {chef.poolLength()}"
chef.add(10, lp_iza_mtv, 0, Accs.from_dev()) # 1
chef.add(9, lp_iza_usdc, 0, Accs.from_dev()) # 2
chef.add(8, lp_usdc_mtv, 0, Accs.from_dev()) # 3
chef.add(7, lp_usdc_mim, 0, Accs.from_dev()) # 4
chef.add(6, lp_usdc_eth, 0, Accs.from_dev()) # 5
chef.add(5, lp_usdc_ftm, 0, Accs.from_dev()) # 6
chef.add(4, lp_usdc_one, 0, Accs.from_dev()) # 7

assert chef.poolLength() == 8, "bad pool length"

for pid in range(1, chef.poolLength()):
    lp = chef.poolInfo(pid)[0]
    bal = balanceOf(lp, Accs.dev)
    if bal > 0:
        approve(lp, chef, Accs.dev)
        chef.deposit(pid, int(bal/2), Accs.dev, Accs.from_dev())


print(f"""
Contract Addresses
------------------------------
Tokens:
WMTV    \t{WETH}
tUSDC   \t{tusdc}
tETH    \t{teth}
tFTM    \t{tftm}
tMIM    \t{tmim}
tONE    \t{tone}

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
IZA/USDC LP\t{lp_iza_usdc}
IZA/MTV LP\t{lp_iza_mtv}
USDC/MTV LP\t{lp_usdc_mtv}
tUSDC/tMIM LP\t{lp_usdc_mim}
tUSDC/eETH LP\t{lp_usdc_eth}
tUSDC/tFTM LP\t{lp_usdc_ftm}
tUSDC/tONE LP\t{lp_usdc_one}

""")


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



