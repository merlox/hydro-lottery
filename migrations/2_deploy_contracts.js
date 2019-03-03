const HydroLottery = artifacts.require('./HydroLottery.sol')
const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const HydroTokenTestnet = artifacts.require('./HydroTokenTestnet.sol')
let tokenInstance
let identityRegistryInstance

module.exports = (deployer, network) => {
    if(network != 'live'){
        console.log('Deploying contracts...')
        deployer.then(() => {
            return HydroTokenTestnet.new()
        }).then(token => {
            tokenInstance = token.address
            console.log('Deployed token', tokenInstance)
        }).then(() => {
            return IdentityRegistry.new()
        }).then(identityRegistry => {
            identityRegistryInstance = identityRegistry.address
            console.log('Deployed identityRegistry', identityRegistryInstance)
            return deployer.deploy(
                HydroLottery,
                identityRegistryInstance,
                tokenInstance, {
                    gas: 8e6
                }
            )
        }).then(hydroLottery => {
            console.log('Deployed hydroLottery', hydroLottery.address)
        })
    }
}
