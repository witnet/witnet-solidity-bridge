const _debug = false;

function __blank() {
  if (console)
    console.log();
}

function __debug() {
  if (_debug && typeof(console) !== 'undefined') {
    console.log.apply(console, arguments)
  }
}

function __trace() {
  if (typeof(console) !== 'undefined') {
    console.log.apply(console, arguments)
  }
}

module.exports = {
  logs: {
    blank: __blank,
    debug: __debug,
    trace: __trace
  },
  generateDeployTx: require('./generateDeployTx'),
  rawTransactions: require('./rawTransaction'),
  shortenAddr: require('./shortenAddr.js'),
  traceEvents: require('./traceEvents.js'),
}