# Changelog

All notable changes to the claudeflows plugin. Versions 1.4.x–1.7.0 were never
released; their work shipped folded into 1.7.1.

## 1.7.1 — 2026-07-06

### Added
- **Auto-routing**: all six skills are now model-invocable. Trigger-shaped
  frontmatter descriptions ("Use when …", with cross-skill tiebreakers) plus a
  one-line `SessionStart` routing hint let Claude announce and invoke the
  matching `/cf-` flow from a plain-language request. Slash commands unchanged.
- **SessionStart hooks** (Windows-safe sh/cmd polyglots, no bash dependency):
  a post-compaction reminder to re-read the active SKILL.md, and the routing
  hint. Per-repo opt-out via `.claudeflows/quiet` or `CLAUDEFLOWS_QUIET=1`.
- **Design-doc file handoff**: `/cf-feature`'s three-Goldfish check hands the
  design doc to each pass as a transient file under `.claudeflows/tmp/`
  (self-git-ignored, session-unique names, cleaned at flow end) instead of
  pasting the doc into three prompts per round.
- **Progress ledgers**: `/cf-feature` and `/cf-precommit-review` persist gate
  and round state to `.claudeflows/tmp/ledger-*.md` so compaction or a crash
  doesn't lose position.
- **Spec-compliance review**: when a design-doc file exists, `/cf-feature`
  Step 5 asks the precommit reviewer to also verify the diff implements the
  design doc; deviations surface as ordinary findings.
- **Flaky-test and fix-at-origin guidance** in `/cf-bug` (repetition-based
  repro contract, condition-based waits over timeouts, trace-to-origin rule).
- **OKF frontmatter** on saved artifacts (PRDs, design docs, memory nuggets),
  now including a `generator: claudeflows/<version>` stamp for upgrade safety.
- **Flow stats line** in every skill's final report (Goldfish count, rounds,
  files written).
- **Subagent guard** in every Goldfish prompt template (a spawned subagent
  must not recursively invoke cf- skills).
- README: 2-minute quickstart, auto-routing and opt-out docs, compaction
  resilience section. `docs/testing.md`: subagent-based behavioral test
  harness for the V-* verification criteria.
- **Plain-language gates**: every AskUserQuestion across all skills rewritten
  so questions, option labels, and descriptions are understandable in one
  read — no internal vocabulary (Goldfish, lens, seed, step names) shown to
  the user — and a durable "gate wording rule" added to each skill. All gates
  now fit AskUserQuestion's 4-option budget (verified by simulated runs).
- Simulation-driven hardening from real fixture runs of all six commands:
  next-task selection no longer re-picks the just-finished task (provisional-
  Done rule + caution line when the PRD wasn't updated), rebutted review
  findings are carried to later reviewer rounds (re-raise carve-out prevents
  cap-outs), the brainstorm contrarian sweep got a real prompt template, and
  cf-prd gained an existing-PRD overlap check plus save-path collision rule.

### Fixed
- Leftover editor notes and duplicated phrases inside the cf-bug DIAG and
  cf-feature design-check Goldfish templates.
- `/cf-feature` Step 4 pre-flight deadlock against the `G-nocode-override`
  Override branch.
- Browser-MCP tool naming portability (harness-specific names, ToolSearch for
  deferred tools) across cf-bug, cf-prd, cf-feature.
- Stale `omniprag` org URLs in both manifests (the GitHub Pages homepage 404'd
  after the org rename); descriptions now count all six skills.
- Interactivity blocks compressed to rationalization tables; evidence rule at
  test gates; opt-in model tiering for cheap lanes; V-check field count
  corrected to the eight-field contract.

## 1.3.0

- Multi-session PRD-task mode: `/cf-prd` emits an `## Implementation roadmap`
  (T1..Tn); `/cf-feature implement T<N> from <PRD path>` executes one task per
  session with verbatim scope seeding, Step 8 close-out, and paste-ready
  carry-over commands.

## 1.2.0

- Interactivity guidelines hardened across skills (mandatory AskUserQuestion
  gates, ≤4-option budgets).

## 1.1.0 and earlier

- Initial marketplace releases: the six Elephant/Goldfish flows (question,
  brainstorm, PRD, bug, feature, precommit-review), stack-agnostic pre-flight
  detection, README workflow diagrams.
