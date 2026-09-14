(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.gitboardSnapshotPublisher = api;
  return api;
})(typeof globalThis === "object" ? globalThis : this, function () {
  "use strict";

  const SHA = /^[0-9a-f]{40}$/;

  function fail(message) {
    throw new Error("snapshot publication: " + message);
  }

  function parseJsonText(text, label) {
    const value = String(text == null ? "" : text).trim();
    if (!value) fail(label + " returned no JSON");
    try { return JSON.parse(value); }
    catch (_error) { fail(label + " returned malformed JSON"); }
  }

  function cliValue(result, label) {
    if (result == null) fail(label + " returned no result");
    if (typeof result === "string") return parseJsonText(result, label);
    if (typeof result !== "object") fail(label + " returned an invalid result");
    if (result.isError) fail(label + " reported an error");
    if (Object.prototype.hasOwnProperty.call(result, "exit_code")) {
      if (result.exit_code !== 0) fail(label + " exited " + result.exit_code);
      return parseJsonText(result.output, label);
    }
    return result;
  }

  function toolValue(result, label) {
    if (result == null || typeof result !== "object")
      fail(label + " returned an invalid tool response");
    if (result.isError) fail(label + " reported an error");
    if (result.structuredContent && typeof result.structuredContent === "object")
      return result.structuredContent;
    if (Array.isArray(result.content)) {
      const texts = result.content.filter((part) => part && part.type === "text" &&
        typeof part.text === "string");
      for (const part of texts) {
        try {
          const parsed = JSON.parse(part.text);
          if (parsed && typeof parsed === "object") return parsed;
        } catch (_error) { /* A plain success message is valid for update_ref. */ }
      }
    }
    return result;
  }

  function shaOf(value, label) {
    const candidates = [value && value.sha, value && value.object && value.object.sha,
      value && value.tree && value.tree.sha, value && value.commit && value.commit.sha,
      value && value.data && value.data.sha];
    const sha = candidates.find((candidate) => typeof candidate === "string" && SHA.test(candidate));
    if (!sha) fail(label + " returned no full commit/tree SHA");
    return sha;
  }

  function treeArguments(value, results) {
    const copy = Object.assign({}, value);
    if (typeof copy.base_tree_sha === "string" && copy.base_tree_sha[0] === "$") {
      const match = copy.base_tree_sha.match(/^\$([A-Za-z0-9_]+)\.sha$/);
      if (!match || !results[match[1]]) fail("unknown symbolic SHA " + copy.base_tree_sha);
      copy.base_tree_sha = results[match[1]];
    }
    return copy;
  }

  function checkBegin(value) {
    if (!value || typeof value !== "object" || !SHA.test(value.commit || "") ||
      !SHA.test(value.parent || "") || !SHA.test(value.tree || "") ||
      typeof value.repository !== "string" || typeof value.branch !== "string" ||
      typeof value.remote !== "string" ||
      !["prepared", "candidate", "updating", "conflict", "uncertain"].includes(value.status))
      fail("begin returned an invalid protocol record");
    if (["candidate", "updating"].includes(value.status) &&
      !SHA.test(value.candidate || ""))
      fail("begin returned no saved remote candidate");
    return value;
  }

  function outcome(begin, value) {
    return Object.assign({}, value, {commit: begin.commit,
      changed: Array.isArray(begin.changed) ? begin.changed : [],
      new_issues: Array.isArray(begin.new_issues) ? begin.new_issues : [],
      existing_issues: Array.isArray(begin.existing_issues) ? begin.existing_issues : []});
  }

  function callOf(value, tool) {
    if (!value || value.tool !== tool || !value.arguments ||
      typeof value.arguments !== "object") fail("protocol returned an invalid " + tool + " call");
    return value;
  }

  async function invokeUpdate(options, begin, update, originalCandidate) {
    callOf(update, "github_update_ref");
    if (update.arguments.repository_full_name !== begin.repository ||
      update.arguments.branch_name !== begin.branch || update.arguments.force !== false ||
      update.arguments.sha !== originalCandidate) fail("update call differs from frozen destination");
    try { toolValue(await options.invoke(update.tool, update.arguments), update.tool); }
    catch (error) {
      let after;
      try { after = await reconcile(options, begin); }
      catch (fetchError) { return outcome(begin, {status: "uncertain",
        candidate: originalCandidate, reason: String(error.message || error) +
        "; reconciliation failed: " + String(fetchError.message || fetchError)}); }
      if (after.outcome.status === "confirmed" || after.outcome.status === "conflict")
        return outcome(begin, after.outcome);
      return outcome(begin, {status: "uncertain", candidate: originalCandidate,
        reason: String(error.message || error) + "; " + (after.outcome.reason || "not visible")});
    }
    try {
      const after = await reconcile(options, begin);
      return outcome(begin, after.outcome);
    } catch (error) {
      return outcome(begin, {status: "uncertain", candidate: originalCandidate,
        reason: "update acknowledged but reconciliation failed: " +
        String(error.message || error)});
    }
  }

  async function reconcile(options, begin) {
    const head = await options.fetch({repository: begin.repository,
      branch: begin.branch, remote: begin.remote});
    if (!SHA.test(head || "")) fail("fetch returned no full canonical head SHA");
    const outcome = cliValue(await options.cli("reconcile", {head}), "reconcile");
    if (!outcome || !["confirmed", "conflict", "uncertain"].includes(outcome.status))
      fail("reconcile returned an invalid outcome");
    return {head, outcome};
  }

  async function publish(options) {
    if (!options || typeof options.cli !== "function" ||
      typeof options.fetch !== "function" || typeof options.invoke !== "function")
      fail("cli, fetch, and invoke callbacks are required");
    const begin = checkBegin(cliValue(await options.cli("begin", {}), "begin"));
    if (options.commit && options.commit !== begin.commit) fail("begin returned a different commit");
    if (begin.status === "conflict" || begin.status === "uncertain")
      return outcome(begin, {status: begin.status, candidate: begin.candidate || "",
        reason: begin.reason || "publication could not begin"});

    if (begin.status === "candidate" || begin.status === "updating") {
      let observed;
      try { observed = await reconcile(options, begin); }
      catch (error) { return outcome(begin, {status: "uncertain",
        candidate: begin.candidate, reason: "reconciliation failed: " +
        String(error.message || error)}); }
      if (observed.outcome.status === "confirmed") return outcome(begin, observed.outcome);
      if (observed.outcome.status === "conflict")
        return outcome(begin, observed.outcome);
      if (observed.head !== begin.parent) return outcome(begin, observed.outcome);
      let update;
      try { update = cliValue(await options.cli("update", {head: observed.head}), "update"); }
      catch (error) { return outcome(begin, {status: "conflict", candidate:
        observed.outcome.candidate || "", reason: String(error.message || error)}); }
      return invokeUpdate(options, begin, update,
        observed.outcome.candidate || update.arguments.sha);
    }

    const treeBatch = cliValue(await options.cli("trees", {}), "trees");
    if (!treeBatch || !Array.isArray(treeBatch.calls) || treeBatch.calls.length === 0)
      fail("trees returned no calls");
    const results = {};
    for (const call of treeBatch.calls) {
      if (!call || call.tool !== "github_create_tree" || typeof call.id !== "string")
        fail("trees returned an invalid call");
      const value = toolValue(await options.invoke(call.tool,
        treeArguments(call.arguments, results)), call.tool);
      results[call.id] = shaOf(value, call.tool);
    }
    const returnedTree = results[treeBatch.calls[treeBatch.calls.length - 1].id];
    const commitCall = cliValue(await options.cli("commit",
      {returned_tree: returnedTree}), "commit");
    if (returnedTree !== begin.tree) fail("connector returned a different snapshot tree");
    callOf(commitCall, "github_create_commit");
    const commitResult = toolValue(await options.invoke(commitCall.tool,
      commitCall.arguments), commitCall.tool);
    const candidate = shaOf(commitResult, commitCall.tool);
    cliValue(await options.cli("candidate", {candidate}), "candidate");

    let observed;
    try { observed = await reconcile(options, begin); }
    catch (error) { return outcome(begin, {status: "uncertain", candidate,
      reason: "candidate saved but reconciliation failed: " +
      String(error.message || error)}); }
    if (observed.outcome.status === "confirmed") return outcome(begin, observed.outcome);
    if (observed.outcome.status === "conflict")
      return outcome(begin, observed.outcome);
    if (observed.head !== begin.parent) return outcome(begin, observed.outcome);
    let update;
    try { update = cliValue(await options.cli("update", {head: observed.head}), "update"); }
    catch (error) { return outcome(begin, {status: "conflict", candidate,
      reason: String(error.message || error)}); }
    return invokeUpdate(options, begin, update, candidate);
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
  }

  return {publish, shellQuote, cliValue, toolValue};
});
