"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const runner = require("./snapshot_work_runner.js");

const parent = "1".repeat(40);
const tree = "2".repeat(40);
const candidate = "3".repeat(40);
const foreign = "4".repeat(40);

function fixture(overrides = {}) {
  const state = {
    phase: overrides.phase || "prepared",
    head: overrides.head || parent,
    expired: Boolean(overrides.expired),
    log: [], fetchFailures: overrides.fetchFailures || 0,
    failFetchAt: overrides.failFetchAt || 0, fetchCount: 0,
    commitFailures: overrides.commitFailures || 0,
    updateLosses: overrides.updateLosses || 0,
    updateFailures: overrides.updateFailures || 0,
    unknownHead: Boolean(overrides.unknownHead),
    treeResult: overrides.treeResult || tree,
  };
  const begin = {status: state.phase, candidate: state.phase === "prepared" ? "" : candidate,
    commit: "5".repeat(40), parent, tree,
    repository: "cosmic-lua/work", branch: "state", remote: "origin",
    publish_by: 0, changed: [], new_issues: [], existing_issues: []};

  async function cli(action, values) {
    state.log.push("cli:" + action);
    if (action === "begin") return {...begin, status: state.phase,
      candidate: state.phase === "prepared" ? "" : candidate};
    if (action === "trees") return {calls: [{id: "tree_1", tool: "github_create_tree",
      arguments: {repository_full_name: begin.repository, base_tree_sha: parent,
        tree_elements: [{path: "spec", mode: "100644", type: "blob",
          content: overrides.content || "$tree_1.sha"}]}}]};
    if (action === "commit") {
      if (values.returned_tree !== tree) throw new Error("different snapshot tree");
      return {id: "commit", tool: "github_create_commit", arguments: {
        repository_full_name: begin.repository, parent_sha: parent,
        tree_sha: tree, message: "snapshot"}};
    }
    if (action === "candidate") {
      assert.equal(values.candidate, candidate);
      state.phase = "candidate";
      return {status: "candidate", candidate};
    }
    if (action === "reconcile") {
      if (values.head === candidate) return {status: "confirmed", candidate, reason: ""};
      if (values.head === parent) return {status: "uncertain", candidate,
        reason: "publication is not yet visible"};
      if (state.unknownHead) return {status: "uncertain", candidate,
        reason: "fetched history is incomplete"};
      return {status: "conflict", candidate, reason: "canonical head advanced"};
    }
    if (action === "update") {
      if (state.expired) throw new Error("prepared claim expired before publication");
      assert.equal(values.head, parent);
      state.phase = "updating";
      return {id: "publish", tool: "github_update_ref", arguments: {
        repository_full_name: begin.repository, branch_name: begin.branch,
        sha: candidate, force: false}};
    }
    throw new Error("unknown action " + action);
  }

  async function fetch() {
    state.log.push("fetch");
    state.fetchCount += 1;
    if (state.fetchCount === state.failFetchAt) throw new Error("fetch failed");
    if (state.fetchFailures > 0) {
      state.fetchFailures -= 1;
      throw new Error("fetch failed");
    }
    return state.head;
  }

  async function invoke(tool, args) {
    state.log.push("tool:" + tool);
    if (tool === "github_create_tree")
      return {structuredContent: {sha: state.treeResult}};
    if (tool === "github_create_commit") {
      if (state.commitFailures > 0) {
        state.commitFailures -= 1;
        throw new Error("commit response lost");
      }
      return {content: [{type: "text", text: JSON.stringify({sha: candidate})}]};
    }
    assert.equal(tool, "github_update_ref");
    assert.equal(args.force, false);
    if (state.updateFailures > 0) {
      state.updateFailures -= 1;
      throw new Error("provider update failed");
    }
    state.head = candidate;
    if (state.updateLosses > 0) {
      state.updateLosses -= 1;
      throw new Error("update response lost");
    }
    return {content: [{type: "text", text: "updated"}]};
  }
  return {state, options: {commit: begin.commit, cli, fetch, invoke}};
}

test("small publication makes exactly three ordered connector calls", async () => {
  const f = fixture();
  const result = await runner.publish(f.options);
  assert.equal(result.status, "confirmed");
  assert.deepEqual(result.changed, []);
  assert.deepEqual(f.state.log.filter((entry) => entry.startsWith("tool:")), [
    "tool:github_create_tree", "tool:github_create_commit", "tool:github_update_ref"]);
  assert.deepEqual(f.state.log.slice(-2), ["fetch", "cli:reconcile"]);
});

test("a returned tree mismatch prevents commit and update", async () => {
  const f = fixture({treeResult: foreign});
  await assert.rejects(runner.publish(f.options), /different snapshot tree/);
  assert.deepEqual(f.state.log.filter((entry) => entry.startsWith("tool:")),
    ["tool:github_create_tree"]);
});

test("lost commit response is safe to recreate before any update", async () => {
  const f = fixture({commitFailures: 1});
  await assert.rejects(runner.publish(f.options), /commit response lost/);
  assert.equal(f.state.phase, "prepared");
  const result = await runner.publish(f.options);
  assert.equal(result.status, "confirmed");
  assert.equal(f.state.log.filter((entry) => entry === "tool:github_create_commit").length, 2);
  assert.equal(f.state.log.filter((entry) => entry === "tool:github_update_ref").length, 1);
});

test("lost update response reconciles after restart without creating objects", async () => {
  const f = fixture({updateLosses: 1, failFetchAt: 2});
  const uncertain = await runner.publish(f.options);
  assert.equal(uncertain.status, "uncertain");
  assert.match(uncertain.reason, /reconciliation failed: fetch failed/);
  assert.equal(f.state.phase, "updating");
  const before = f.state.log.length;
  const result = await runner.publish(f.options);
  assert.equal(result.status, "confirmed");
  assert.deepEqual(f.state.log.slice(before), ["cli:begin", "fetch", "cli:reconcile"]);
});

test("an uncertain updating record retries only its saved candidate", async () => {
  const f = fixture({phase: "updating"});
  const result = await runner.publish(f.options);
  assert.equal(result.status, "confirmed");
  assert.deepEqual(f.state.log.filter((entry) => entry.startsWith("tool:")),
    ["tool:github_update_ref"]);
});

test("an uncertain non-parent head never attempts an update", async () => {
  const f = fixture({phase: "updating", head: foreign, unknownHead: true});
  const result = await runner.publish(f.options);
  assert.equal(result.status, "uncertain");
  assert.equal(f.state.log.some((entry) => entry.startsWith("tool:")), false);
});

test("a failed update is reconciled and remains structured uncertainty", async () => {
  const f = fixture({phase: "updating", updateFailures: 1});
  const result = await runner.publish(f.options);
  assert.equal(result.status, "uncertain");
  assert.match(result.reason, /provider update failed/);
  assert.equal(f.state.phase, "updating");
});

test("a foreign canonical head conflicts before update", async () => {
  const f = fixture({phase: "candidate", head: foreign});
  const result = await runner.publish(f.options);
  assert.equal(result.status, "conflict");
  assert.match(result.reason, /canonical head advanced/);
  assert.equal(f.state.log.some((entry) => entry.startsWith("tool:")), false);
});

test("an early begin outcome stays structured and performs no writes", async () => {
  const f = fixture({phase: "uncertain"});
  const result = await runner.publish(f.options);
  assert.equal(result.status, "uncertain");
  assert.match(result.reason, /publication could not begin/);
  assert.deepEqual(f.state.log, ["cli:begin"]);
});

test("an expired saved candidate is reconciled but cannot update", async () => {
  const f = fixture({phase: "candidate", expired: true});
  const result = await runner.publish(f.options);
  assert.equal(result.status, "conflict");
  assert.match(result.reason, /expired/);
  assert.deepEqual(f.state.log.filter((entry) => entry.startsWith("tool:")), []);
});

test("malformed and isError tool responses are refused", async () => {
  const malformed = fixture();
  malformed.options.invoke = async (tool) => tool === "github_create_tree" ? {} : {sha: candidate};
  await assert.rejects(runner.publish(malformed.options), /returned no full commit\/tree SHA/);
  const rejected = fixture();
  rejected.options.invoke = async () => ({isError: true, content: []});
  await assert.rejects(runner.publish(rejected.options), /reported an error/);
});

test("shell quoting preserves spaces, quotes, and substitutions literally", () => {
  assert.equal(runner.shellQuote("a b'$(x)"), "'a b'\\''$(x)'");
});

test("large protocol payloads and dollar-prefixed content remain literal", async () => {
  const content = "$" + "x".repeat(400000);
  const f = fixture({content});
  const baseInvoke = f.options.invoke;
  f.options.invoke = async (tool, args) => {
    if (tool === "github_create_tree") assert.equal(args.tree_elements[0].content, content);
    return baseInvoke(tool, args);
  };
  assert.equal((await runner.publish(f.options)).status, "confirmed");
});
