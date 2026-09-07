## Question

How should `gitboard` perform GitHub reads and writes inside ChatGPT Work when
the GitHub connector is authenticated but local processes receive neither
`GITHUB_TOKEN` nor `GH_TOKEN`?

## Evidence

Measured 2026-09-07 in the Work environment while completing `1QjU_Fdth`:

- GitHub operations were available through the authenticated connector.
- `gitboard sync` printed `lanes: unknown (release.yml: no GitHub token: set
  GITHUB_TOKEN (or GH_TOKEN))`.
- The local environment had no token usable by `_work/api.tl`, so integrated
  operations such as PR inspection/landing could not use their intended path.
- PR #85 had already merged, so the session used connector facts and then a
  local board transition to repair the stranded accepted item.
- Current `gitboard` already implements `take --open`, verdict-driven GitHub
  review/landing, cached reads, and already-merged handling. This is therefore
  not a missing-verb or stale-pin problem; it is an authentication/capability
  boundary between an app connector and a child process.

The security constraint matters: a solution must not scrape, reveal, or copy
connector credentials into the shell. It must use a supported delegation or
brokered interaction if direct token inheritance is intentionally unavailable.

## Result

Produce a short decision record that:

1. Documents the supported authentication capabilities available to a local
   `gitboard` process in ChatGPT Work.
2. Determines whether a connector can safely broker the exact GitHub reads and
   writes gitboard needs, or whether gitboard should emit a machine-readable
   action for the orchestrator to execute and acknowledge.
3. Specifies ownership and verification for `sync`, `take --open`, `verdict`,
   and `done` when GitHub interaction crosses that boundary.
4. Includes one end-to-end experiment against a disposable branch or mocked
   transport, without exposing credentials.
5. Separates product/environment work from repository changes and files any
   concrete implementation children in the correct place.

## Non-goals

Do not request that connector tokens be printed or injected into arbitrary
processes. Do not add another GitHub client before establishing which boundary
is supported.
