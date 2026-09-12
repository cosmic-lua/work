local briefctx = require("_work.briefctx")

local function render(d: briefctx.Decompose): string
  local parts: {string} = {}
  parts[#parts + 1] = "You are a decomposer for the work board. You have no memory of any\nprior conversation — everything you need is below. You are the only\nrefiner/decomposer running right now; `sync` before you write.\n\n## Where to work\n\n`bin/gitboard` in the product checkout fetches its own pinned release.\nExport SSL_USE_SYSTEM_CERTS=1 before any command that reaches GitHub.\n\n```\ncd "
  -- decompose:11
  local v1: string = d.product_root
  parts[#parts + 1] = v1
  parts[#parts + 1] = "\nexport SSL_USE_SYSTEM_CERTS=1\nbin/gitboard sync\n```\n\n## The task: decompose one outcome into workable children\n\nOutcome item id: `"
  -- decompose:18
  local v2: string = d.item_id
  parts[#parts + 1] = v2
  parts[#parts + 1] = "` (handle "
  -- decompose:18
  local v3: string = d.handle
  parts[#parts + 1] = v3
  parts[#parts + 1] = ")\nTitle: "
  -- decompose:19
  local v4: string = d.title
  parts[#parts + 1] = v4
  parts[#parts + 1] = "\n\n"
  -- decompose:21
  local v5: string = d.gap
  parts[#parts + 1] = v5
  parts[#parts + 1] = "\n\nCurrent spec/prose on the outcome (may be empty):\n\n---\n"
  -- decompose:26
  local v6: string = d.current_spec
  parts[#parts + 1] = v6
  parts[#parts + 1] = "\n---\n\nWork backwards from the outcome's win condition: cut it into\nchildren, each sized for one session's PR, until nothing is left\nuncut. Each child needs its own pullable spec — run\n`bin/gitboard help bar` for the bar; never file a child as a\nplaceholder title with no `## Change`. Real landing order between\nchildren is their rank, not prose. File each with:\n\n```\nbin/gitboard new \"<child title>\" --parent "
  -- decompose:37
  local v7: string = d.item_id
  parts[#parts + 1] = v7
  parts[#parts + 1] = " --spec-file <file>\n```\n\nand `bin/gitboard rank <child-id> --before|--after <sibling-id>`\nfor any real ordering between the children you filed.\n\n## Rules\n\nNever touch a product tree, never open a PR. Decompose this one\noutcome only. A cut you cannot make from the tree and AGENTS.md\nalone is not yours to guess past: say so and stop. Never hand-edit\nan item file.\n\n## Final report\n\nThe children filed (id, title, one line each), how they are\nordered, and the verb verdict lines. Keep it factual and concise.\n"
  return table.concat(parts)
end

return {render = render}
