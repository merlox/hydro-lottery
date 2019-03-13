const assert = require('assert')
const fs = require('fs')
const { join } = require('path')
const RandomizerTest = artifacts.require('RandomizerTest')
let randomizerTest = {}

// Do test random key generation with my own oracle instead of oraclize since oraclize is expensive. When the tests are completed, deploy it to ropsten or rinkeby and use the real oraclize although it may only work on mainnet, test that.
contract('RandomizerTest', accounts => {
    // Deploy a new HydroLottery, Token and Registry before each test to avoid messing shit up while creatin an EIN and getting tokens
    beforeEach(async () => {
        randomizerTest = await RandomizerTest.new()
        console.log('Deployed Randomizer', randomizerTest.address)

        console.log('Listening to events...')
        const event = randomizerTest.ShowRandomResult()
        event.on('data', newEvent => {
            callback('New event', newEvent)
        })
    })

    // Skip it to stop running this test
    it('Should run oraclize', async () => {
        console.log('Starting random generation...')
        await randomizerTest.startGeneratingRandom({
            from: accounts[0],
            gas: 8e6,
            value: '100000000000000000' // 0.1 ETH in wei
        })
        console.log('Waiting 1000 seconds for the event from __callback()...')
        await asyncSetTimeout(1000e3)
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
