const assert = require('assert')
const fs = require('fs')
const { join } = require('path')
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
    before(async () => {
        console.log('Deploying new hydro token...')
        hydroToken = await HydroTokenTestnet.new({gas: 8e6})
        console.log('Deploying new identity registry...')
        identityRegistry = await IdentityRegistry.new({gas: 8e6})
        console.log('Deploying new randomizer...')
        randomizer = await Randomizer.new({gas: 8e6})
        console.log('Deploying new hydro lottery...')
        hydroLottery = await HydroLottery.new(identityRegistry.address, hydroToken.address, randomizer.address, {gas: 8e6})

        // hydroToken = await HydroTokenTestnet.deployed()
        // identityRegistry = await IdentityRegistry.deployed()
        // randomizer = await Randomizer.deployed()
        // hydroLottery = await HydroLottery.deployed()

        console.log('Setting lottery on randomizer')
        // Set Hydro Lottery's address inside our Randomizer instance
        await randomizer.setHydroLottery(hydroLottery.address)
        console.log('Creating identity one')
        // EIN 1
        await identityRegistry.createIdentity(accounts[0], accounts, accounts)
        console.log('Creating identity two')
        // EIN 2
        await identityRegistry.createIdentity(accounts[1], accounts, accounts, { from: accounts[1] })
    })

    it.skip('Should create a new lottery', async () => {
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

    it.skip('Should move the hydro token reward to the escrow contract when creating a new lottery', async () => {
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

    it.skip('Should buy a ticket for a lottery successfully with enough funds', async () => {
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

    it('Should end a lottery after the time runs out with the raffle() function', async () => {
        const lotteryId = 0
        const hydroPrice = 100
        const ein = parseInt(await identityRegistry.getEIN(accounts[0]))
        const name = fillBytes32WithSpaces('Example')
        const description = 'This is an example'
        const hydroReward = 1000
        const startTime = Math.floor(new Date().getTime() / 1000)
        const endTime = Math.floor(new Date().getTime() / 1000) + 300 // 300 seconds after now
        const fee = 10
        const feeReceiver = accounts[0]
        let counterTime = Math.floor(new Date().getTime() / 1000)
        let approval

        console.log('Setting up ein 3...')
        // EIN 3
        await identityRegistry.createIdentity(accounts[2], accounts, accounts, { from: accounts[2] })
        console.log('Setting up ein 4...')
        // EIN 4
        await identityRegistry.createIdentity(accounts[3], accounts, accounts, { from: accounts[3] })

        console.log('Creating lottery\'s approval...')
        await hydroToken.approve(hydroLottery.address, hydroReward, {
            from: accounts[0],
            gas: 8e6
        })

        approval = parseInt(await hydroToken.allowance(accounts[0], hydroLottery.address))
        console.log('The approval right now is', approval)
        while(approval == 0) {
            console.log('Waiting for approval confirmation... 10 seconds')
            await asyncSetTimeout(1e3 * 10) // Wait 10 seconds for confirming the approval before buying
            approval = parseInt(await hydroToken.allowance(accounts[0], hydroLottery.address))
            console.log('The approval right now is', approval)
        }

        console.log('Creating lottery...')
        await hydroLottery.createLottery(name, description, hydroPrice, hydroReward, startTime, endTime, fee, feeReceiver, {
            from: accounts[0],
            gas: 8e6
        })

        console.log('Buying ticket 1 transfer...')
        // Transfer tokens to the second account so he can buy some
        await hydroToken.transfer(accounts[1], hydroPrice, {
            from: accounts[0],
            gas: 8e6
        })
        console.log('Buying ticket 1 approve...')
        await hydroToken.approve(hydroLottery.address, hydroPrice, {
            from: accounts[1],
            gas: 8e6
        })

        approval = parseInt(await hydroToken.allowance(accounts[0], accounts[1]))
        console.log('The approval right now is', approval)
        while(approval == 0) {
            console.log('Waiting for approval confirmation... 10 seconds')
            await asyncSetTimeout(1e3 * 10) // Wait 10 seconds for confirming the approval before buying
            approval = parseInt(await hydroToken.allowance(accounts[0], accounts[1]))
            console.log('The approval right now is', approval)
        }

        console.log('Buying ticket 1 buy...')
        await hydroLottery.buyTicket(lotteryId, {
            from: accounts[1],
            gas: 8e6
        })
        console.log('Buying ticket 2 transfer...')
        // Transfer tokens to the third account so he can buy some
        await hydroToken.transfer(accounts[2], hydroPrice, {
            from: accounts[0],
            gas: 8e6
        })
        console.log('Buying ticket 2 approve...')
        await hydroToken.approve(hydroLottery.address, hydroPrice, {
            from: accounts[2],
            gas: 8e6
        })

        approval = parseInt(await hydroToken.allowance(accounts[0], accounts[2]))
        console.log('The approval right now is', approval)
        while(approval == 0) {
            console.log('Waiting for approval confirmation... 10 seconds')
            await asyncSetTimeout(1e3 * 10) // Wait 10 seconds for confirming the approval before buying
            approval = parseInt(await hydroToken.allowance(accounts[0], accounts[2]))
            console.log('The approval right now is', approval)
        }

        console.log('Buying ticket 2 buy...')
        await hydroLottery.buyTicket(lotteryId, {
            from: accounts[2],
            gas: 8e6
        })
        console.log('Buying ticket 3 transfer...')
        // Transfer tokens to the fourth account so he can buy some
        await hydroToken.transfer(accounts[3], hydroPrice, {
            from: accounts[0],
            gas: 8e6
        })
        console.log('Buying ticket 3 approve...')
        await hydroToken.approve(hydroLottery.address, hydroPrice, {
            from: accounts[3],
            gas: 8e6
        })

        approval = parseInt(await hydroToken.allowance(accounts[0], accounts[3]))
        console.log('The approval right now is', approval)
        while(approval == 0) {
            console.log('Waiting for approval confirmation... 10 seconds')
            await asyncSetTimeout(1e3 * 10) // Wait 10 seconds for confirming the approval before buying
            approval = parseInt(await hydroToken.allowance(accounts[0], accounts[3]))
            console.log('The approval right now is', approval)
        }

        console.log('Buying ticket 3 buy...')
        await hydroLottery.buyTicket(lotteryId, {
            from: accounts[3],
            gas: 8e6
        })

        // If the contract time has not been reached yet, wait a bit
        while(counterTime < endTime) {
            console.log('Counter', counterTime)
            console.log('End time', endTime)
            counterTime = Math.floor(new Date().getTime() / 1000)
            await asyncSetTimeout(5e3)
        }

        console.log('Running raffle after time is up...')
        // To run the raffle we need to create the lottery, add 3 participants, run the time to the future and run the raffle()
        await hydroLottery.raffle(lotteryId, {
            from: accounts[0],
            gas: 8e6,
            value: '100000000000000000' // 0.1 ETH in wei
        })
        await asyncSetTimeout(1e3 * 100) // Wait 100 seconds for oraclize to generate the random number

        const lottery = await hydroLottery.lotteryById(lotteryId)
        console.log('Final lottery', lottery)
        assert.ok(lottery.einWinner != 0, 'The lottery winner must be set')
    })
})

function asyncSetTimeout(time) {
    return new Promise((resolve, reject) => {
        setTimeout(() => {
            resolve()
        }, time)
    })
}

// To test bytes32 functions
function fillBytes32WithSpaces(name) {
    let nameHex = web3.utils.toHex(name)
    for(let i = nameHex.length; i < 66; i++) {
        nameHex = nameHex + '0'
    }
    return nameHex
}
