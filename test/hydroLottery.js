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
contract('HydroLottery', accounts => {
    // Deploy a new HydroLottery, Token and Registry before each test to avoid messing shit up while creatin an EIN and getting tokens
    beforeEach(async () => {
        hydroToken = await HydroTokenTestnet.new()
        identityRegistry = await IdentityRegistry.new()
        hydroLottery = await HydroLottery.new(identityRegistry.address, hydroToken.address)
        // EIN 1
        await identityRegistry.createIdentity(accounts[0], accounts, accounts)
        // EIN 2
        await identityRegistry.createIdentity(accounts[1], accounts, accounts, { from: accounts[1] })
        // EIN 3
        await identityRegistry.createIdentity(accounts[2], accounts, accounts, { from: accounts[2] })
    })

    it('Should create a new lottery', async () => {
        const startTime = Math.floor(new Date().getTime() / 1000) + 1e3
        const endTime = Math.floor(new Date().getTime() / 1000) + 1e6

        // bytes32 _name, string memory _description, uint256 _hydroPricePerTicket, uint256 _hydroReward, uint256 _beginningTimestamp, uint256 _endTimestamp, uint256 _fee, address payable _feeReceiver
        await hydroLottery.createLottery(fillBytes32WithSpaces('Example'), 'This is an example', 100, 1000, startTime, endTime, 10, accounts[0])
        const lottery = await hydroLottery.lotteryById(1)
    })
})

// To test bytes32 functions
function fillBytes32WithSpaces(name) {
    let nameHex = web3.utils.toHex(name)
    for(let i = nameHex.length; i < 66; i++) {
        nameHex = nameHex + '0'
    }
    return nameHex
}
