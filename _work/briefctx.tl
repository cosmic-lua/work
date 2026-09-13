--- The typed context records `_work.brieftmpl`'s compiled renderers
--- take: one record per brief template, its fields named for the
--- template's own interpolations (`{{.item_id}}` reads `item_id`).
---
--- Nominal, and that is the point of the module existing at all:
--- `cosmic.template` compiles `{{type Builder from _work.briefctx}}`
--- into `require("_work.briefctx")` plus `d.item_id`, so every field a
--- template names is resolved by the type checker at build time. A
--- misspelled interpolation is a compile error against the generated
--- module, never a placeholder that quietly renders as nothing.
---
--- Every field is a plain `string`: absence is resolved before a
--- render ever runs (`_work.briefcontext` supplies the caller-fill
--- token and records the survivor), so the renderers themselves have
--- no notion of a missing value and no policy of their own.
---
--- Pure types. Nothing here holds data or behaviour.

local record briefctx
  --- `_work.brieftext`'s `BUILDER`: the builder prompt.
  record Builder
    repo: string
    worktree: string
    branch: string
    preparation: string
    board_dir: string
    item_id: string
    handle: string
    title: string
    bounce_context: string
    spec: string
    type_check_cmd: string
    test_cmd: string
    gate_cmd: string
    bootstrap_cmd: string
    gitboard_cmd: string
  end

  --- `_work.brieftext`'s `REWORK`: the rework section spliced into a
  --- builder brief's `bounce_context`.
  record Rework
    judged_head: string
    worktree: string
    branch: string
  end

  --- `_work.brieftext`'s `RESEARCH`: the research-slice prompt.
  record Research
    repo: string
    worktree: string
    item_id: string
    handle: string
    title: string
    bounce_context: string
    spec: string
  end

  --- `_work.brieftext`'s `REFINE`: the spec-refinement prompt.
  record Refine
    product_root: string
    item_id: string
    handle: string
    title: string
    gap: string
    current_spec: string
  end

  --- `_work.brieftext`'s `DECOMPOSE`: the outcome-decomposition prompt.
  record Decompose
    product_root: string
    item_id: string
    handle: string
    title: string
    gap: string
    current_spec: string
  end

  --- `_work.brieftext_review`'s `REVIEW`: the full adversarial review.
  --- `reviewing` is its "what you're reviewing" section, rendered from
  --- `ReviewingDiff` or `ReviewingResearch` below and spliced in.
  record Review
    repo: string
    item_id: string
    handle: string
    title: string
    change_source: string
    reviewing: string
    head_sha: string
    spec: string
    round_context: string
    test_cmd_phrase: string
    worktree: string
    board_dir: string
    review_session: string
    bootstrap_phrase: string
    gitboard_cmd: string
  end

  --- `_work.brieftext_review`'s `REVIEW_SCRIPT`: the mechanical review.
  record ReviewScript
    repo: string
    item_id: string
    handle: string
    title: string
    change_source: string
    board_dir: string
    claim_base: string
    head_sha: string
    spec: string
    product_root: string
    review_session: string
    bootstrap_phrase: string
    gitboard_cmd: string
  end

  --- `_work.brieftext_review`'s `REVIEWING_DIFF`: a diff handover's
  --- "what you're reviewing" section — the product commit range.
  record ReviewingDiff
    claim_base: string
    head_sha: string
  end

  --- `_work.brieftext_review`'s `REVIEWING_RESEARCH`: a research
  --- handover's "what you're reviewing" section — the board commit
  --- and the findings its message body carries.
  record ReviewingResearch
    board_dir: string
    head_sha: string
    findings: string
  end

  --- `_work.brieftext_review`'s `ROUND`: a later review round's own
  --- context section.
  record Round
    round_number: string
    judged_head: string
    current_head: string
    round_finding: string
  end
end

return briefctx
