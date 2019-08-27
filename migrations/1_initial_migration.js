const Migrations = artifacts.require("Migrations");

module.exports = function (deployer) {
  console.log("Migrating your contracts...\n===========================")
  deployer.deploy(Migrations)
}
