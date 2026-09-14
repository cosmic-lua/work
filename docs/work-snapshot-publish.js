/*
Evaluate `_work/snapshot_work_runner.js` first, then this file inside one Work
`functions.exec` cell. Call:

  await runGitboardSnapshot({
    root: "/absolute/board/checkout",
    binary: "/absolute/newly-built/gitboard",
    commit: "40-hex-local-snapshot",
    remote: "origin"
  })

The protocol callback spools CLI JSON to a transient file and reads it in
bounded base64 chunks. This avoids treating truncated exec output as a plan.
*/
(function (root) {
  "use strict";
  const quote = root.gitboardSnapshotPublisher.shellQuote;

  async function command(args) {
    let result = await tools.exec_command(args);
    while (result && result.session_id) {
      result = await tools.write_stdin({session_id: result.session_id, chars: "",
        yield_time_ms: 30000, max_output_tokens: args.max_output_tokens || 2000});
    }
    return result;
  }

  function good(result, label) {
    if (!result || result.exit_code !== 0)
      throw new Error(label + " failed: " + String(result && result.output || "no result"));
    return String(result.output || "");
  }

  async function readJsonFile(path, rootDir) {
    const script = "const s=require('fs').readFileSync(process.argv[1],'utf8');";
    const sizeText = good(await command({cmd: ["node", "-e",
      script + "process.stdout.write(String(s.length))", path].map(quote).join(" "),
      workdir: rootDir, yield_time_ms: 30000, max_output_tokens: 1000}), "protocol size");
    const size = Number(sizeText.trim());
    if (!Number.isSafeInteger(size) || size < 1) throw new Error("protocol JSON is empty");
    let chunkSize = 8192;
    const parts = [];
    for (let offset = 0; offset < size;) {
      const count = Math.min(chunkSize, size - offset);
      const code = script + "process.stdout.write(JSON.stringify(s.slice(" + offset +
        "," + (offset + count) + ")))";
      const encoded = good(await command({cmd: ["node", "-e", code, path]
        .map(quote).join(" "), workdir: rootDir, yield_time_ms: 30000,
        max_output_tokens: 12000}), "protocol chunk read");
      try {
        const part = JSON.parse(encoded);
        if (typeof part !== "string" || part.length !== count) throw new Error("short chunk");
        parts.push(part);
        offset += count;
      } catch (_error) {
        if (chunkSize <= 512) throw new Error("protocol chunk was truncated or malformed");
        chunkSize = Math.floor(chunkSize / 2);
      }
    }
    const joined = parts.join("");
    if (joined.length !== size) throw new Error("protocol output was truncated");
    try { return JSON.parse(joined); }
    catch (_error) { throw new Error("protocol returned malformed JSON"); }
  }

  async function protocol(options, action, fields) {
    if (options.recovery) throw new Error("custom snapshot recovery paths are not supported");
    const argv = [options.binary, "publish", options.commit, "--dir", options.root,
      "--remote", options.remote, "--protocol", action];
    if (fields.returned_tree) argv.push("--returned-tree", fields.returned_tree);
    if (fields.candidate) argv.push("--candidate", fields.candidate);
    if (fields.head) argv.push("--head", fields.head);
    const wrapper = "const cp=require('child_process'),fs=require('fs'),os=require('os'),p=require('path');" +
      "const r=cp.spawnSync(process.argv[1],process.argv.slice(2),{encoding:'utf8',maxBuffer:67108864});" +
      "if(r.error||r.status!==0){process.stdout.write(JSON.stringify({ok:false,detail:String(r.error||r.stderr||r.stdout).slice(0,12000)}));}" +
      "else{try{const v=JSON.parse(r.stdout);if(Buffer.byteLength(r.stdout)<=4000)process.stdout.write(JSON.stringify({ok:true,inline:v}));" +
      "else{const d=fs.mkdtempSync(p.join(os.tmpdir(),'gitboard-snapshot.')),f=p.join(d,'protocol.json');" +
      "fs.writeFileSync(f,r.stdout);process.stdout.write(JSON.stringify({ok:true,path:f,length:r.stdout.length}));}}" +
      "catch(e){process.stdout.write(JSON.stringify({ok:false,detail:'malformed protocol JSON'}));}}";
    const ran = good(await command({cmd: ["node", "-e", wrapper].concat(argv)
      .map(quote).join(" "), workdir: options.root, yield_time_ms: 30000,
      max_output_tokens: 6000}), "gitboard protocol " + action);
    let envelope;
    try { envelope = JSON.parse(ran); }
    catch (_error) { throw new Error("protocol wrapper returned malformed JSON"); }
    if (!envelope.ok) throw new Error("gitboard protocol " + action + " failed: " + envelope.detail);
    if (Object.prototype.hasOwnProperty.call(envelope, "inline")) return envelope.inline;
    if (typeof envelope.path !== "string" || !Number.isSafeInteger(envelope.length))
      throw new Error("protocol wrapper returned an invalid large-output receipt");
    try { return await readJsonFile(envelope.path, options.root); }
    finally {
      const cleanup = "const fs=require('fs'),os=require('os'),p=require('path');" +
        "const f=p.resolve(process.argv[1]),d=p.dirname(f),t=p.resolve(os.tmpdir());" +
        "if(p.basename(f)!=='protocol.json'||p.dirname(d)!==t||!p.basename(d).startsWith('gitboard-snapshot.'))" +
        "throw new Error('refusing unexpected protocol cleanup path');" +
        "fs.unlinkSync(f);fs.rmdirSync(d);";
      good(await command({cmd: ["node", "-e", cleanup, envelope.path]
        .map(quote).join(" "), workdir: options.root, yield_time_ms: 30000,
        max_output_tokens: 1000}), "protocol cleanup");
    }
  }

  async function invoke(shortName, argumentsValue) {
    const matches = ALL_TOOLS.filter((entry) => entry.name === shortName ||
      entry.name.endsWith("__" + shortName));
    if (matches.length !== 1 || typeof tools[matches[0].name] !== "function")
      throw new Error("expected one exposed Work tool for " + shortName);
    return tools[matches[0].name](argumentsValue);
  }

  async function runGitboardSnapshot(options) {
    if (!root.gitboardSnapshotPublisher) throw new Error("evaluate snapshot_work_runner.js first");
    const callbacks = {
      commit: options.commit,
      cli: (action, fields) => protocol(options, action, fields),
      invoke,
      fetch: async (destination) => {
        const tracking = "refs/remotes/" + destination.remote;
        const argv = ["git", "fetch", "--atomic", destination.remote,
          "+refs/heads/" + destination.branch + ":" + tracking + "/state",
          "+refs/heads/board/format:" + tracking + "/board/format"];
        good(await command({cmd: argv.map(quote).join(" "), workdir: options.root,
          yield_time_ms: 30000, max_output_tokens: 2000}), "canonical fetch");
        return good(await command({cmd: ["git", "rev-parse", "--verify",
          tracking + "/state"].map(quote).join(" "), workdir: options.root,
          yield_time_ms: 30000, max_output_tokens: 1000}), "fetched head").trim();
      }
    };
    return root.gitboardSnapshotPublisher.publish(callbacks);
  }

  root.runGitboardSnapshot = runGitboardSnapshot;
})(typeof globalThis === "object" ? globalThis : this);
