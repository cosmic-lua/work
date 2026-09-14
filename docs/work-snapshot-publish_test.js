"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const child = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const vm = require("node:vm");

test("Work bridge reads large Unicode protocol JSON without browser globals", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "snapshot-work-example."));
  const binary = path.join(root, "protocol-fixture");
  const payload = "😀λ".repeat(9000);
  fs.writeFileSync(binary, "#!/bin/sh\nnode -e " +
    JSON.stringify("process.stdout.write(JSON.stringify({payload:" +
      JSON.stringify(payload) + "}))") + "\n", {mode: 0o755});
  const context = {
    ALL_TOOLS: [],
    tools: {
      exec_command: async (args) => {
        const result = child.spawnSync("/bin/sh", ["-c", args.cmd],
          {cwd: args.workdir, encoding: "utf8", maxBuffer: 64 * 1024 * 1024});
        return {exit_code: result.status, output: (result.stdout || "") + (result.stderr || "")};
      },
      write_stdin: async () => { throw new Error("unexpected session"); },
    },
    gitboardSnapshotPublisher: {
      shellQuote: (value) => "'" + String(value).replace(/'/g, "'\\''") + "'",
      publish: async (callbacks) => callbacks.cli("trees", {}),
    },
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, "work-snapshot-publish.js"), "utf8"),
    context);
  const result = await context.runGitboardSnapshot({root, binary,
    commit: "1".repeat(40), remote: "origin"});
  assert.equal(result.payload, payload);
  fs.rmSync(root, {recursive: true, force: true});
});
