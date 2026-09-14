#!/usr/bin/env cosmic
--- Production-CLI proof of the native connector protocol. A local bare remote
--- stands in for GitHub's Git Database API, but every plan and every indexed
--- call comes from `o/bin/gitboard`; the emulator has no validation-only path.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local boardread = require("_work.boardread")
local connector = require("_work.native_connector_fixture")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local git = require("_work.singlehead_git")
local item = require("_work.item")
local rank = require("_work.gitrank")
local refs = require("_work.refs")
local stateinit = require("_work.stateinit")
local store = require("_work.store")

local BUILDER < const > = "11111111111111111111111111111111"
local REVIEWER < const > = "22222222222222222222222222222222"

local function by_title(root: string, title: string): item.Item
  for _, candidate in ipairs(check.must(store.list(check.must(store.open(root))))) do
    if candidate.title == title then return candidate end
  end
  error("missing item titled " .. title)
end

local function setup(): string, string, string, string
  local base = fs.join(fixture.tmpdir, "native-connector-cycle")
  assert(fs.remove_all(base) and fs.make_dirs(base))
  local seed = fs.join(base, "seed")
  assert(fs.make_dirs(seed) and stateinit.init(seed))
  assert(refs.set_board_mode(seed, "local"))
  local s = check.must(store.open(seed))
  assert(graph.cmd_new(s, "proof outcome", "", nil, "") == 0)
  local outcome = by_title(seed, "proof outcome")
  assert(graph.cmd_new(s, "ranking peer", "", nil, "") == 0)
  assert(rank.cmd_rank(s, outcome.id, "", "", true) == 0)
  fixture.git(seed, {"symbolic-ref", "HEAD", "refs/heads/state"})
  local remote, root = fs.join(base, "remote.git"), fs.join(base, "client")
  fixture.git(base, {"clone", "-q", "--bare", seed, remote})
  fixture.git(base, {"clone", "-q", remote, root})
  assert(refs.set_board_mode(root, "remote"))
  fixture.git(root, {"config", "gitboard.publicationRepository", "proof/board"})
  local product = fs.join(base, "product")
  assert(fs.make_dirs(product))
  fixture.git(product, {"init", "-q", "-b", "main"})
  assert(fs.write(fs.join(product, "result.txt"), "base\n"))
  fixture.git(product, {"add", "result.txt"})
  fixture.git(product, {"commit", "-qm", "product base"})
  return root, remote, outcome.id, product
end

local function test_production_cli_connector_cycle_and_uncertain_publication()
  local root, remote, parent, product = setup()
  local spec = fs.join(root, "research.md")
  assert(fs.write(spec, [[## Change

Measure the native connector path and record its observed result.

## Non-goals

No product repository change.
]]))
  connector.cli(root, {"new", "connector research", "--parent", parent,
      "--spec-file", spec, "--repo", "proof/product"}, nil)
  local opened = connector.publish(root, remote, "01-new", nil)
  assert(opened.commits == 1 and opened.calls >= 3)
  local work = by_title(root, "connector research")

  connector.cli(root, {"claim", work.id, "--session", BUILDER,
      "--repo-dir", product}, 2)
  local claim = connector.publish(root, remote, "02-claim", nil)
  assert(claim.commits == 1)
  local claimed = check.must(store.load(check.must(store.open(root)), work.id))
  assert(claimed.claim == BUILDER, "publication alone did not grant authority")

  local draft = connector.cli(root,
    {"draft", "begin", "--print-id"}, nil).stdout:gsub("%s+$", "")
  local revised = fs.join(root, "revised.md")
  assert(fs.write(revised, [[## Change

Measure the production CLI's indexed connector calls and retain the evidence.

## Non-goals

No product repository change and no special publication driver.
]]))
  local note = fs.join(root, "observation.md")
  assert(fs.write(note, "The connector minted the commit under its own physical author.\n"))
  connector.cli(root, {"spec", work.id, revised, "--base", spec, "--draft", draft,
      "--session", BUILDER}, nil)
  connector.cli(root, {"log", work.id, "--add", note, "--draft", draft,
      "--session", BUILDER}, nil)
  connector.cli(root, {"set", work.id, "--title", "connector proof retained",
      "--draft", draft, "--session", BUILDER}, nil)
  local drafted = connector.publish(root, remote, "03-draft", nil)
  assert(drafted.commits == 3 and drafted.trees >= 3,
    "one connector commit must preserve each draft transition")

  fixture.git(product, {"checkout", "-qb", "work"})
  assert(fs.write(fs.join(product, "result.txt"), "base\nconnector proof\n"))
  fixture.git(product, {"commit", "-qam", "connector proof result"})
  local product_head = check.must(git.text(product, {"rev-parse", "HEAD"}))
  connector.cli(root, {"take", work.id, "--head", product_head,
      "--repo-dir", product, "--session", BUILDER}, nil)
  local handed = connector.publish(root, remote, "04-result", true)
  assert(handed.uncertain, "fixture must exercise the lost update acknowledgement")
  local handed_item = check.must(store.load(check.must(store.open(root)), work.id))
  assert(handed_item.handover_head == product_head,
    "commit handover names the locally verified product commit")
  assert(#handed_item.builders == 1 and handed_item.builders[1] == BUILDER)

  connector.cli(root, {"drop", work.id, "--session", BUILDER,
      "--why", "handover complete"}, 2)
  connector.publish(root, remote, "05-builder-drop", nil)
  connector.cli(root, {"claim", work.id, "--session", REVIEWER,
      "--repo-dir", product}, 2)
  connector.publish(root, remote, "06-reviewer-claim", nil)
  connector.cli(root, {"verdict", work.id, "accept", "--head",
      product_head, "--repo-dir", product, "--session", REVIEWER}, nil)
  connector.publish(root, remote, "07-verdict", nil)
  connector.cli(root, {"done", work.id, "--landed", product_head,
      "--repo-dir", product, "--session", REVIEWER}, nil)
  connector.publish(root, remote, "08-done", nil)
  connector.cli(root, {"drop", work.id, "--session", REVIEWER,
      "--why", "review complete"}, 2)
  connector.publish(root, remote, "09-reviewer-drop", nil)

  local final_head = check.must(refs.read_ref(root, "refs/remotes/origin/state"))
  local view = check.must(boardread.list(root, final_head))
  local final = assert(view.items_by_id[work.id])
  assert(final.title == "connector proof retained")
  assert(final.handover_head == product_head and final.verdict == "accept")
  assert(final.verdict_head == product_head and final.landed_head == product_head)
  assert(final.resolution == "completed" and view.claims_by_id[work.id] == nil,
    "the completed reviewer dropped current authority")
  local history = connector.cli(root, {"log", work.id}, nil).stdout
  assert(history:find("The connector minted the commit", 1, true), history)
  connector.cli(root, {"fsck"}, nil)
end
