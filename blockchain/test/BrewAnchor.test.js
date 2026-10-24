const assert = require("node:assert/strict");
const { ethers } = require("hardhat");

describe("BrewAnchor", function () {
  const userKey = ethers.keccak256(ethers.toUtf8Bytes("test-user-id"));
  const firstHash = `0x${"11".repeat(32)}`;
  const secondHash = `0x${"22".repeat(32)}`;
  let anchor;
  let owner;
  let nextOwner;

  beforeEach(async function () {
    [owner, nextOwner] = await ethers.getSigners();
    anchor = await ethers.deployContract("BrewAnchor");
    await anchor.waitForDeployment();
  });

  async function rejectsWith(transaction, errorName) {
    await assert.rejects(transaction, (error) =>
      error.message.includes(`reverted with custom error '${errorName}()`)
    );
  }

  it("anchors the first head and emits its stored values", async function () {
    const tx = await anchor.anchor(userKey, firstHash, 1);
    const receipt = await tx.wait();
    const block = await ethers.provider.getBlock(receipt.blockNumber);
    const saved = await anchor.latest(userKey);
    const event = receipt.logs.map((log) => anchor.interface.parseLog(log)).find((log) => log?.name === "Anchored");

    assert.equal(saved.headHash, firstHash);
    assert.equal(saved.seq, 1n);
    assert.equal(saved.anchoredAt, BigInt(block.timestamp));
    assert.equal(event.args.userKey, userKey);
    assert.equal(event.args.headHash, firstHash);
    assert.equal(event.args.seq, 1n);
    assert.equal(event.args.anchoredAt, saved.anchoredAt);
    console.log(`  Gas anchor pertama: ${receipt.gasUsed} gas`);
  });

  it("accepts a higher sequence and rejects equal or lower sequences", async function () {
    await anchor.anchor(userKey, firstHash, 2);
    const tx = await anchor.anchor(userKey, secondHash, 3);
    console.log(`  Gas anchor lanjutan: ${(await tx.wait()).gasUsed} gas`);
    assert.equal((await anchor.latest(userKey)).headHash, secondHash);
    await rejectsWith(anchor.anchor(userKey, firstHash, 3), "SequenceNotIncreasing");
    await rejectsWith(anchor.anchor(userKey, firstHash, 1), "SequenceNotIncreasing");
  });

  it("rejects callers other than the owner", async function () {
    await rejectsWith(anchor.connect(nextOwner).anchor(userKey, firstHash, 1), "NotOwner");
  });

  it("rejects a zero head hash", async function () {
    await rejectsWith(anchor.anchor(userKey, ethers.ZeroHash, 1), "InvalidHeadHash");
  });

  it("transfers ownership and rejects the former owner", async function () {
    await rejectsWith(anchor.transferOwnership(ethers.ZeroAddress), "InvalidOwner");
    await anchor.transferOwnership(nextOwner.address);
    assert.equal(await anchor.owner(), nextOwner.address);
    await rejectsWith(anchor.anchor(userKey, firstHash, 1), "NotOwner");
    await anchor.connect(nextOwner).anchor(userKey, firstHash, 1);
    assert.equal((await anchor.latest(userKey)).seq, 1n);
  });
});
