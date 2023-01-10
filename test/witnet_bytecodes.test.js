const utils = require("../scripts/utils")
const { expectEvent, expectRevert } = require("@openzeppelin/test-helpers")
const { assert } = require("chai")
const { expectRevertCustomError } = require("custom-error-test-helper")

const WitnetBuffer = artifacts.require("WitnetBuffer")
const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetV2 = artifacts.require("WitnetV2")

contract("WitnetBytecodes", (accounts) => {
  const creatorAddress = accounts[0]
  const firstOwnerAddress = accounts[1]
  //   const secondOwnerAddress = accounts[2]
  //   const externalAddress = accounts[3]
  const unprivilegedAddress = accounts[4]

  let bytecodes

  before(async () => {
    bytecodes = await WitnetBytecodes.new(
      true,
      utils.fromAscii("testing")
    )
  })

  beforeEach(async () => {
    /* before each context */
  })

  context("Ownable2Step", async () => {
    it("should revert if transferring ownership from stranger", async () => {
      await expectRevert(
        bytecodes.transferOwnership(unprivilegedAddress, { from: unprivilegedAddress }),
        "not the owner"
      )
    })
    it("owner can start transferring ownership", async () => {
      const tx = await bytecodes.transferOwnership(firstOwnerAddress, { from: creatorAddress })
      expectEvent(
        tx.receipt,
        "OwnershipTransferStarted",
        { newOwner: firstOwnerAddress }
      )
    })
    it("stranger cannot accept transferring ownership", async () => {
      await expectRevert(
        bytecodes.acceptOwnership({ from: unprivilegedAddress }),
        "not the new owner"
      )
    })
    it("ownership is fully transferred upon acceptance", async () => {
      const tx = await bytecodes.acceptOwnership({ from: firstOwnerAddress })
      expectEvent(
        tx.receipt,
        "OwnershipTransferred",
        {
          previousOwner: creatorAddress,
          newOwner: firstOwnerAddress,
        }
      )
      assert.equal(firstOwnerAddress, await bytecodes.owner())
    })
  })

  context("Upgradeable", async () => {
    it("should manifest to be upgradable from actual owner", async () => {
      assert.equal(
        await bytecodes.isUpgradableFrom(firstOwnerAddress),
        true
      )
    })
    it("should manifest to not be upgradable from anybody else", async () => {
      assert.equal(
        await bytecodes.isUpgradableFrom(unprivilegedAddress),
        false
      )
    })
    it("cannot be initialized more than once", async () => {
      await expectRevertCustomError(
        WitnetBytecodes,
        bytecodes.initialize("0x", { from: firstOwnerAddress }),
        "AlreadyUpgraded"
      )
      await expectRevertCustomError(
        WitnetBytecodes,
        bytecodes.initialize("0x", { from: unprivilegedAddress }),
        "OnlyOwner"
      )
    })
  })

  context("IWitnetBytecodes", async () => {
    let slaHash
    let slaBytecode

    let concathashReducerHash
    // let concathashReducerBytecode
    let modeNoFiltersReducerHash
    // let modeNoFitlersReducerBytecode
    let stdev15ReducerHash
    let stdev25ReducerHash

    let rngSourceHash
    let binanceTickerHash
    // let uniswapToken0PriceHash
    let uniswapToken1PriceHash
    let heavyRetrievalHash
    let heavyRetrievalBytecode

    let rngHash
    // let rngBytecode

    let btcUsdPriceFeedHash
    let btcUsdPriceFeedBytecode
    // let fraxUsdtPriceFeedHash
    // let fraxUsdtPriceFeedBytecode

    context("verifyDataSource(..)", async () => {
      context("WitnetV2.DataRequestMethods.Rng", async () => {
        it("emits appropiate single event when verifying randomness data source for the first time", async () => {
          const tx = await bytecodes.verifyDataSource(
            2, // requestMethod
            0, // resultMinRank
            0, // resultMaxRank
            "", // requestSchema
            "", // requestFQDN
            "", // requestPath
            "", // requestQuery
            "", // requestBody
            [], // requestHeaders
            "0x80", // requestRadonScript
          )
          expectEvent(
            tx.receipt,
            "NewDataSourceHash"
          )
          rngSourceHash = tx.logs[0].args.hash
        })
        it("emits no event when verifying already existing randomness data source", async () => {
          const tx = await bytecodes.verifyDataSource(
            2, // requestMethod
            0, // resultMinRank
            0, // resultMaxRank
            "", // requestSchema
            "", // requestFQDN
            "", // requestPath
            "", // requestQuery
            "", // requestBody
            [], // requestHeaders
            "0x80", // requestRadonScript
          )
          assert.equal(tx.logs.length, 0, "some unexpected event was emitted")
        })
        it("generates proper hash upon offchain verification of already existing randmoness source", async () => {
          const hash = await bytecodes.verifyDataSource.call(
            2, // requestMethod
            0, // resultMinRank
            0, // resultMaxRank
            "", // requestSchema
            "", // requestFQDN
            "", // requestPath
            "", // requestQuery
            "", // requestBody
            [], // requestHeaders
            "0x80", // requestRadonScript
          )
          assert.equal(hash, rngSourceHash)
        })
        // ... reverts
      })
      context("WitnetV2.DataRequestMethods.HttpGet", async () => {
        it(
          "emits new data provider and source events when verifying a new http-get source for the first time", async () => {
            const tx = await bytecodes.verifyDataSource(
              1, // requestMethod
              0, // resultMinRank
              0, // resultMaxRank
              "HTTPs://", // requestSchema
              "api.binance.US", // requestFQDN
              "api/v3/ticker/price", // requestPath
              "symbol=\\0\\\\1\\", // requestQuery
              "", // requestBody
              [], // requestHeaders
              "0x841877821864696c61737450726963658218571a000f4240185b", // requestRadonScript
            )
            expectEvent(
              tx.receipt,
              "NewDataProvider"
            )
            assert.equal(tx.logs[0].args.index, 1)
            expectEvent(
              tx.receipt,
              "NewDataSourceHash"
            )
            binanceTickerHash = tx.logs[1].args.hash
          })
        it("data source metadata gets stored as expected", async () => {
          const ds = await bytecodes.lookupDataSource(binanceTickerHash)
          assert.equal(ds.method, 1) // HTTP-GET
          assert.equal(ds.resultDataType, 4) // Integer
          assert.equal(ds.url, "https://api.binance.us/api/v3/ticker/price?symbol=\\0\\\\1\\")
          assert.equal(ds.body, "")
          assert(ds.headers.length === 0)
          assert.equal(ds.script, "0x841877821864696c61737450726963658218571a000f4240185b")
        })
        it("emits one single event when verifying new http-get endpoint to already existing provider", async () => {
          const tx = await bytecodes.verifyDataSource(
            1, // requestMethod
            0, // resultMinRank
            0, // resultMaxRank
            "http://", // requestSchema
            "api.binance.us", // requestFQDN
            "api/v3/ticker/24hr", // requestPath
            "symbol=\\0\\\\1\\", // requestQuery
            "", // requestBody
            [], // requestHeaders
            "0x841877821864696c61737450726963658218571a000f4240185b", // requestRadonScript
          )
          assert.equal(tx.logs.length, 1)
          expectEvent(
            tx.receipt,
            "NewDataSourceHash"
          )
        })
      })
      context("WitnetV2.DataRequestMethods.HttpPost", async () => {
        it(
          "emits new data provider and source events when verifying a new http-post source for the first time", async () => {
            const tx = await bytecodes.verifyDataSource(
              3, // requestMethod
              0, // resultMinRank
              0, // resultMaxRank
              "HTTPs://", // requestSchema
              "api.thegraph.com", // requestFQDN
              "subgraphs/name/uniswap/uniswap-v3", // requestPath
              "", // requestQuery
              "{\"query\":\"{pool(id:\"\\0\\\"){token1Price}}\"}", // requestBody
              [
                ["user-agent", "witnet-rust"],
                ["content-type", "text/html; charset=utf-8"],
              ], // requestHeaders
              "0x861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b", // requestRadonScript
            )
            expectEvent(
              tx.receipt,
              "NewDataProvider"
            )
            assert.equal(tx.logs[0].args.index, 2)
            expectEvent(
              tx.receipt,
              "NewDataSourceHash"
            )
            uniswapToken1PriceHash = tx.logs[1].args.hash
          })
        it("data source metadata gets stored as expected", async () => {
          const ds = await bytecodes.lookupDataSource(uniswapToken1PriceHash)
          assert.equal(ds.method, 3) // HTTP-GET
          assert.equal(ds.resultDataType, 4) // Integer
          assert.equal(ds.url, "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3")
          assert.equal(ds.body, "{\"query\":\"{pool(id:\"\\0\\\"){token1Price}}\"}")
          assert(ds.headers.length === 2)
          assert.equal(ds.headers[0][0], "user-agent")
          assert.equal(ds.headers[0][1], "witnet-rust")
          assert.equal(ds.headers[1][0], "content-type")
          assert.equal(ds.headers[1][1], "text/html; charset=utf-8")
          assert.equal(ds.script, "0x861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b")
        })
      })
    })

    context("verifyRadonReducer(..)", async () => {
      it("emits event when verifying new radon reducer with no filter", async () => {
        const tx = await bytecodes.verifyRadonReducer([
          11, // opcode: ConcatenateAndHash
          [], // filters
          "0x", // script
        ])
        expectEvent(
          tx.receipt,
          "NewRadonReducerHash"
        )
        concathashReducerHash = tx.logs[0].args.hash
        // concathashReducerBytecode = tx.logs[0].args.bytecode
      })
      it("emits no event when verifying an already verified radon sla with no filter", async () => {
        const tx = await bytecodes.verifyRadonReducer([
          11, // ConcatenateAndHash
          [], // filters
          "0x", // script
        ])
        assert.equal(
          tx.logs.length,
          0,
          "some unexpected event was emitted"
        )
      })
      it("generates proper hash upon offchain call", async () => {
        const hash = await bytecodes.verifyRadonReducer.call([
          11, // ConcatenateAndHash
          [], // filters
          "0x", // script
        ])
        assert.equal(hash, concathashReducerHash)
      })
      it("reverts custom error if verifying radon reducer with unsupported opcode", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonReducer([
            0, // Minimum
            [], // filters
            "0x", // script
          ]),
          "UnsupportedRadonReducerOpcode"
        )
      })
      it("reverts custom error if verifying radon reducer with at least one unsupported filter", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonReducer([
            5, // AverageMedian
            [
              [8, "0x"], // Mode: supported
              [0, "0x"], // Greater than: not yet supported
            ],
            "0x", // script
          ]),
          "UnsupportedRadonFilterOpcode"
        )
      })
      it("reverts custom error if verifying radon reducer with stdev filter but no args", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonReducer([
            2, // Mode
            [
              [5, "0x"], // Standard deviation filter
            ],
            "0x", // script
          ]),
          "RadonFilterMissingArgs"
        )
      })
      it("verifying radon reducer with stdev filter and args works", async () => {
        let tx = await bytecodes.verifyRadonReducer([
          3, // AverageMean
          [
            [5, "0xF93E00"], // StdDev(1.5) filter
          ],
          "0x", // script
        ])
        expectEvent(
          tx.receipt,
          "NewRadonReducerHash"
        )
        stdev15ReducerHash = tx.logs[0].args.hash
        tx = await bytecodes.verifyRadonReducer([
          2, // Mode
          [
            [5, "0xF94100"], // StdDev(2.5) filter
          ],
          "0x", // script
        ])
        stdev25ReducerHash = tx.logs[0].args.hash
      })
    })

    context("verifyRadonRetrieval(..)", async () => {
      context("Use case: Randomness", async () => {
        it("emits single event when verifying new radomness retrieval", async () => {
          let tx = await bytecodes.verifyRadonReducer([
            2, // Mode
            [], // no filters
            "0x", // script
          ])
          expectEvent(
            tx.receipt,
            "NewRadonReducerHash"
          )
          modeNoFiltersReducerHash = tx.logs[0].args.hash
          //   modeNoFiltersReducerBytecode = tx.logs[0].args.bytecode
          tx = await bytecodes.verifyRadonRetrieval(
            0, // resultDataType
            0, // resultMaxVariableSize
            [ // sources
              rngSourceHash,
            ],
            [[]], // sourcesArgs
            modeNoFiltersReducerHash, // aggregator
            concathashReducerHash, // tally
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRetrievalHash"
          )
          rngHash = tx.logs[0].args.hash
        //   rngBytecode = tx.logs[0].args.bytecode
        })
        it("emits no event when verifying same randomness retrieval", async () => {
          const tx = await bytecodes.verifyRadonRetrieval(
            0, // resultDataType
            0, // resultMaxVariableSize
            [ // sources
              rngSourceHash,
            ],
            [[]], // sourcesArgs
            modeNoFiltersReducerHash, // aggregator
            concathashReducerHash, // tally
          )
          assert(tx.logs.length === 0)
        })
        it("generates same hash when verifying same randomness retrieval offchain", async () => {
          const hash = await bytecodes.verifyRadonRetrieval.call(
            0, // resultDataType
            0, // resultMaxVariableSize
            [ // sources
              rngSourceHash,
            ],
            [[]], // sourcesArgs
            modeNoFiltersReducerHash, // aggregator
            concathashReducerHash, // tally
          )
          assert.equal(hash, rngHash)
        })
      })
      context("Use case: Price feeds", async () => {
        it("reverts custom error if trying to verify retrieval w/ templated source and 0 args out of 2", async () => {
          await expectRevertCustomError(
            WitnetBuffer,
            bytecodes.verifyRadonRetrieval(
              4, // resultDataType
              0, // resultMaxVariableSize
              [ // sources
                binanceTickerHash,
              ],
              [ // sourcesArgs
                [],
              ],
              stdev15ReducerHash, // aggregator
              stdev25ReducerHash, // tally
            ),
            "MissingArgs", [
              1, // expected
              0, // given
            ]
          )
        })
        it("reverts custom error if trying to verify retrieval w/ templated source and 1 args out of 2", async () => {
          await expectRevertCustomError(
            WitnetBuffer,
            bytecodes.verifyRadonRetrieval(
              4, // resultDataType
              0, // resultMaxVariableSize
              [ // sources
                binanceTickerHash,
              ],
              [ // sourcesArgs
                ["BTC"],
              ],
              stdev15ReducerHash, // aggregator
              stdev25ReducerHash, // tally
            ),
            "MissingArgs", [
              2, // expected
              1, // given
            ]
          )
        })
        it("emits single event when verifying new price feed retrieval for the first time", async () => {
          const tx = await bytecodes.verifyRadonRetrieval(
            4, // resultDataType
            0, // resultMaxVariableSize,
            [ // sources
              binanceTickerHash,
            ],
            [
              ["BTC", "USD"], // binance ticker args
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRetrievalHash"
          )
          btcUsdPriceFeedHash = tx.logs[0].args.hash
          btcUsdPriceFeedBytecode = tx.logs[0].args.bytecode
        })
        it("verifying radon retrieval with repeated sources works", async () => {
          const tx = await bytecodes.verifyRadonRetrieval(
            4, // resultDataType
            0, // resultMaxVariableSize,
            [ // sources
              binanceTickerHash,
              binanceTickerHash,
            ],
            [
              ["BTC", "USD"], // binance ticker args
              ["BTC", "USD"], // binance ticker args
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRetrievalHash"
          )
        })
        it("reverts if trying to verify radon retrieval w/ incompatible sources", async () => {
          await expectRevertCustomError(
            WitnetV2,
            bytecodes.verifyRadonRetrieval(
              4, // resultDataType
              0, // resultMaxVariableSize,
              [ // sources
                binanceTickerHash,
                rngSourceHash,
              ],
              [
                ["BTC", "USD"], // binance ticker args
                [],
              ],
              stdev15ReducerHash, // aggregator
              stdev25ReducerHash, // tally
            ),
            "RadonRetrievalResultsMismatch", [
              1, // index
              0, // read
              4, // expected
            ]
          )
        })
        it("emits single event when verifying new radon retrieval w/ http-post source", async () => {
          const tx = await bytecodes.verifyRadonRetrieval(
            4, // resultDataType
            0, // resultMaxVariableSize,
            [ // sources
              uniswapToken1PriceHash,
            ],
            [
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRetrievalHash"
          )
        //   fraxUsdtPriceFeedHash = tx.logs[0].args.hash
        //   fraxUsdtPriceFeedBytecode = tx.logs[0].args.bytecode
        })
        it("emits single event when verifying new radon retrieval w/ repeated http-post sources", async () => {
          const tx = await bytecodes.verifyRadonRetrieval(
            4, // resultDataType
            0, // resultMaxVariableSize,
            [ // sources
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
              uniswapToken1PriceHash,
            ],
            [
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
              ["0xc2a856c3aff2110c1171b8f942256d40e980c726"], // pair id
            ],
            stdev15ReducerHash, // aggregator
            stdev25ReducerHash, // tally
          )
          assert(tx.logs.length === 1)
          expectEvent(
            tx.receipt,
            "NewRadonRetrievalHash"
          )
          heavyRetrievalHash = tx.logs[0].args.hash
          heavyRetrievalBytecode = tx.logs[0].args.bytecode
        })
      })
    })

    context("verifyRadonSLA(..)", async () => {
      it("emits event when verifying new radon sla", async () => {
        const tx = await bytecodes.verifyRadonSLA([
          10 ** 6,
          10,
          10 ** 6,
          51,
          5 * 10 ** 9,
        ])
        expectEvent(
          tx.receipt,
          "NewRadonSLAHash"
        )
        slaHash = tx.logs[0].args.hash
        slaBytecode = tx.logs[0].args.bytecode
      })
      it("emits no event when verifying an already verified radon sla", async () => {
        const tx = await bytecodes.verifyRadonSLA([
          10 ** 6,
          10,
          10 ** 6,
          51,
          5 * 10 ** 9,
        ])
        assert.equal(
          tx.logs.length,
          0,
          "some unexpected event was emitted"
        )
      })
      it("generates proper hash upon offchain call", async () => {
        const hash = await bytecodes.verifyRadonSLA.call([
          10 ** 6,
          10,
          10 ** 6,
          51,
          5 * 10 ** 9,
        ])
        assert.equal(hash, slaHash)
      })
      it("reverts custom error if verifying radon sla with no reward", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonSLA([
            0,
            10,
            10 ** 6,
            51,
            5 * 10 ** 9,
          ]),
          "RadonSlaNoReward"
        )
      })
      it("reverts custom error if verifying radon sla with no witnesses", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonSLA([
            10 ** 6,
            0,
            10 ** 6,
            51,
            5 * 10 ** 9,
          ]),
          "RadonSlaNoWitnesses"
        )
      })
      it("reverts custom error if verifying radon sla with too many witnesses", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonSLA([
            10 ** 6,
            500,
            10 ** 6,
            51,
            5 * 10 ** 9,
          ]),
          "RadonSlaTooManyWitnesses"
        )
      })
      it("reverts custom error if verifying radon sla with quorum out of range", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonSLA([
            10 ** 6,
            10,
            10 ** 6,
            50,
            5 * 10 ** 9,
          ]),
          "RadonSlaConsensusOutOfRange"
        )
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonSLA([
            10 ** 6,
            10,
            10 ** 6,
            100,
            5 * 10 ** 9,
          ]),
          "RadonSlaConsensusOutOfRange"
        )
      })
      it("reverts custom error if verifying radon sla with too low collateral", async () => {
        await expectRevertCustomError(
          WitnetV2,
          bytecodes.verifyRadonSLA([
            10 ** 6,
            10,
            10 ** 6,
            51,
            10 ** 6,
          ]),
          "RadonSlaLowCollateral"
        )
      })
    })

    context("bytecodeOf(..)", async () => {
      context("radon retrievals", async () => {
        it("reverts if trying to get bytecode from unknown radon retrieval", async () => {
          await expectRevertCustomError(
            WitnetBytecodes,
            bytecodes.bytecodeOf("0x0"),
            "UnknownRadonRetrieval"
          )
        })
        it("works if trying to get bytecode onchain from known radon retrieval", async () => {
          await bytecodes.bytecodeOf(btcUsdPriceFeedHash)
        })
        it("returns expected bytecode if getting it offchain from known radon retrieval", async () => {
          const bytecode = await bytecodes.bytecodeOf(btcUsdPriceFeedHash)
          assert.equal(bytecode, btcUsdPriceFeedBytecode)
        })
      })
      context("radon slas", async () => {
        it("reverts if trying to get bytecode from unknown radon sla", async () => {
          await expectRevertCustomError(
            WitnetBytecodes,
            bytecodes.bytecodeOf(btcUsdPriceFeedHash, "0x0"),
            "UnknownRadonSLA"
          )
        })
        it("works if trying to get bytecode onchain from known radon retrieval and sla", async () => {
          await bytecodes.bytecodeOf(btcUsdPriceFeedHash, slaHash)
        })
        it("returns expected bytecode if getting it offchain from known radon retrieval and sla", async () => {
          const bytecode = await bytecodes.bytecodeOf.call(heavyRetrievalHash, slaHash)
          assert.equal(
            heavyRetrievalBytecode + slaBytecode.slice(2),
            bytecode
          )
        })
      })
    })

    context("hashOf(..)", async () => {
      it("hashing unknown radon retrieval doesn't revert", async () => {
        await bytecodes.hashOf("0x", slaHash)
      })
      it("hashing unknown radon sla doesn't revert", async () => {
        await bytecodes.hashOf(btcUsdPriceFeedHash, "0x0")
      })
      it("hashing of known radon retrieval and sla works", async () => {
        await bytecodes.hashOf(btcUsdPriceFeedHash, slaHash)
      })
    })

    context("hashWeightRewardOf(..)", async () => {
      it("hashing unknown radon retrieval reverts", async () => {
        await expectRevertCustomError(
          WitnetBytecodes,
          bytecodes.hashWeightWitsOf("0x0", slaHash),
          "UnknownRadonRetrieval"
        )
      })
      it("hashing unknown radon sla reverts", async () => {
        await expectRevertCustomError(
          WitnetBytecodes,
          bytecodes.hashWeightWitsOf(btcUsdPriceFeedHash, "0x0"),
          "UnknownRadonSLA"
        )
      })
      it("hashing of known radon retrieval and sla works", async () => {
        await bytecodes.hashWeightWitsOf(
          heavyRetrievalHash, slaHash
        )
      })
    })
  })
})
