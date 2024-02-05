module.exports = {
  default: {
    solc: {
      version: "0.8.22",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "paris",
      },
    },
  },
}
