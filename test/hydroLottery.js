const assert = require('assert')
const fs = require('fs')
const { join } = require('path')
const Web3 = require('web3')
const IdentityRegistry = artifacts.require('IdentityRegistry')
const HydroTokenTestnet = artifacts.require('HydroTokenTestnet')
const Randomizer = artifacts.require('Randomizer')
const HydroLottery = artifacts.require('HydroLottery')
const hydroLotteryABI = JSON.parse(fs.readFileSync(join(__dirname, '../build/contracts', 'HydroLottery.json')))
let hydroToken = {}
let identityRegistry = {}
let hydroLottery = {}
let randomizer = {}

// 1. Write tests to deploy the token contract with truffle on ganache
// 2. Deploy the identity registry
// 3. Get an EIN for my account since it’s necessary
// 4. Get tokens since we need them
// 5. Run the createLottery function
// Do test random key generation with my own oracle instead of oraclize since oraclize is expensive. When the tests are completed, deploy it to ropsten or rinkeby and use the real oraclize although it may only work on mainnet, test that.
contract('HydroLottery', accounts => {
    // Deploy a new HydroLottery, Token and Registry before each test to avoid messing shit up while creatin an EIN and getting tokens
    beforeEach(async () => {
        web3 = new Web3(new Web3.providers.WebsocketProvider('http://localhost:8545'))
        hydroToken = await HydroTokenTestnet.new()
        identityRegistry = await IdentityRegistry.new()
        randomizer = await Randomizer.new()
        hydroLottery = await HydroLottery.new.estimateGas(identityRegistry.address, hydroToken.address, randomizer.address)

        // Set Hydro Lottery's address inside our Randomizer instance
        await randomizer.setHydroLottery(hydroLottery.address)
        // EIN 1
        await identityRegistry.createIdentity(accounts[0], accounts, accounts)
        // EIN 2
        await identityRegistry.createIdentity(accounts[1], accounts, accounts, { from: accounts[1] })
        // EIN 3
        await identityRegistry.createIdentity(accounts[2], accounts, accounts, { from: accounts[2] })
    })

    it('Should create a new lottery', async () => {
        const id = 0
        const name = fillBytes32WithSpaces('Example')
        const description = 'This is an example'
        const hydroPrice = 100
        const hydroReward = 1000
        const startTime = Math.floor(new Date().getTime() / 1000) + 1e3
        const endTime = Math.floor(new Date().getTime() / 1000) + 1e6
        const fee = 10
        const feeReceiver = accounts[0]
        const ein = parseInt(await identityRegistry.getEIN(accounts[0]))

        // First reduce the allowance to 0 to avoid race conditions
        await hydroToken.approve(hydroLottery.address, 0, {
            from: accounts[0],
            gas: 8e6
        })

        // Then do the right approval
        await hydroToken.approve(hydroLottery.address, hydroReward, {
            from: accounts[0],
            gas: 8e6
        })

        // bytes32 _name, string memory _description, uint256 _hydroPricePerTicket, uint256 _hydroReward, uint256 _beginningTimestamp, uint256 _endTimestamp, uint256 _fee, address payable _feeReceiver
        await hydroLottery.createLottery(name, description, hydroPrice, hydroReward, startTime, endTime, fee, feeReceiver, {
            from: accounts[0],
            gas: 8e6
        })
        const lottery = await hydroLottery.lotteryById(0)

        // lottery.id, lottery.name, lottery.description, lottery.hydroPrice, lottery.hydroReward, lottery.beginningDate, lottery.endDate, lottery.einOwner, lottery.fee, lottery.feeReceiver, lottery.escrowContract, lottery.einWinner
        assert.equal(id, lottery.id, 'The lottery ID has not been setup properly')
        assert.equal(name, lottery.name, 'The lottery name has not been setup properly')
        assert.equal(description, lottery.description, 'The lottery description has not been setup properly')
        assert.equal(hydroPrice, lottery.hydroPrice, 'The lottery price has not been setup properly')
        assert.equal(hydroReward, lottery.hydroReward, 'The lottery reward has not been setup properly')
        assert.equal(startTime, lottery.beginningDate, 'The lottery start time has not been setup properly')
        assert.equal(endTime, lottery.endDate, 'The lottery end time has not been setup properly')
        assert.equal(ein, lottery.einOwner, 'The lottery EIN owner has not been setup properly')
        assert.equal(fee, lottery.fee, 'The lottery fee has not been setup properly')
    })

    it('Should move the hydro token reward to the escrow contract when creating a new lottery', async () => {
        const id = 0
        const name = fillBytes32WithSpaces('Example')
        const description = 'This is an example'
        const hydroPrice = 100
        const hydroReward = 1000
        const startTime = Math.floor(new Date().getTime() / 1000) + 1e3
        const endTime = Math.floor(new Date().getTime() / 1000) + 1e6
        const fee = 10
        const feeReceiver = accounts[0]
        const ein = parseInt(await identityRegistry.getEIN(accounts[0]))

        // First reduce the allowance to 0 to avoid race conditions
        await hydroToken.approve(hydroLottery.address, 0, {
            from: accounts[0],
            gas: 8e6
        })

        // Then do the right approval
        await hydroToken.approve(hydroLottery.address, hydroReward, {
            from: accounts[0],
            gas: 8e6
        })

        // bytes32 _name, string memory _description, uint256 _hydroPricePerTicket, uint256 _hydroReward, uint256 _beginningTimestamp, uint256 _endTimestamp, uint256 _fee, address payable _feeReceiver
        await hydroLottery.createLottery(name, description, hydroPrice, hydroReward, startTime, endTime, fee, feeReceiver, {
            from: accounts[0],
            gas: 8e6
        })
        const lottery = await hydroLottery.lotteryById(0)
        const escrowTokenBalance = parseInt(await hydroToken.balanceOf(lottery.escrowContract))

        // lottery.id, lottery.name, lottery.description, lottery.hydroPrice, lottery.hydroReward, lottery.beginningDate, lottery.endDate, lottery.einOwner, lottery.fee, lottery.feeReceiver, lottery.escrowContract, lottery.einWinner
        assert.equal(escrowTokenBalance, hydroReward, 'The token balance inside the escrow contract must be the hydro reward when deploying a new lottery')
    })

    it('Should buy a ticket for a lottery successfully with enough funds', async () => {
        const id = 0
        const hydroPrice = 100
        const ein = parseInt(await identityRegistry.getEIN(accounts[0]))
        const name = fillBytes32WithSpaces('Example')
        const description = 'This is an example'
        const hydroReward = 1000
        const startTime = Math.floor(new Date().getTime() / 1000) + 1e3
        const endTime = Math.floor(new Date().getTime() / 1000) + 1e6
        const fee = 10
        const feeReceiver = accounts[0]
        // First reduce the allowance to 0 to avoid race conditions
        await hydroToken.approve(hydroLottery.address, 0, {
            from: accounts[0],
            gas: 8e6
        })
        // Then do the right approval
        await hydroToken.approve(hydroLottery.address, hydroReward, {
            from: accounts[0],
            gas: 8e6
        })

        // bool _id, bytes32 _name, string memory _description, uint256 _hydroPricePerTicket, uint256 _hydroReward, uint256 _beginningTimestamp, uint256 _endTimestamp, uint256 _fee, address payable _feeReceiver
        await hydroLottery.createLottery(name, description, hydroPrice, hydroReward, startTime, endTime, fee, feeReceiver, {
            from: accounts[0],
            gas: 8e6
        })

        // Buy 2 lottery tickets to properly check the id since the first once is zero
        const lottery = await hydroLottery.lotteryById(id)

        // First reduce the allowance to 0 to avoid race conditions
        await hydroToken.approve(hydroLottery.address, 0, {
            from: accounts[0],
            gas: 8e6
        })
        // Then do the right approval
        await hydroToken.approve(hydroLottery.address, hydroPrice, {
            from: accounts[0],
            gas: 8e6
        })
        await hydroLottery.buyTicket(lottery.id, {
            from: accounts[0],
            gas: 8e6
        })

        // Transfer tokens to the second account so he can buy some
        await hydroToken.transfer(accounts[1], 100, {
            from: accounts[0],
            gas: 8e6
        })
        // First reduce the allowance to 0 to avoid race conditions
        await hydroToken.approve(hydroLottery.address, 0, {
            from: accounts[1],
            gas: 8e6
        })
        // Then do the right approval
        await hydroToken.approve(hydroLottery.address, hydroPrice, {
            from: accounts[1],
            gas: 8e6
        })
        await hydroLottery.buyTicket(lottery.id, {
            from: accounts[1],
            gas: 8e6
        })

        const secondEin = parseInt(await identityRegistry.getEIN(accounts[1]))
        const secondEinTicket = parseInt(await hydroLottery.getTicketIdByEin(id, secondEin))
        const totalTickets = (await hydroLottery.getEinsParticipatingInLottery(id)).length
        assert.equal(secondEinTicket, 1, 'The lottery Id of the second ticket must be one to confirm that is has been purchased')
        assert.equal(totalTickets, 2, 'There must be two tickets purchased')
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
