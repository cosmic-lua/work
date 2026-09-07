#!/usr/bin/env cosmic
-- The predicate `_work.gh` and `_work.brief` both call: whether one
-- review counts as a bounce round. The marker-precision cases live
-- here, at the predicate's own home; `_work/gh_test.tl` keeps its two
-- existing cases (`matches_a_marked_own_pr_comment`,
-- `ignores_a_marker_below_the_first_line`) unchanged — they still
-- prove `gh.latest_request_changes` calls this predicate correctly,
-- not the predicate itself.

local bounce = require("_work.bounce")

local function test_is_bounce_true_for_a_formal_changes_requested()
  assert(bounce.is_bounce("CHANGES_REQUESTED", "anything at all"),
    "a formal CHANGES_REQUESTED review is always a bounce, body aside")
end

local function test_is_bounce_true_for_an_exact_own_pr_marker()
  assert(bounce.is_bounce("COMMENTED", "request-changes:\nthe finding"),
    "a COMMENTED review whose exact first line is request-changes: is a bounce")
  assert(bounce.is_bounce("COMMENTED", "reject:"),
    "a COMMENTED review whose exact first line is reject: is a bounce")
end

local function test_is_bounce_false_for_a_plain_comment()
  assert(not bounce.is_bounce("COMMENTED", "looks fine now"),
    "an ordinary COMMENTED review with no marker is never a bounce")
end

local function test_is_bounce_false_for_an_approval_or_dismissed_review()
  assert(not bounce.is_bounce("APPROVED", "request-changes:"),
    "the marker only matters on a COMMENTED review — an APPROVED one is never "
    .. "a bounce no matter what its body says")
  assert(not bounce.is_bounce("DISMISSED", "request-changes:"),
    "a DISMISSED review is never a bounce")
end

local function test_is_bounce_false_for_a_marker_on_a_later_line()
  assert(not bounce.is_bounce("COMMENTED", "lgtm\nrequest-changes:"),
    "the marker counts only on the FIRST line — a mention further down "
    .. "in the body is a plain comment")
end

local function test_is_bounce_false_for_a_marker_with_leading_space()
  assert(not bounce.is_bounce("COMMENTED", " request-changes:"),
    "the marker must be the exact first line — leading space makes it "
    .. "a plain comment, not a bounce")
end

local function test_is_bounce_false_for_a_marker_as_a_prefix()
  assert(not bounce.is_bounce("COMMENTED", "request-changes: fix the retry"),
    "the first line must be EXACTLY the marker — trailing text after it "
    .. "on the same line is a plain comment, not a bounce")
end
