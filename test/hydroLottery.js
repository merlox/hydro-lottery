const assert = require('assert')
const HydroLottery = artifacts.require('HydroLottery')
const IdentityRegistry = artifacts.require('IdentityRegistry')
const HydroTokenTestnet = artifacts.require('HydroTokenTestnet')
let hydroToken = {}
let identityRegistry = {}
let hydroLottery = {}

// 1. Write tests to deploy the token contract with truffle on ganache
// 2. Deploy the identity registry
// 3. Get an EIN for my account since it’s necessary
// 4. Get tokens since we need them
// 5. Run the createLottery function
// Do test random key generation with my own oracle instead of oraclize since oraclize is expensive. When the tests are completed, deploy it to ropsten or rinkeby and use the real oraclize although it may only work on mainnet, test that.
contract('HydroLottery', () => {
    // Deploy a new HydroLottery, Token and Registry before each test to avoid messing shit up
    beforeEach(async () => {
        hydroToken = await HydroTokenTestnet.new()
        identityRegistry = await IdentityRegistry.new()
        hydroLottery = await HydroLottery.new(identityRegistry.address, hydroToken.address)

        console.log('Token address', hydroToken.address)
        console.log('Registry address', identityRegistry.address)
        console.log('Lottery address', hydroLottery.address)
    })

    it('Should start', async () => {
        console.log('hi')
    })
})

// To test bytes32 functions
function fillBytes32WithSpaces(name) {
    let nameHex = myWeb3.utils.toHex(name)
    for(let i = nameHex.length; i < 66; i++) {
        nameHex = nameHex + '0'
    }
    return nameHex
}
