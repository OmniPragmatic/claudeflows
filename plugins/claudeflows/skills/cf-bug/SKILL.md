---
name: cf-bug
description: "Use when the user wants broken behavior fixed — a bug, crash, error/exception, 5xx, failing or flaky test, regression, 'X stopped working', or a linked bug issue. Flow: problem doc, independent Goldfish diagnosis, failing test before the fix, smallest fix, precommit review; trivial typo/config fixes take a fast path. If the capability never existed use cf-feature; explaining an error without fixing it is cf-question."
argument-hint: bug description, GitHub issue URL, or symptom + repro
---

Fix a bug using the Elephant/Goldfish workflow. The aim: write a problem doc, Goldfish-check the diagnosis (so we are not anchored to the first hypothesis), capture the bug as a failing test, fix it, then run `/cf-precommit-review` and the test gate.

`$ARGUMENTS` is the bug description provided by the user. If empty, ask for one before doing anything. If `$ARGUMENTS` is a GitHub issue URL or `#<number>`, fetch it first with `gh issue view <number> --json title,body,labels,comments` and seed the problem doc from it.

## Step 0: Triviality gate

**Skip the Goldfish/test ceremony for:** typo fixes in copy or comments, dead-code removal, version bumps, formatter-only diffs, single-line config tweaks. Go straight to Step 5 (`/cf-precommit-review`) and the test gate.

**Run the full loop for everything else,** including small one-line code fixes — small diffs hide bugs disproportionately well.

## Step 1: Write the problem doc (in this conversation)

Print a tight problem doc to the user. Keep it brief but complete:

```
PROBLEM DOC
- Symptom: <what the user observes>
- Repro: <steps to reproduce, or "user did not provide; need to derive">
- Suspected area: <file/module/route/worker/job/screen>
- Hypothesised root cause: <one sentence>
- Blast radius: <which other surfaces could be affected>
- "Fixed" means: <specific test passes / specific behavior / specific output>
```

If the user gave no repro and the bug is not obvious from a single file read, **stop and ask** for a repro path (URL, steps, failing test name, log line, screenshot). Do NOT guess. The Goldfish needs something concrete to act on.

**Browser / simulator validation.** Choose by the detected stack:

- **Web app** (look for `package.json` with a dev script, `vite.config`, `next.config`, `wrangler.jsonc`, etc.): use the Chrome browser MCP against the dev URL (tool naming varies by harness, e.g. `mcp__claude-in-chrome__*`; if the tools are deferred, load them via ToolSearch first). Find the URL from `package.json` scripts, `wrangler.jsonc`, README, or CLAUDE.md; common defaults are `http://localhost:3000`, `http://localhost:5173`, `https://localhost:4444`. Assume the dev server is running, or find the start command from `package.json` scripts (`npm run dev`, `pnpm dev`, etc.) or CLAUDE.md and start it. Navigate, click, screenshot, read the console.
- **Mobile** (Flutter `pubspec.yaml`, native iOS / Android): run on a simulator (`flutter run -d <device>`, `xcrun simctl`, `adb`) and capture screenshots / device logs. For layout-only bugs that reproduce on web, `flutter run -d chrome` plus Chrome MCP works.
- **Backend-only**: skip browser validation. Repro is usually a `curl` against the local server, a failing test name, or a log line.

## Step 2: Goldfish diagnosis check (parallel to your hypothesis)

Spawn a fresh agent with `Agent` tool:
- `subagent_type: "Explore"` for narrow lookups, `"general-purpose"` if the bug spans multiple subsystems. If the harness does not have `Explore` registered, fall back to `general-purpose`.
- `description: "Goldfish bug diagnosis"`

The Goldfish gets ONLY the symptom + repro from Step 1. It does NOT get your hypothesised root cause — that asymmetry is the point.

**Prompt body to send (between markers, exclusive):**

```
<<<DIAG_START>>>
Independent diagnosis of a bug in this repo (read CLAUDE.md / README.md to identify the project name, stack, and one-line purpose; if neither file exists, derive from the manifests; CLAUDE.md at the repo root has the full architecture).
You are a subagent executing a delegated task: do NOT invoke any skill (including cf- skills) via the Skill tool — use only the tools and steps this prompt names.

Symptom: <FILL IN from Step 1>
Repro: <FILL IN from Step 1>

Investigate. Where in the codebase is the bug most likely to live? Cite specific file:line locations. List the top 1-3 candidate root causes ranked by likelihood. For each candidate, name what evidence in the code supports it and what would falsify it. Do NOT propose a fix yet — just diagnose.

If a UI repro is needed, you may use the Chrome browser MCP against the running dev server. Tool naming varies by harness (e.g. `mcp__claude-in-chrome__*`); if the browser tools are deferred in your session, load them via ToolSearch before first use. For mobile and backend-only repos, skip browser validation and diagnose from the code instead.

End with the literal string `diagnosis complete`.
<<<DIAG_END>>>
```

**Compare Goldfish output to your Step 1 hypothesis.**
- Convergence (top candidate matches your hypothesis): proceed to Step 3 with confidence.
- Divergence: re-investigate. Read the Goldfish's evidence. If it is right, update the problem doc and tell the user "Goldfish flagged a different root cause; re-diagnosing." If you are right, write down WHY the Goldfish was wrong — that disagreement is itself useful signal.

If the bug is genuinely tiny (1-3 line fix in a clearly-identified location), you may skip the Goldfish call — but only when the location is mechanically obvious. When in doubt, run it.

**Fix at the origin.** Trace the defect backward from the symptom to where the bad value or state first originates; the fix belongs at the origin, not the symptom site. "I can guard against it here" at the symptom site is symptom-patching — that thought is the signal to keep tracing.

## Step 3: Capture the bug as a failing test BEFORE fixing

The verification criterion lives in code, not in chat. Pick the right tier:

**Pick the right test tier from the project's actual layout.** Common patterns:
- **Models / scopes / validations** → unit test next to the source (Rails `test/models/`, Flutter `test/`, Vitest `*.test.ts`).
- **Controllers / API endpoints** → controller test (`test/controllers/`, Grape API tests, FastAPI `TestClient`, Django views).
- **Workers / background jobs** → worker test (`test/workers/`, RQ tests, Celery tests).
- **UI flows / multi-screen / auth** → E2E (Playwright, Cypress, Capybara system tests).
- **Server-rendered page assertions** → Rails system tests, Django LiveServer.
- **Native UI / widget logic** → Flutter `WidgetTester`, Compose / SwiftUI snapshot.
Inspect the test directories that exist in the repo and pick the tier whose folder is the natural home for this fix.

Write the test. Run it. Confirm it fails for the reason described in the problem doc. If it fails for a different reason, the test is wrong — fix the test before touching the implementation.

**Flaky / nondeterministic failures.** When the bug is an intermittent test, adapt the failing-test contract: reproduce by repetition (run the test 10+ times, or use the runner's repeat/stress flag) and record the failure rate. "Fails for the right reason" then means: fails intermittently with the diagnosed race/timing/ordering signature before the fix, and passes on every repetition after. Fix the nondeterminism at its root (shared state, ordering, time); replace sleeps and bumped timeouts with condition-based waits — wait for the observable state change, not a duration. A raised timeout is symptom-patching.

For UI bugs where a Playwright/Cypress regression spec is overkill, capture the repro as a one-shot script in the conversation: navigate, click, screenshot, read console — and confirm the bug is observable. This is your verification path; you will re-run it after the fix.

## Step 4: Fix it

Implement the smallest change that turns the failing test green and matches the "Fixed means" criterion.

Avoid: adjacent refactors, defensive coding for cases the bug did not surface, fallbacks that mask future regressions, unrequested feature flags. Bug fix scope is the bug, nothing else.

Re-run the failing test. It must go green. If it does not, you have not fixed the bug — do NOT rewrite the test.

For UI bugs: re-verify in Chrome MCP / on the simulator with the same steps from the original repro. A before/after screenshot pair often helps the user follow.

## Step 5: Hand off to `/cf-precommit-review`

Run `/cf-precommit-review` per the canonical procedure. The reviewer is a second Goldfish — it sees only the diff. Triage findings, loop, and exit.

If `/cf-precommit-review` surfaces an issue that the Step 2 diagnosis Goldfish missed, note it in the final report — it tells us where the diagnosis prompt needs to be tighter next time.

## Step 6: Test gate

Run lint / typecheck / unit / E2E sequentially (NOT `&&`-chained — short-circuiting hides failures). Detect the actual commands from the manifests / CI config / CLAUDE.md as in the pre-flight detection rules. Skip tiers that don't apply for this stack (e.g. no separate typecheck step in Ruby; no E2E if there's no `e2e/` directory).

All required tiers must pass. Skip E2E only when the diff is purely model/worker/lib with no observable UI or API surface change. For bugs that touched generated code (e.g. `.g.dart`, protobuf), confirm regeneration ran and the generated files are committed. For UI bugs, also re-verify the original repro in Chrome MCP / on the simulator (whichever applies) one final time before reporting done.

**Evidence rule:** report each tier's result from fresh command output produced in this session. Never claim a tier green from memory, from an earlier session, or because it "should pass" — if you did not run it here, it is not verified.

## Step 7: Final report

Print to the user:
- Bug summary (one line)
- Root cause (one line)
- Fix (file:line)
- Test that captures it (file:test name)
- Goldfish-vs-Elephant agreement (converged / diverged + why)
- `/cf-precommit-review` outcome (rounds, fix/rebuttal counts; repeat rebuttals verbatim ONLY if its own Step 6 report is not directly above in the conversation — never print identical verbatim text twice in a row)
- Test gate status
- Flow stats: <N> Goldfish spawned (diagnosis + reviewer rounds), test files written

**STOP.** Do NOT commit; auto mode does not override the project's commit policy. Wait for the user's literal commit instruction; when it comes, follow the convention you observe in `git log` (subject style, ticket reference, trailers) and do not add `Co-Authored-By: Claude` unless the user's existing log already uses it.
