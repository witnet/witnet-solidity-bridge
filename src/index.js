const addresses = require("./migrations/witnet.addresses.json");
const { merge } = require("lodash")
module.exports = {
    getAddresses: (network) => {
        const [eco, net] = utils.getRealmNetworkFromArgs(network);
        return merge(
            addresses.default,
            addresses[eco],
            addresses[net],
        );
    },
    getNetworks: () => {
        return Object(addresses).entries.map(entry => {
            if (entry[0].indexOf(":") > -1) {
                return entry[1]
            }
        });
    },
    artifacts: require("../artifacts"),
    settings: require("../settings"),
    utils: require("./utils"),
}