#!/usr/bin/env cosmic
-- The parse that decides which repository a live merge is aimed at.
-- An item's recorded navigation URL is the only place the data model
-- holds a pull request NUMBER, and it is free-form text whoever held
-- the claim typed at handover — so what it does and does not name is
-- worth pinning exactly. Pure over a string: nothing here activates a
-- transport, reads a store, or reaches a network.
local ghland = require("_work.ghland")

--- Assert what one URL names.
--- @param url string The recorded navigation URL
--- @param repo string The owner/name expected, "" for none
--- @param number integer The request number expected, 0 for none
local function names(url: string, repo: string, number: integer)
  local got_repo, got_number = ghland.pull_of(url)
  assert(got_repo == repo,
    ("%s: repository %q, want %q"):format(url, got_repo, repo))
  assert(got_number == number,
    ("%s: number %d, want %d"):format(url, got_number, number))
end

local function test_a_pull_url_names_its_repository_and_number()
  names("https://github.com/acme/widgets/pull/7", "acme/widgets", 7)
  names("https://github.com/acme-org/widgets.js/pull/1234",
    "acme-org/widgets.js", 1234)
end

-- The host is matched whole, anchored at the start of the string.
-- Nothing that merely CONTAINS github.com names a request, which is
-- what keeps a URL typed at handover from aiming a squash `PUT` at a
-- look-alike host.
local function test_another_host_names_nothing()
  names("https://gitlab.com/acme/widgets/pull/7", "", 0)
  names("https://github.com.evil.test/acme/widgets/pull/7", "", 0)
  names("https://evil.test/https://github.com/acme/widgets/pull/7", "", 0)
  names("http://github.com/acme/widgets/pull/7", "", 0)
  names("  https://github.com/acme/widgets/pull/7", "", 0)
end

-- Everything between the host and the number is matched exactly too:
-- one owner segment, one repository segment, then `pull`. A path of
-- another shape names no request rather than guessing at one.
local function test_a_path_of_another_shape_names_nothing()
  names("https://github.com/acme/widgets/pulls/7", "", 0)
  names("https://github.com/acme/widgets/issues/7", "", 0)
  names("https://github.com/acme/sub/dir/pull/7", "", 0)
  names("https://github.com/acme/widgets", "", 0)
  names("", "", 0)
end

-- A tail with no digits where the number belongs names nothing, which
-- is the branch a truncated paste takes.
local function test_a_missing_number_names_nothing()
  names("https://github.com/acme/widgets/pull/", "", 0)
  names("https://github.com/acme/widgets/pull/abc", "", 0)
  names("https://github.com/acme/widgets/pull", "", 0)
end

-- The number is read as the leading digits and whatever follows is
-- ignored, so the URL GitHub's own navigation produces — the request
-- with a tab or an anchor on the end — names the request it is a view
-- of, rather than nothing at all.
local function test_a_tail_after_the_number_is_ignored()
  names("https://github.com/acme/widgets/pull/7/files", "acme/widgets", 7)
  names("https://github.com/acme/widgets/pull/7#issuecomment-1",
    "acme/widgets", 7)
  names("https://github.com/acme/widgets/pull/7abc", "acme/widgets", 7)
end

-- A number no pull request can have names its repository but no
-- request: zero, and a value too large to be an integer at all. Both
-- fall through to the same 0 the missing-number branch returns, which
-- is what `land` reads as "nothing to land" — neither crashes, and
-- neither reaches a merge.
local function test_a_number_no_request_can_have_names_no_request()
  names("https://github.com/acme/widgets/pull/0", "acme/widgets", 0)
  names("https://github.com/acme/widgets/pull/99999999999999999999",
    "acme/widgets", 0)
end
