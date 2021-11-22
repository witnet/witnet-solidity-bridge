const WitnetRequestRandomness = artifacts.require("WitnetRequestRandomness")
const truffleAssert = require("truffle-assertions")
const { assert } = require("chai")

contract("WitnetRequest implementations", accounts => {
  const master = accounts[0]
  const deputy = accounts[1]
  const stranger = accounts[2]
  const cloner = accounts[3]
  const cloneCloner = accounts[4]
  describe("WitnetRequestRandomness", async () => {
    let rng, clone, cloneClone
    before(async () => {
      rng = await WitnetRequestRandomness.new({ from: master })
    })
    describe("Proxiable", async () => {
      it("proxiableUUID() concurs with expected value", async () => {
        const uuid = await rng.proxiableUUID()
        // console.log(uuid)
        assert.equal(
          uuid,
          "0x851d0a92a3ad30295bef33afc69d6874779826b7789386b336e22621365ed2c2"
        )
      })
    })
    describe("Ownable", async () => {
      it("owner() concurs with expected value", async () => {
        const owner = await rng.owner.call()
        // console.log(owner)
        assert.equal(owner, master)
      })
      it("stranger cannot transfer ownership", async () => {
        await truffleAssert.reverts(
          rng.transferOwnership(stranger, { from: stranger }),
          "not the owner"
        )
      })
      it("owner can transfer ownership", async () => {
        await rng.transferOwnership(deputy, { from: master })
        assert(await rng.owner.call(), deputy)
      })
      it("ownership cannot be transferred to zero address", async () => {
        await truffleAssert.reverts(
          rng.transferOwnership("0x0000000000000000000000000000000000000000", { from: deputy }),
          "zero address"
        )
      })
      it("ownership can be renounced", async () => {
        await rng.renounceOwnership({ from: deputy })
        assert(
          await rng.owner.call(),
          "0x0000000000000000000000000000000000000000"
        )
      })
      it("ownership cannot be recovered", async () => {
        await truffleAssert.reverts(
          rng.transferOwnership(deputy, { from: deputy }),
          "not the owner"
        )
        await truffleAssert.reverts(
          rng.transferOwnership(deputy, { from: master }),
          "not the owner"
        )
      })
    })
    describe("Clonable", async () => {
      before(async () => {
        const tx = await rng.clone({ from: cloner })
        const args = getEventArgs(tx.logs, "Cloned")
        clone = await WitnetRequestRandomness.at(args.clone)
      })
      it("master copy is no clone", async () => {
        assert.equal(false, await rng.cloned.call())
      })
      it("first level clones correctly refer to master copy", async () => {
        assert.equal(rng.address, await clone.self.call())
      })
      it("clones belong to the cloner, not the master's owner", async () => {
        const owner = await clone.owner()
        // console.log(owner)
        assert.equal(owner, cloner)
      })
      it("clones are fully initialized after cloning", async () => {
        const bytecode = await clone.bytecode.call()
        // console.log(bytecode)
        assert(bytecode.length > 0)
      })
      it("clones recognize themselves as such", async () => {
        assert.equal(true, await clone.cloned.call())
      })
      it("clones can be cloned", async () => {
        const tx = await clone.clone({ from: cloneCloner })
        const args = getEventArgs(tx.logs, "Cloned")
        assert.notEqual(args.clone, clone.address)
        cloneClone = await WitnetRequestRandomness.at(args.clone)
      })
      it("clone of clone keeps referring to master copy", async () => {
        assert.equal(rng.address, await cloneClone.self.call())
      })
    })
    describe("Initializable", async () => {
      describe("master copy", async () => {
        it("cannot be re-initialized", async () => {
          await truffleAssert.reverts(
            rng.initialize("0x80", { from: master }),
            "already initialized"
          )
          await truffleAssert.reverts(
            rng.initialize("0x80", { from: deputy }),
            "already initialized"
          )
          await truffleAssert.reverts(
            rng.initialize("0x80", { from: stranger }),
            "already initialized"
          )
        })
      })
      describe("clone copy", async () => {
        it("cannot be re-initialized by owner", async () => {
          await truffleAssert.reverts(
            clone.initialize("0x80", { from: cloner }),
            "already initialized"
          )
        })
        it("cannot be re-initialized by anybody else", async () => {
          await truffleAssert.reverts(
            clone.initialize("0x80", { from: stranger }),
            "already initialized"
          )
        })
      })
      describe("clone of clone copy", async () => {
        before(async () => {
          cloneClone.transferOwnership(deputy, { from: cloneCloner })
        })
        it("cannot be re-initialized by owner", async () => {
          await truffleAssert.reverts(
            cloneClone.initialize("0x80", { from: deputy }),
            "already initialized"
          )
        })
        it("cannot re-initialized by anybody else", async () => {
          await truffleAssert.reverts(
            cloneClone.initialize("0x80", { from: cloneCloner }),
            "already initialized"
          )
          await truffleAssert.reverts(
            cloneClone.initialize("0x80", { from: cloner }),
            "already initialized"
          )
          await truffleAssert.reverts(
            clone.initialize("0x80", { from: stranger }),
            "already initialized"
          )
        })
      })
    })
    describe("IWitnetRequest", async () => {
      before(async () => {
        rng = await WitnetRequestRandomness.new({ from: master })
      })
      it("bytecode() concurs with expected default value", async () => {
        const bytecode = await rng.bytecode.call()
        // console.log(bytecode)
        assert.equal(
          "0x0a0f120508021a01801a0210022202100b10a0c21e18022090a10f2833308094ebdc03",
          bytecode
        )
      })
      it("hash() concurs with expected default value", async () => {
        const hash = await rng.hash.call()
        // console.log(hash)
        assert.equal(
          "0x0dd4be45fe46949658d276b2a9f8550f72c3352692cdcd718d16b87924fbc113",
          hash
        )
      })
    })
    describe("WitnetRequestMalleableBase", async () => {
      before(async () => {
        rng = await WitnetRequestRandomness.new({ from: master })
      })
      describe("master copy", async () => {
        it("witnessingParams() concurs with expected default values", async () => {
          const params = await rng.witnessingParams.call()
          // console.log(params)
          assert.equal(2, params.numWitnesses)
          assert.equal(51, params.minWitnessingConsensus)
          assert.equal(1000000000, params.witnessingCollateral)
          assert.equal(500000, params.witnessingReward)
          assert.equal(250000, params.witnessingUnitaryFee)
        })
        describe("setWitnessingCollateral(.)", async () => {
          it("stranger cannot change the witnessing collateral", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingCollateral(
                10 ** 9,
                { from: stranger }
              ),
              "not the owner"
            )
          })
          it("owner can change witnessing collateral to an acceptable value", async () => {
            await rng.setWitnessingCollateral(
              "1000000000000000000",
              { from: master }
            )
            assert.equal(
              (await rng.witnessingParams.call()).witnessingCollateral,
              "1000000000000000000"
            )
          })
          it("the witnessing collateral cannot be set to less than 1 WIT", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingCollateral(
                10 ** 9 - 1,
                { from: master }
              ),
              "collateral below"
            )
          })
          it("bytecode() concurs with last set parameters", async () => {
            const bytecode = await rng.bytecode.call()
            // console.log(bytecode)
            assert.equal(
              "0x0a0f120508021a01801a0210022202100b10a0c21e18022090a10f283330808090bbbad6adf00d",
              bytecode
            )
          })
        })
        describe("setWitnessingFees(..)", async () => {
          it("stranger cannot change the witnessing fees", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingFees(
                5 * 10 ** 5,
                25 * 10 ** 4,
                { from: stranger }
              ),
              "not the owner"
            )
          })
          it("owner can change witnessing fees to acceptable values", async () => {
            await rng.setWitnessingFees(
              10 ** 6,
              50 * 10 ** 4,
              { from: master }
            )
            const params = await rng.witnessingParams.call()
            assert.equal(params.witnessingReward, "1000000")
            assert.equal(params.witnessingUnitaryFee, "500000")
          })
          it("the witnessing reward cannot be set to zero", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingFees(0, 50 * 10 ** 4, { from: master }),
              "no reward"
            )
          })
          it("bytecode() concurs with last set parameters", async () => {
            const bytecode = await rng.bytecode.call()
            // console.log(bytecode)
            assert.equal(
              "0x0a0f120508021a01801a0210022202100b10c0843d180220a0c21e283330808090bbbad6adf00d",
              bytecode
            )
          })
        })
        describe("setWitnessingQuorum(..)", async () => {
          it("stranger cannot change the witnessing quorum", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingQuorum(2, 51, { from: stranger }),
              "not the owner"
            )
          })
          it("owner can change witnessing to quorum to acceptable values", async () => {
            await rng.setWitnessingQuorum(7, 67, { from: master })
            const params = await rng.witnessingParams.call()
            assert.equal(7, params.numWitnesses)
            assert.equal(67, params.minWitnessingConsensus)
          })
          it("number of witnesses cannot be set to zero", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingQuorum(0, 67, { from: master }),
              "witnesses out of range"
            )
          })
          it("number of witnesses cannot be set to more than 127", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingQuorum(128, 67, { from: master }),
              "witnesses out of range"
            )
          })
          it("witnessing quorum cannot be set to less than 51", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingQuorum(7, 50, { from: master }),
              "consensus out of range"
            )
          })
          it("witnessing quorum cannot be set to more than 100", async () => {
            await truffleAssert.reverts(
              rng.setWitnessingQuorum(7, 100, { from: master }),
              "consensus out of range"
            )
          })
          it("bytecode() concurs with last set parameters", async () => {
            const bytecode = await rng.bytecode.call()
            // console.log(bytecode)
            assert.equal(
              "0x0a0f120508021a01801a0210022202100b10c0843d180720a0c21e284330808090bbbad6adf00d",
              bytecode
            )
          })
        })
      })
      describe("clone copy", async () => {
        before(async () => {
          const tx = await rng.clone({ from: cloner })
          const args = getEventArgs(tx.logs, "Cloned")
          clone = await WitnetRequestRandomness.at(args.clone)
          // console.log(await rng.witnessingParams.call())
        })
        it("witnessingParams() concurs with expected default values", async () => {
          const params = await clone.witnessingParams.call()
          // console.log(params)
          assert.equal(2, params.numWitnesses)
          assert.equal(51, params.minWitnessingConsensus)
          assert.equal(1000000000, params.witnessingCollateral)
          assert.equal(500000, params.witnessingReward)
          assert.equal(250000, params.witnessingUnitaryFee)
        })
        describe("setWitnessingCollateral(.)", async () => {
          it("stranger cannot change the witnessing collateral", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingCollateral(
                10 ** 9,
                { from: stranger }
              ),
              "not the owner"
            )
          })
          it("owner can change witnessing collateral to an acceptable value", async () => {
            await clone.setWitnessingCollateral(
              "1000000000000000000",
              { from: cloner }
            )
            assert.equal(
              (await clone.witnessingParams.call()).witnessingCollateral,
              "1000000000000000000"
            )
          })
          it("the witnessing collateral cannot be set to less than 1 WIT", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingCollateral(
                10 ** 9 - 1,
                { from: cloner }
              ),
              "collateral below"
            )
          })
          it("bytecode() concurs with last set parameters", async () => {
            const bytecode = await clone.bytecode.call()
            // console.log(bytecode)
            assert.equal(
              "0x0a0f120508021a01801a0210022202100b10a0c21e18022090a10f283330808090bbbad6adf00d",
              bytecode
            )
          })
        })
        describe("setWitnessingFees(..)", async () => {
          it("stranger cannot change the witnessing fees", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingFees(
                5 * 10 ** 5,
                25 * 10 ** 4,
                { from: stranger }
              ),
              "not the owner"
            )
          })
          it("owner can change witnessing fees to acceptable values", async () => {
            await clone.setWitnessingFees(
              10 ** 9,
              50 * 10 ** 4,
              { from: cloner }
            )
            const params = await clone.witnessingParams.call()
            assert.equal(params.witnessingReward, "1000000000")
            assert.equal(params.witnessingUnitaryFee, "500000")
          })
          it("the witnessing reward cannot be set to zero", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingFees(0, 50 * 10 ** 4, { from: cloner }),
              "no reward"
            )
          })
          it("the witnessing reward cannot be set to zero", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingFees(0, 50 * 10 ** 4, { from: cloner }),
              "no reward"
            )
          })
          it("bytecode() concurs with last set parameters", async () => {
            const bytecode = await clone.bytecode.call()
            // console.log(bytecode)
            assert.equal(
              "0x0a0f120508021a01801a0210022202100b108094ebdc03180220a0c21e283330808090bbbad6adf00d",
              bytecode
            )
          })
        })
        describe("setWitnessingQuorum(..)", async () => {
          it("stranger cannot change the witnessing quorum", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingQuorum(2, 51, { from: stranger }),
              "not the owner"
            )
          })
          it("owner can change witnessing to quorum to acceptable values", async () => {
            await clone.setWitnessingQuorum(7, 67, { from: cloner })
            const params = await clone.witnessingParams.call()
            assert.equal(7, params.numWitnesses)
            assert.equal(67, params.minWitnessingConsensus)
          })
          it("number of witnesses cannot be set to zero", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingQuorum(0, 67, { from: cloner }),
              "witnesses out of range"
            )
          })
          it("number of witnesses cannot be set to more than 127", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingQuorum(128, 67, { from: cloner }),
              "witnesses out of range"
            )
          })
          it("witnessing quorum cannot be set to less than 51", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingQuorum(7, 50, { from: cloner }),
              "consensus out of range"
            )
          })
          it("witnessing quorum cannot be set to more than 100", async () => {
            await truffleAssert.reverts(
              clone.setWitnessingQuorum(7, 100, { from: cloner }),
              "consensus out of range"
            )
          })
          it("bytecode() concurs with last set parameters", async () => {
            const bytecode = await clone.bytecode.call()
            // console.log(bytecode)
            assert.equal(
              "0x0a0f120508021a01801a0210022202100b108094ebdc03180720a0c21e284330808090bbbad6adf00d",
              bytecode
            )
          })
        })
      })
    })
  })
})

function getEventArgs (logs, event) {
  if (logs && logs.length > 0) {
    for (let j = 0; j < logs.length; j++) {
      if (logs[j].event === event) {
        return logs[j].args
      }
    }
  }
}
