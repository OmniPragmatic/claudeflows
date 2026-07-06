# Behavioral testing with subagents

The plugin's product is prompts, so its regressions are behavioral, not
syntactic. The planned `/cf-selfcheck` (hardening PRD T4) will lint grammar —
marker pairing, sentinel inventory, gate budgets, field-label byte-match — but
it cannot tell you whether a fresh session actually *follows* a flow. For
that, run the V-* criteria (listed in `cf-feature/SKILL.md`) as scripted
scenarios against fresh subagents, adapting the skill-testing methodology from
obra/superpowers' `writing-skills`.

## Method

1. **Fixture repo.** Create a scratch git repo with a `docs/prds/` directory
   and a minimal fixture PRD containing an `## Implementation roadmap` with
   T1–T3 (all eight fields, em-dash headings). Keep it committed to a fixtures
   branch or regenerate it from the template in `cf-prd/SKILL.md`.
2. **One scenario per V-\* item.** Each scenario is: *setup* (fixture state),
   *stimulus* (the exact `/cf-` invocation to paste), *expected observable*
   (which gate fires, which literal block prints, what the PRD diff is).
3. **Fresh session per scenario.** Run each stimulus in a brand-new session
   (or a dispatched subagent told to execute the skill file verbatim); a warm
   session that has already read the skill will mask re-read failures.
4. **Judge as signal, not CI.** Prompt-behavior is nondeterministic. A failed
   expectation means "investigate the wording", not "the build is red". Two
   consecutive failures of the same scenario on unchanged skill text is the
   actionable threshold.
5. **Record.** Append results to a dated table (scenario, pass/fail/partial,
   transcript pointer, skill version from `plugin.json`). The OKF `generator`
   stamp on saved artifacts tells you which plugin version produced a fixture.

## Scenario sketches

| V-check | Stimulus | Expected observable |
|---|---|---|
| V-regex (7 cases) | `/cf-feature implement T1 from <fixture>` and the 6 variants | PRD-task vs standalone routing per the table in Step 0a |
| V-status | complete a T1 run, answer Yes at `G-step8-confirm` | PRD diff is exactly the one-line Status flip |
| V-carry-over | same run | carry-over block matches the character-level spec |
| V-cap | static count | every gate ≤4 options (also lintable) |
| V-no-roadmap | fixture PRD without roadmap | `G-no-roadmap` fires |
| V-redo | fixture T1 pre-set to Done | `G-step0a-redo` fires |
| V-inferred-ambiguous | two fixture PRDs with T1, `/cf-feature implement T1` | `G-find-path` lists both |
| V-verbatim | any PRD-task run | design-doc Scope bullets ⊇ T1.In scope verbatim |
| V-branch-hint | branch `t1-fix`, no matching PRD, then with one | gate silent, then fires |
| file handoff (1.7+) | any `/cf-feature` run reaching Step 2 | `.claudeflows/tmp/` exists with `.gitignore` = `*`, design file read by passes, cleaned at flow end |
| subagent guard (1.7+) | inspect any Goldfish transcript | no Skill-tool invocation by the Goldfish |
| hooks (1.7+) | new session in a repo with/without `.claudeflows/quiet` | routing hint printed / suppressed |

## When to run

Before tagging any release that touches `cf-feature` or `cf-prd`; after the
T1 reference-file split (re-anchor expectations first); and whenever a
description or template edit is intended to change routing or gate behavior.
