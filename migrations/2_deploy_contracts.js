const HydroLottery = artifacts.require('./HydroLottery.sol')
const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const HydroTokenTestnet = artifacts.require('./HydroTokenTestnet.sol')
const Randomizer = artifacts.require('./Randomizer.sol')
const RandomizerTest = artifacts.require('./RandomizerTest.sol')
let tokenInstance
let identityRegistryInstance
let randomizer

module.exports = (deployer, network) => {
    if(network != 'live'){
        console.log('Deploying contracts...')
        deployer.then(() => {
            return HydroTokenTestnet.new()
        }).then(token => {
            tokenInstance = token.address
            console.log('Deployed token', tokenInstance)
            return IdentityRegistry.new()
        }).then(identityRegistry => {
            identityRegistryInstance = identityRegistry.address
            console.log('Deployed identityRegistry', identityRegistryInstance)
            return Randomizer.new()
        }).then(_randomizer => {
            randomizer = _randomizer.address
            console.log('Deployed randomizer', randomizer)
            return deployer.deploy(
                HydroLottery,
                identityRegistryInstance,
                tokenInstance,
                randomizer, {
                    gas: 8e6
                }
            )
        }).then(hydroLottery => {
            console.log('Deployed hydroLottery', hydroLottery.address)
        })
    }
}
