const assert = require('assert')
const fs = require('fs')
const { join } = require('path')
const Web3 = require('web3')
const RandomizerTest = artifacts.require('RandomizerTest')
const randomizedTestABI = JSON.parse(fs.readFileSync(join(__dirname, '../build/contracts', 'RandomizerTest.json')))
const infura = 'wss://ropsten.infura.io/ws/v3/f7b2c280f3f440728c2b5458b41c663d'
let randomizerTest = {}

// 1. Write tests to deploy the token contract with truffle on ganache
// 2. Deploy the identity registry
// 3. Get an EIN for my account since it’s necessary
// 4. Get tokens since we need them
// 5. Run the createLottery function
// Do test random key generation with my own oracle instead of oraclize since oraclize is expensive. When the tests are completed, deploy it to ropsten or rinkeby and use the real oraclize although it may only work on mainnet, test that.
contract('HydroLottery', accounts => {
    // Deploy a new HydroLottery, Token and Registry before each test to avoid messing shit up while creatin an EIN and getting tokens
    beforeEach(async () => {
        web3 = new Web3(new Web3.providers.WebsocketProvider(infura))
        contractAddress = ABI.networks['3'].address
        randomizerTest = new web3.eth.Contract(randomizedTestABI.abi, contractAddress)

        console.log('Listening to events...')
        // Listen to the generate random event for executing the __callback() function
        const subscription = randomizerTest.events.ShowRandomResult()
        subscription.on('data', newEvent => {
            callback('New event', newEvent)
        })
    })

    it('Should run oraclize', async () => {
        await randomizerTest.methods.startGeneratingRandom().send({
            from: accounts[0],
            gas: 8e6,
            value: 0.1
        })
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
