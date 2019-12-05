var NewBlockRelay = artifacts.require("NewBlockRelay")

module.exports = function (deployer, network) {
  console.log(`> Migrating NewBlockRelay into ${network} network`)
  deployer.deploy(NewBlockRelay, 1568559600, 90)
}