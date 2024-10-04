import("chai")

const utils = require("../src/utils")
const { expectEvent, expectRevert } = require("@openzeppelin/test-helpers")
const { expectRevertCustomError } = require("custom-error-test-helper")

const WitOracleRadonRegistry = artifacts.require("WitOracleRadonRegistryDefault")
const WitOracleRadonEncodingLib = artifacts.require("WitOracleRadonEncodingLib")
const Witnet = artifacts.require("Witnet")

contract("WitOracleRadonRegistry", (accounts) => {
  const creatorAddress = accounts[0]
  const firstOwnerAddress = accounts[1]
  const unprivilegedAddress = accounts[4]

  let radonRegistry

  before(async () => {
    await WitOracleRadonRegistry.link(WitOracleRadonEncodingLib, WitOracleRadonEncodingLib.address)
    radonRegistry = await WitOracleRadonRegistry.new(
      true,
      utils.fromAscii("testing")
    )
  })

  beforeEach(async () => {
    /* before each context */
  })

  context("Ownable2Step", async () => {
    it("should revert if transferring ownership from stranger", async () => {
      await expectRevert.unspecified(
        radonRegistry.transferOwnership(unprivilegedAddress, { from: unprivilegedAddress }),
      )
    })
    it("owner can start transferring ownership", async () => {
      const tx = await radonRegistry.transferOwnership(firstOwnerAddress, { from: creatorAddress })
      expectEvent(
        tx.receipt,
        "OwnershipTransferStarted",
        { newOwner: firstOwnerAddress }
      )
    })
    it("stranger cannot accept transferring ownership", async () => {
      await expectRevert(
        radonRegistry.acceptOwnership({ from: unprivilegedAddress }),
        "not the new owner"
      )
    })
    it("ownership is fully transferred upon acceptance", async () => {
      const tx = await radonRegistry.acceptOwnership({ from: firstOwnerAddress })
      expectEvent(
        tx.receipt,
        "OwnershipTransferred",
        {
          previousOwner: creatorAddress,
          newOwner: firstOwnerAddress,
        }
      )
      assert.equal(firstOwnerAddress, await radonRegistry.owner())
    })
  })

  context("Upgradeable", async () => {
    it("should manifest to be upgradable from actual owner", async () => {
      assert.equal(
        await radonRegistry.isUpgradableFrom(firstOwnerAddress),
        true
      )
    })
    it("should manifest to not be upgradable from anybody else", async () => {
      assert.equal(
        await radonRegistry.isUpgradableFrom(unprivilegedAddress),
        false
      )
    })
    it("cannot be initialized more than once", async () => {
      await expectRevert(
        radonRegistry.initialize("0x", { from: firstOwnerAddress }),
        "already initialized"
      )
      await expectRevert(
        radonRegistry.initialize("0x", { from: unprivilegedAddress }),
        "not the owner"
      )
    })
  })

  context("IWitOracleRadonRegistry", async () => {
    let slaHash

    let concathashReducerHash
    let modeNoFiltersReducerHash
    let stdev15ReducerHash
    let stdev25ReducerHash

    let rngSourceHash
    let binanceTickerHash
    let binanceUsdTickerHash
    let uniswapToken1PriceHash

    let rngHash

    let btcUsdPriceFeedHash

    context("verifyRadonRetrieval(..)", async () => {
      context("Witnet.RadonRetrievalMethods.RNG", async () => {
        it("emits appropiate single event when verifying randomness data source for the first time", async () => {
          const tx = await radonRegistry.verifyRadonRetrieval(
            2, // requestMethod
            "", // requestURL
            "", // requestBody
            [], // requestHeaders
            "0x80", // requestRadonScript
          )
          expectEvent(
            tx.receipt,
            "NewRadonRetrieval"
          )
          rngSourceHash = tx.logs[0].args.hash
        })
        it("emits no event when verifying already existing randomness data source", async () => {
          const tx = await radonRegistry.verifyRadonRetrieval(
            2, // requestMethod
            "", // requestURL
            "", // requestBody
            [], // requestHeaders
            "0x80", // requestRadonScript
          )
          assert.equal(tx.logs.length, 0, "some unexpected event was emitted")
        })
        it("generates proper hash upon offchain verification of already existing randmoness source", async () => {
          const hash = await radonRegistry.methods["verifyRadonRetrieval(uint8,string,string,string[2][],bytes)"].call(
            2, // requestMethod
            "", // requestURL
            "", // requestBody
            [], // requestHeaders
            "0x80", // requestRadonScript
          )
          assert.equal(hash, rngSourceHash)
        })
        // ... reverts
      })
      context("Witnet.RadonRetrievalMethods.HttpGet", async () => {
        it(
          "emits new data provider and source events when verifying a new http-get source for the first time", async () => {
            const tx = await radonRegistry.verifyRadonRetrieval(
              1, // requestMethod
              "https://api.binance.us/api/v3/ticker/price?symbol=\\0\\\\1\\", 
              "", // requestBody
              [], // requestHeaders
              "0x841877821864696c61737450726963658218571a000f4240185b", // requestRadonScript
            )
            // expectEvent(
            //   tx.receipt,
            //   "NewDataProvider"
            // )
            // assert.equal(tx.logs[0].args.index, 1)
            expectEvent(
              tx.receipt,
              "NewRadonRetrieval"
            )
            binanceTickerHash = tx.logs[0].args.hash
          })
        it("data source metadata gets stored as expected", async () => {
          const ds = await radonRegistry.lookupRadonRetrieval(binanceTickerHash)
          assert.equal(ds.method, 1) // HTTP-GET
          assert.equal(ds.dataType, 4) // Integer
          assert.equal(ds.url, "https://api.binance.us/api/v3/ticker/price?symbol=\\0\\\\1\\")
          assert.equal(ds.body, "")
          assert(ds.headers.length === 0)
          assert.equal(ds.radonScript, "0x841877821864696c61737450726963658218571a000f4240185b")
        })
        it("emits one single event when verifying new http-get endpoint to already existing provider", async () => {
          const tx = await radonRegistry.verifyRadonRetrieval(
            1, // requestMethod
            "http://api.binance.us/api/v3/ticker/24hr?symbol=\\0\\\\1\\", // requestQuery
            "", // requestBody
            [], // requestHeaders
            "0x841877821864696c61737450726963658218571a000f4240185b", // requestRadonScript
          )
          assert.equal(tx.logs.length, 1)
          expectEvent(
            tx.receipt,
            "NewRadonRetrieval"
          )
        })
        it("fork existing retrieval by settling one out of two parameters", async () => {
          const tx = await radonRegistry.verifyRadonRetrieval(
            binanceTickerHash,
            "USD" 
          )
          assert.equal(tx.logs.length, 1)
          expectEvent(
            tx.receipt,
            "NewRadonRetrieval"
          )
          binanceUsdTickerHash = tx.logs[0].args.hash
        })
        it("metadata of forked retrieval gets stored as expected", async () => {
          const ds = await radonRegistry.lookupRadonRetrieval.call(binanceUsdTickerHash)
          assert.equal(ds.method, 1) // HTTP-GET
          assert.equal(ds.dataType, 4) // Integer
          assert.equal(ds.url, "https://api.binance.us/api/v3/ticker/price?symbol=\\0\\USD")
          assert.equal(ds.body, "")
          assert(ds.headers.length === 0)
          assert.equal(ds.radonScript, "0x841877821864696c61737450726963658218571a000f4240185b")
        })
      })
      context("Witnet.RadonRetrievalMethods.HttpPost", async () => {
        it(
          "emits new data provider and source events when verifying a new http-post source for the first time", async () => {
            const tx = await radonRegistry.verifyRadonRetrieval(
              3, // requestMethod
              "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3",
              "{\"query\":\"{pool(id:\"\\0\\\"){token1Price}}\"}", // requestBody
              [
                ["user-agent", "witnet-rust"],
                ["content-type", "text/html; charset=utf-8"],
              ], // requestHeaders
              "0x861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b", // requestRadonScript
            )
            // expectEvent(
            //   tx.receipt,
            //   "NewDataProvider"
            // )
            // assert.equal(tx.logs[0].args.index, 2)
            expectEvent(
              tx.receipt,
              "NewRadonRetrieval"
            )
            uniswapToken1PriceHash = tx.logs[0].args.hash
          })
        it("data source metadata gets stored as expected", async () => {
          const ds = await radonRegistry.lookupRadonRetrieval(uniswapToken1PriceHash)
          assert.equal(ds.method, 3) // HTTP-GET
          assert.equal(ds.dataType, 4) // Integer
          assert.equal(ds.url, "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3")
          assert.equal(ds.body, "{\"query\":\"{pool(id:\"\\0\\\"){token1Price}}\"}")
          assert(ds.headers.length === 2)
          assert.equal(ds.headers[0][0], "user-agent")
          assert.equal(ds.headers[0][1], "witnet-rust")
          assert.equal(ds.headers[1][0], "content-type")
          assert.equal(ds.headers[1][1], "text/html; charset=utf-8")
          assert.equal(ds.radonScript, "0x861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b")
        })
      })
    })

    context("verifyRadonReducer(..)", async () => {
      it("emits event when verifying new radon reducer with no filter", async () => {
        const tx = await radonRegistry.verifyRadonReducer([
          11, // opcode: ConcatenateAndHash
          [], // filters
        ])
        expectEvent(
          tx.receipt,
          "NewRadonReducer"
        )
        concathashReducerHash = tx.logs[0].args.hash
        // concathashReducerBytecode = tx.logs[0].args.bytecode
      })
      it("emits no event when verifying an already verified radon sla with no filter", async () => {
        const tx = await radonRegistry.verifyRadonReducer([
          11, // ConcatenateAndHash
          [], // filters
        ])
        assert.equal(
          tx.logs.length,
          0,
          "some unexpected event was emitted"
        )
      })
      it("generates proper hash upon offchain call", async () => {
        const hash = await radonRegistry.verifyRadonReducer.call([
          11, // ConcatenateAndHash
          [], // filters
        ])
        assert.equal(hash, concathashReducerHash)
      })
      it("reverts if verifying radon reducer with unsupported opcode", async () => {
        await expectRevert.unspecified(
          radonRegistry.verifyRadonReducer([
            0, // Minimum
            [], // filters
          ]),
        )
      })
      it("reverts if verifying radon reducer with at least one unsupported filter", async () => {
        await expectRevert.unspecified(
          radonRegistry.verifyRadonReducer([
            5, // AverageMedian
            [
              [8, "0x"], // Mode: supported
              [0, "0x"], // Greater than: not yet supported
            ],
          ]),
        )
      })
      it("reverts if verifying radon reducer with stdev filter but no args", async () => {
        await expectRevert.unspecified(
          radonRegistry.verifyRadonReducer([
            2, // Mode
            [
              [5, "0x"], // Standard deviation filter
            ],
          ]),
        )
      })
      it("verifying radon reducer with stdev filter and args works", async () => {
        let tx = await radonRegistry.verifyRadonReducer([
          3, // AverageMean
          [
            [5, "0xF93E00"], // StdDev(1.5) filter
          ],
        ])
        expectEvent(
          tx.receipt,
          "NewRadonReducer"
        )
        stdev15ReducerHash = tx.logs[0].args.hash
        tx = await radonRegistry.verifyRadonReducer([
          2, // Mode
          [
            [5, "0xF94100"], // StdDev(2.5) filter
          ],
        ])
        stdev25ReducerHash = tx.logs[0].args.hash
      })
    })

    context("verifyRadonRequest(..)", async () => {
      context("Use case: Randomness", async () => {
        it("emits single event when verifying new radomness request", async () => {
          let tx = await radonRegistry.verifyRadonReducer([
            2, // Mode
            [], // no filters
          ])
          expectEvent(
            tx.receipt,
            "NewRadonReducer"
          )
          modeNoFiltersReducerHash = tx.logs[0].args.hash
          //   modeNoFiltersReducerBytecode = tx.logs[0].args.bytecode
          tx = await radonRegistry.verifyRadonRequest(
            [ // sources
              rngSourceHash,
            ],
            modeNoFiltersReducerHash, // aggregator
            concathashReducerHash, // tally
            0, [[]], // sourcesArgs
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRequest"
          )
          rngHash = tx.logs[0].args.radHash
        })
        it("emits no event when verifying same randomness request", async () => {
          const tx = await radonRegistry.verifyRadonRequest(
            [ // sources
              rngSourceHash,
            ],
            modeNoFiltersReducerHash, // aggregator
            concathashReducerHash, // tally
            0, [[]], // sourcesArgs
          )
          assert(tx.logs.length === 0)
        })
        it("generates same hash when verifying same randomness request offchain", async () => {
          const hash = await radonRegistry.methods['verifyRadonRequest(bytes32[],bytes32,bytes32,uint16,string[][])'].call(
            [ // sources
              rngSourceHash,
            ],
            modeNoFiltersReducerHash, // aggregator
            concathashReducerHash, // tally
            0, // resultMaxVariableSize
            [[]], // sourcesArgs
          )
          assert.equal(hash, rngHash)
        })
      })
      context("Use case: Price feeds", async () => {
        it("reverts custom error if trying to verify request w/ templated source and 0 args out of 2", async () => {
          await expectRevert.unspecified(
            radonRegistry.verifyRadonRequest(
              [ // sources
                binanceTickerHash,
              ],
              stdev15ReducerHash, // aggregator
              stdev25ReducerHash, // tally
              0, // resultMaxVariableSize
              [[]],
            )
          )
        })
        it("reverts custom error if trying to verify request w/ templated source and 1 args out of 2", async () => {
          await expectRevert.unspecified(
            radonRegistry.verifyRadonRequest(
              [ // sources
                binanceTickerHash,
              ],
              stdev15ReducerHash, // aggregator
              stdev25ReducerHash, // tally
              0, // resultMaxVariableSize
              [ // sourcesArgs
                ["BTC"],
              ],
            )
          )
        })
        it("emits single event when verifying new price feed request for the first time", async () => {
          const tx = await radonRegistry.verifyRadonRequest(
            [ // source
              binanceTickerHash,
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
            0, // resultMaxVariableSize,
            [
              ["BTC", "USD"], // binance ticker args
            ],
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRequest"
          )
          btcUsdPriceFeedHash = tx.logs[0].args.radHash
          // btcUsdPriceFeedBytecode = tx.logs[0].args.bytecode
        })
        it("verifying radon request with repeated sources works", async () => {
          const tx = await radonRegistry.verifyRadonRequest(
            [ // sources
              binanceTickerHash,
              binanceTickerHash,
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
            0, // resultMaxVariableSize,
            [
              ["BTC", "USD"], // binance ticker args
              ["BTC", "USD"], // binance ticker args
            ],
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRequest"
          )
        })
        it("reverts if trying to verify radon request w/ incompatible sources", async () => {
          await expectRevert(
            radonRegistry.verifyRadonRequest(
              [ // sources
                binanceTickerHash,
                rngSourceHash,
              ],
              stdev15ReducerHash, // aggregator
              stdev25ReducerHash, // tally
              0, // resultMaxVariableSize,
              [
                ["BTC", "USD"], // binance ticker args
                [],
              ],
            ),
            "mismatching retrievals"
          )
        })
        it("emits single event when verifying new radon request w/ http-post source", async () => {
          const tx = await radonRegistry.verifyRadonRequest(
            [ // sources
              uniswapToken1PriceHash,
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
            0, // resultMaxVariableSize,
            [
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
            ],
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRequest"
          )
        })
        it("emits single event when verifying new radon request w/ repeated http-post sources", async () => {
          const tx = await radonRegistry.verifyRadonRequest(
            [ // sources
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
            0, // resultMaxVariableSize,
            [
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
            ],
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRequest"
          )
          heavyRetrievalHash = tx.logs[0].args.radHash
        })
      })
    })

    context("bytecodeOf(..)", async () => {
      context("radon requests", async () => {
        it("reverts if trying to get bytecode from unknown radon request", async () => {
          await expectRevert(
            radonRegistry.bytecodeOf("0x0"),
            "unverified"
          )
        })
        it("works if trying to get bytecode onchain from known radon request", async () => {
          await radonRegistry.bytecodeOf(btcUsdPriceFeedHash)
        })
        it("returns bytecode if getting it offchain from known radon request", async () => {
          await radonRegistry.bytecodeOf(btcUsdPriceFeedHash)
        })
      })
    })
  })
})
