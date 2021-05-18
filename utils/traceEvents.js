const shortenAddr = require('./shortenAddr')

module.exports = async function (logs, web3) {
  for (var i = 0; i < logs.length; i++) {
    var event = logs[i].event;
    var args = logs[i].args;
    var params = ""

    switch (event) {
      default:
        continue;
    }
  }
}