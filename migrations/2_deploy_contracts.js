var WBI=artifacts.require ("./WitnetBridgeInterface.sol");

module.exports = function(deployer) {
      deployer.deploy(WBI);
}
