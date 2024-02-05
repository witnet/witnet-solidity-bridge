
const artifacts = require("./artifacts")
const { merge } = require("lodash")
const networks = require("./networks")
const specs = require("./specs")
const solidity = require("./solidity")
const utils = require("../src/utils")

module.exports = {
    getArtifacts: (network) => {
        const [eco, net] = utils.getRealmNetworkFromArgs(network);
        return merge(
            artifacts.default,
            artifacts[eco],
            artifacts[net]
        );
    },
    getCompilers: (network) => {
        const [eco, net] = utils.getRealmNetworkFromArgs(network);
        return merge(
            solidity.default,
            solidity[eco],
            solidity[net],
        );
    },
    getNetworks: (network) => {
        const [eco, net] = utils.getRealmNetworkFromArgs(network);
        return merge(
            networks.default,
            networks[eco],
            networks[net],
        );
    },
    getSpecs: (network) => {
        const [eco, net] = utils.getRealmNetworkFromArgs(network);
        return merge(
            specs.default,
            specs[eco],
            specs[net]
        );
    },
    artifacts, networks, solidity, specs,
};
