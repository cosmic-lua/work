## Evidence

Measured at cosmic-lua/work product commit
`1dbd6fb7959576e5ab40f13b4d5d40bb4b5a58ed` in
`/Users/wcm/Documents/Codex/2026-09-08/ok-now-that-we-ve-cleaned/board`.
This replaces the earlier decision-only spec.

```sh
sed -n '255,300p' _work/brieftext_review.tl
sed -n '330,375p' _work/brief_test.tl
sed -n '330,360p' _work/doctrine.tl
sed -n '300,333p' _work/brief.tl
rg -n 'RESEARCH_REVIEW' _work -g '*.tl'
```

The last command located seven sites: brief.tl:8,321 and
brieftext_review.tl:5,16,231,317,324. The only selector is brief.tl:320-321:
a nonempty legacy result wins even over handover_head. The selected template
asks for board show/Git-grep reads and emits a verdict without --head.
The existing brief_test.tl:342 test intentionally pins that behavior.
Doctrine:344-346 instead requires the applying commit as research verdict
evidence; the orchestration paragraph:354-356 keeps board verbs with the caller.

The actual supported handover/verdict path is already commit-only:

```sh
sed -n '414,442p' _work/gitboard.tl
sed -n '29,85p' _work/gittake.tl
cat _work/gitverdict.tl
cat _work/commit_evidence.tl
sed -n '1,25p' _work/fastimport.tl
sed -n '162,243p' _work/brieftext.tl
```

gitboard.tl:421 dispatches take to take_handover. That function validates
a locally present product commit against the immutable product claim base
(:45), then clears legacy pr/result metadata (:68). Verdict refuses a missing
handover (:57-60), checks lineage (:71), and requires the supplied canonical
head to equal the handover (:76-79). Board item refs have their own parentless
roots (fastimport.tl:18-19), not product-main ancestry. A result digest,
item-ref tip, claim-batch root, or board publication commit cannot simply be
substituted for the required applying product commit.

Research agents still return recommendations without changing product or
board files (brieftext.tl:162-243). The caller can supply a real applying
product commit through the existing handover path. When no such product
commit exists, this item must refuse the review, not manufacture evidence or
invent another verdict API.

Executable reproduction used the declared pin, verified with
`shasum -a 256 o/bootstrap/cosmic`:

```text
b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434  o/bootstrap/cosmic
```

The probe below uses temporary product/board repositories only. From the
measured checkout:

```sh
TEST_TMPDIR=/private/tmp/nwly-evidence.Mkia6H sh o/bootstrap/cosmic /tmp/nwly-evidence.Mkia6H/research_probe.lua
```

Exit 0; diagnostic output, excluding ordinary fixture setup verdict lines:

```text
result digest: not a locally inspectable product commit
legacy result brief: success=true headless=true
legacy verdict: refused (no commit handover to judge)
fetched item-ref commit: refused (does not descend from claim base)
normal product handover: legacy result cleared, exact-head brief emitted
mixed result+head today: result wrongly selects headless research brief
ordinary verdict: mismatched head refused; exact head accepted
```

These are observations of the current defect and existing migration path,
not claims that the replacement behavior is implemented. Probe source is
included so the evidence survives the temporary file:

```lua
local check = require("cosmic.check")
local child = require("cosmic.child")
local brief = require("_work.brief")
local evidence = require("_work.commit_evidence")
local flow = require("_work.commit_flow_fixture")
local item = require("_work.item")
local spec = require("_work.spec")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local verdict = require("_work.gitverdict")
local function capture(f, ...)
  local old, lines = print, {}
  _G.print = function(...) local p = {}; for n=1,select("#",...) do p[n]=tostring(select(n,...)) end; lines[#lines+1]=table.concat(p,"\t") end
  local ok, code = pcall(f, ...)
  _G.print = old
  assert(ok, code)
  return code, table.concat(lines,"\n")
end
local s, id, p = flow.fresh("nwly-research")
assert(flow.claim(s,id,flow.BUILDER,p)==0)
local it=check.must(store.load(s,id))
it.result=spec.revision(store.read_spec(s,id))
assert(item.record_involvement(it.builders,flow.BUILDER))
assert(storewrite.save(s,it,"take "..id:sub(1,8).." result:"..it.result))
local digest_commit=evidence.commit_id(p.root,it.result)
assert(digest_commit==nil)
print("result digest: not a locally inspectable product commit")
local code, out=capture(brief.cmd_brief,s,"review",id)
assert(code==0 and out:find("RESEARCH SLICE",1,true))
print("legacy result brief: success=true headless=true")
assert(flow.claim(s,id,flow.BUILDER,p,"drop")==0)
assert(flow.claim(s,id,flow.REVIEWER,p)==0)
local refused, refusal=capture(verdict.cmd_verdict_commit,s,id,"accept","",flow.REVIEWER,false,"",p.root)
assert(refused~=0 and refusal:find("no commit handover to judge",1,true))
print("legacy verdict: refused (no commit handover to judge)")
local loaded=check.must(store.load(s,id))
local board_ref=s.leased_ref[id]
local board_sha=s.leased_sha[id]
local fetched=check.must(child.run({"git","fetch","-q",s.root,board_ref},{cwd=p.root}))
assert(fetched.ok, fetched.stderr)
local wrong, why=evidence.verify_lineage(p.root,p.base,board_sha)
assert(wrong==nil and why:find("does not descend from claim base",1,true))
print("fetched item-ref commit: refused (does not descend from claim base)")
assert(flow.claim(s,id,flow.REVIEWER,p,"drop")==0)
assert(flow.claim(s,id,flow.BUILDER,p)==0)
assert(flow.handover(s,id,flow.BUILDER,p,p.head)==0)
assert(check.must(store.load(s,id)).result=="")
local normal, normal_out=capture(brief.cmd_brief,s,"review",id)
assert(normal==0 and normal_out:find("--head "..p.head,1,true))
assert(not normal_out:find("RESEARCH SLICE",1,true))
print("normal product handover: legacy result cleared, exact-head brief emitted")
local mixed=check.must(store.load(s,id))
mixed.result=spec.revision(store.read_spec(s,id))
assert(storewrite.save(s,mixed,"legacy mixed-fields fixture"))
local mcode,mout=capture(brief.cmd_brief,s,"review",id)
assert(mcode==0 and mout:find("RESEARCH SLICE",1,true) and not mout:find("--head "..p.head,1,true))
print("mixed result+head today: result wrongly selects headless research brief")
mixed=check.must(store.load(s,id)); mixed.result=""
assert(storewrite.save(s,mixed,"restore fixture metadata"))
assert(flow.claim(s,id,flow.BUILDER,p,"drop")==0)
assert(flow.claim(s,id,flow.REVIEWER,p)==0)
local bad, badout=capture(verdict.cmd_verdict_commit,s,id,"accept",p.next_head,flow.REVIEWER,false,"",p.root)
assert(bad~=0 and badout:find("but the handover is",1,true))
local accepted=capture(verdict.cmd_verdict_commit,s,id,"accept",p.head,flow.REVIEWER,false,"",p.root)
assert(accepted==0)
assert(check.must(store.load(s,id)).verdict_head==p.head)
print("ordinary verdict: mismatched head refused; exact head accepted")
assert(store.close(s))
```

The cap-safe scope was measured with:

```sh
wc -l _work/brief_research_test.tl _work/brief.tl _work/brieftext_review.tl _work/brieftext.tl _work/doctrine.tl _work/brief_test.tl _work/brief_review_script_test.tl _work/brief_label_test.tl
```

```text
_work/brief_research_test.tl absent
459 _work/brief.tl
328 _work/brieftext_review.tl
392 _work/brieftext.tl
498 _work/doctrine.tl
461 _work/brief_test.tl
234 _work/brief_review_script_test.tl
234 _work/brief_label_test.tl
```

Dependent tests were located with:

```sh
rg -n 'local function test_review_brief_of_a_research_handover|local function test_verdict_line_ignores_placeholders|local function test_legacy_research' _work/brief_test.tl _work/brief_review_script_test.tl _work/brief_label_test.tl
rg -n 'RESEARCH_REVIEW|research_handover|result = spec|it.result' _work/brief.tl _work/brieftext_review.tl _work/brief_test.tl _work/brief_review_script_test.tl _work/brief_label_test.tl
```

The three affected tests start at brief_test.tl:342,
brief_review_script_test.tl:199, and brief_label_test.tl:138.
A wider `rg -n 'RESEARCH_REVIEW|research_handover|RESEARCH SLICE' . --glob '!o/**'`
also found action/gitview/gitshow legacy-result tests and the RESEARCH
generation template. Those are compatibility/generation surfaces, not review
selection; they are deliberately outside the removal.

## Change

Retire the distinct result-only research-review template. Research review
requires the same exact product handover as ordinary review; it gains no new
board-read, provider, or verdict authority.

1. In _work/brief.tl's cmd_brief review selection, make handover_head the only
   positive eligibility signal. A nonempty result must never select a template.
   With a nonempty handover_head, run the existing ordinary full-versus-
   mechanical selection unchanged, even if legacy result is also nonempty.

   With no handover_head and a nonempty result, return a nonzero
   gitboard-brief refusal with this detail, substituting the actual id8:

   "ID8 has a legacy research result but no commit handover — the caller must
   supply the applying product commit with `take ID8 --head SHA`"

   Preserve the existing no-handover refusal for an item with neither field.
   Preserve preceding unknown-kind, tree, item, and missing-spec checks.
   Refuse before label/history resolution, body printing, measurement, or
   output-file writing. --out must neither create an absent file nor truncate
   an existing file on this refusal.

   No board fields or refs change while briefing. Do not clear result from a
   read or resolve it as a SHA. Existing item-wide round numbering remains
   unchanged, including historical verdict events with legacy result/PR subjects.

2. Remove RESEARCH_REVIEW's literal, record field, and returned export from
   _work/brieftext_review.tl. It is an internal template export: do not keep an
   alias that silently emits another workflow. The measured reference sweep
   names its entire current production use.

   Update only associated module/selection comments in _work/brief.tl and
   _work/brieftext_review.tl, and the two-reviewer-template description in
   _work/brieftext.tl's header, to describe full and mechanical exact-head review.
   Keep REVIEW and REVIEW_SCRIPT literal contents byte-for-byte unchanged.
   Keep the RESEARCH generation template and every non-review body unchanged.
   No "The board" paragraph, nested state path, sync recipe, new placeholder,
   extra board read, provider instruction, or alternate verdict command is added.

3. Replace the seven-line research paragraph at _work/doctrine.tl:340-346,
   rather than append to the 498-line file, with this seven-line paragraph:

   Research agents return recommendations; the caller applies them in the product
   repository and hands over its exact commit through `take ID --head SHA`.
   That commit must descend from the claim's product base. A result digest or
   unrelated board item-ref commit is not a substitute. If no applying product
   commit exists, no review brief is available: stop for caller preparation.
   Research uses ordinary exact-head review; no result-only review template
   or additional agent board-read instructions are emitted.

   This names the caller's preparation responsibility, not an instruction for
   the research agent to change the product or the board. The actual applying
   commit must be present in the declared/mapped product repository, have the
   required product-base lineage, and contain the deliverable under review.
   Do not infer it from a board ref, branch tip, result digest, or claim root.
   Existing gates perform their existing local checks; this item adds no new
   commit-validation rule or conversion mechanism. If a legacy item lacks an
   applicable product claim/base, the caller must establish an ordinary valid
   claim; do not bypass that contract or silently manufacture an empty commit.

   Leave general review/orchestration role wording outside this paragraph
   unchanged. The broader question of who invokes ordinary local verdict
   commands is not reopened by retiring the special research path.

4. Keep legacy data compatibility. Existing result/verdict_spec fields,
   item decoding, display/action compatibility, event history, and historical
   subjects remain readable and unchanged. Existing take_result/library
   compatibility is not removed or re-enabled through the CLI. No mass
   migration, schema bump, cache rewrite, or new flags.

   A caller migrates a result-only item through the existing ordinary handover:
   obtain the applying product commit under a valid claim and record
   take ID --head SHA. The existing take_handover clearing of result is reused,
   not reimplemented. A mixed result+head record can already produce ordinary
   review without mutating its metadata. Both cases retain their history.

5. Add _work/brief_research_test.tl for the new focused behavior, using existing
   fixture/commit_flow_fixture/storewrite helpers and a small local capture
   helper. This sibling avoids filling the 461-line brief_test file; do not
   extract a shared fixture framework or move unrelated tests.

   The new tests must enforce:
   - A valid legacy result-only fixture is still readable but cannot emit a
     review. Pin the actionable refusal and exit code, absence of a successful
     body, unchanged board refs/item fields, and no create/truncate for --out.
     A missing-spec fixture must still get the earlier missing-spec refusal.
     A result digest is never implicitly treated as handover_head.
   - The existing no-result/no-head refusal is unchanged; non-review research
     generation still works for a result-only item and retains its no-board-
     mutation instruction.
   - For both ordinary full and mechanical review, a valid head plus legacy
     result renders byte-identically to the same fixture after only result is
     cleared. The exact handed-over SHA appears in every verdict command,
     the stale-checkout warning remains, and no special capture-board-read or
     headless-verdict recipe is generated. Use a plain spec for these absence
     assertions; never strip quoted text from the caller's verbatim spec.
   - A real fixture sequence starts with legacy result metadata, passes through
     the ordinary claim/handover path, clears result, renders ordinary review,
     rejects a mismatched verdict head, and accepts the exact handover head.
     Also prove that a fetched, unrelated board item-ref commit fails the
     existing product-base lineage check. These prove the migration boundary,
     not a new production validation implementation.
   - The new doctrine paragraph states the caller preparation requirement and
     the no-product-commit refusal. The exported template table contains no
     RESEARCH_REVIEW key (inspect keys without adding an unsafe cast).

   Update only the three identified obsolete test assumptions:
   - brief_test.tl:342: replace the old successful headless-research assertions
     with a compact legacy-result refusal assertion. Keep its fixture helper;
     put the expanded coverage in the new sibling.
   - brief_review_script_test.tl:199: preserve the quoted-placeholder/survivor
     assertions, but give its review phase a real exact-head handover using
     that file's existing handover_diff helper. It must still prove the
     fully-filled ordinary review leaves no genuine placeholders.
     Remove the now-unused specmod import only if this conversion makes it unused.
   - brief_label_test.tl:138: keep all three historical verdict subjects and
     the -4 assertion. In the legacy-result phase retain the valid HEAD instead
     of clearing it; assert the same round through ordinary review. Do not
     weaken legacy event counting or non-review-label checks.

   Keep every modified/new file <=500 lines. The explicit source/test scope is
   the seven existing files measured above plus new _work/brief_research_test.tl.
   No new production module, public cosmic API, cast, or nullable-return
   signature is needed. No new ratchet row is expected from a new test file.
   If removal changes coverage denominators, only the mechanically affected
   _work/brief.tl or _work/brieftext_review.tl row in .cosmic-coverage may be
   updated from measured coverage. A row edit must not excuse lost coverage
   of retained executable lines; do not regenerate the whole baseline.
   The current rows are 73/84 and 4/6 respectively (measured with
   `rg -n -F -e '["_work/brief.tl"]' -e '["_work/brieftext_review.tl"]' .cosmic-coverage`).
   Other baseline movement is a finding, not authority to widen scope.

   Run scoped type/format/lint checks and affected test files. Because a template
   export is removed, run the normal build once before checking dependents.
   Run coverage after the final test edit, and the repository's full CI gate.
   Commit the real implementation before mutation testing. At minimum, bypass
   the legacy-result refusal and confirm the new refusal/no-output test fails;
   then force the presence of result to override a valid head (for example,
   refuse whenever result is nonempty even if a head exists) and confirm the
   mixed-field equality test fails. Restore exactly and rerun the focused tests.

## Non-goals

No new research-result, headless-verdict, PR, caller-input, or conversion API.
No storage/schema/history/action/display migration or changes to claim,
handover, verdict, landing, transport, CI observation, or provider behavior.
No new agent board access, hard-coded state path, clone/sync/provider recipe,
or changes to the ordinary REVIEW/REVIEW_SCRIPT bodies. Do not rewrite
research generation, general orchestration policy, or unrelated stale comments.
