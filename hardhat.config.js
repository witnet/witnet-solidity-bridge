const settings = require("./settings")
const utils = require("./src/utils")
const [, target] = utils.getRealmNetworkFromArgs()
module.exports = {
    solidity: settings.getCompilers(target),
};
