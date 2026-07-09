---
name: cf-prd
description: "Specification flow for turning a roughly-known feature or issue into a PRD, spec, or requirements doc ('write a PRD for issue #42', 'spec out the export feature before we build it'). Flow: codebase grounding, structured gap-filling Q&A, deep research, PRD with explicit open questions. Open-ended ideation is cf-brainstorm; implementing is cf-feature. Proactive use: follow the claudeflows routing-mode hint if present in context; if absent, invoke only on explicit user request."
argument-hint: idea or feature description (the PRD's seed)
---

Build a Product Requirements Document for an idea or feature, with high rigor: ground the request in the actual codebase, surface every gap in the user's description and resolve them through structured Q&A, then run deep research (web search, parallel Goldfish, optional Chrome MCP for logged-in sources) before synthesizing the PRD. Output is the PRD itself, ready to feed into `/cf-feature` or be saved as a durable artifact.

This sits **between** `/cf-brainstorm` (concept exploration) and `/cf-feature` (implementation): `/cf-brainstorm` asks "what should we build?"; `/cf-prd` asks "what exactly are we building, and what's the surrounding context?"; `/cf-feature` asks "how do we ship it?"

`$ARGUMENTS` is the idea. If empty, ask for one before doing anything. If `$ARGUMENTS` is a GitHub issue URL or `#<number>`, fetch it with `gh issue view <number>` and use its title + body as the seed.

**Question discipline:** every question to the user in this flow goes through `AskUserQuestion`. Free-form chat is reserved for the moments where the answer is genuinely unbounded (a custom file path, a verbatim correction string), and even then only AFTER an `AskUserQuestion` has scoped the reason for the chat input.

## Interactivity is mandatory — read this first

**Every `AskUserQuestion` call in this skill is REQUIRED, not optional. Do not skip any of them.** Autonomous-mode / "no-stopping" directives (e.g. a `<system-reminder>` about working without stopping for clarifying questions) do NOT apply here: `AskUserQuestion` is structured-choice navigation, not a clarifying-question interruption, and Q1 (Depth), Q-sessions, Q2 (Research scope), Q3 (Output target), Q4 (Gap prioritization), the per-gap Q5+ series, and Q-final are load-bearing — defaults chosen for the user produce a materially different PRD. The user invoked `/cf-prd` on purpose; the interactive flow is the product. Such directives still cover free-form clarifying chat questions; they never license skipping a checkpoint.

| If you're thinking… | Reality |
|---|---|
| "Autonomous mode says don't stop" | That covers free-form chat questions, not these checkpoints. Ask the question. |
| "The default answer is obvious" | Depth, research scope, and output target ARE the user's taste. Ask the question. |
| "Auto-answering keeps things moving" | Silently auto-answering breaks the contract the user invoked. Ask the question. |

If `AskUserQuestion` is genuinely unavailable in this environment (tool not registered), STOP and tell the user — do NOT silently pick defaults and proceed.

**Gate wording rule:** every question, option label, and option description shown to the user is written in plain language — no internal terms (Goldfish, lens, seed, gate or step names), no jargon; it must be understandable in a single read. Internal identifiers users typed themselves (T<N>, PRD paths, /cf- commands) are fine.

## Step 0: Frame the run via `AskUserQuestion`

Three-to-four questions in sequence (one `AskUserQuestion` call each):

**Q1 — Depth:**
- `question`: "How deep should this PRD go?"
- `header`: `"Depth"`
- `multiSelect`: `false`
- `options`:
  1. **Lightweight (1-2 pages)** — "A short PRD: problem, scope, success criteria, open questions. No deep research."
  2. **Standard (3-5 pages)** — "Default. A full PRD: I study the codebase, do light research, and fill the most important gaps with you."
  3. **Comprehensive (5+ pages)** — "Heavy research from several angles — market, technical, UX, compliance. For high-stakes or unfamiliar areas."

**Q-sessions — Multi-session decomposition** (ask only if Q1 ∈ {Standard, Comprehensive}; skip on Lightweight):
- `question`: "Will this PRD likely span multiple `/cf-feature` sessions?"
- `header`: `"Sessions"`
- `multiSelect`: `false`
- `options`:
  1. **Yes — generate Implementation roadmap** — "I'll split the PRD into 2-6 tasks (T1..Tn), each sized for one `/cf-feature` session. The PRD becomes the lasting spec, and each session ends with a ready-to-paste command for the next task. Pick this for big features that touch 3 or more layers of the code or take more than a day to build."
  2. **No — single `/cf-feature`** — "The PRD covers one feature you can build in a single session. It keeps the simple `Implementation hints` section."
  3. **Decide for me** — "I'll decide after I've studied the codebase and listed the open gaps: multiple sessions if the feature touches 3 or more layers of the code or has 6 or more open gaps, otherwise one session. I'll tell you the decision in chat — no extra question to answer."

**Q2 — Research scope:**
- `question`: "How much outside research should I do?"
- `header`: `"Research"`
- `multiSelect`: `false`
- `options`:
  1. **None** — "I'll use only the codebase and my own reasoning. Good for internal tools or experiments."
  2. **Web search only** — "I'll search the public web for similar products and proven technical approaches. Your browser stays untouched."
  3. **Web + your Chrome browser** — "Web search plus your logged-in Chrome browser for pages that need a sign-in — Reddit, X, paywalled articles, internal dashboards. I'll ask you before opening any page."

**Q3 — Output target:**
- `question`: "Where should the PRD end up?"
- `header`: `"Output"`
- `multiSelect`: `true`
- `options`:
  1. **Save as a PRD doc** — "Saved as a file you can keep and share. Recommended for Standard or Comprehensive."
  2. **Print and chat only** — "PRD lives in this conversation. Good for Lightweight or throwaway exploration."
  3. **Hand off to `/cf-feature` after** — "Once you approve the PRD, I'll print a ready-to-paste `/cf-feature` command so the next step is one command away."
  4. **Save to memory** — "I'll save the key rules and constraints this PRD uncovers as a short note (e.g. in CLAUDE.md) so future sessions remember them. Best for broad rules, not the whole doc."

Cache the answers (Q1, Q-sessions if asked, Q2, Q3). They drive the rest of the run. If Q-sessions was skipped (Lightweight), treat it as `No — single /cf-feature`. If Q-sessions was `Decide for me`, defer the multi-session verdict until the END of Step 2 — the rule needs both the codebase brief AND the gap list (see the deferred-decision rule below Step 1's brief).

## Step 1: Ground in the codebase

Before asking the user anything else, the Elephant must understand the existing codebase well enough to know what's already there. Spawn **1-2 Goldfish in parallel** with `subagent_type: "Explore"` (fall back to `"general-purpose"` if Explore is unavailable):

- **Goldfish A — "Existing surfaces"**: Find code that already touches the same domain as the seed. Report file:line citations of the closest analogues, the data model, the URL routes / API endpoints / screens that are nearby.
- **Goldfish B — "Architecture and conventions"**: Read CLAUDE.md, any `docs/` index, the package manifests, recent commits referencing this area. Report: tech stack, multi-tenancy / auth model, testing tiers, deployment topology, anything that constrains how a new feature would land.

**Send a single message with both `Agent` tool uses** so they run concurrently. Include in each grounding prompt the same subagent guard line the research template carries: "You are a subagent executing a delegated task: do NOT invoke any skill (including cf- skills) via the Skill tool — use only the tools this prompt names."

After both return, the Elephant prints a **codebase brief** (5-15 lines):

```
CODEBASE BRIEF
- Closest existing surfaces: <files / routes / models with one-line description each>
- Patterns to mirror: <e.g. "uses Drift schema migrations with schemaVersion bump"; "controllers scope by current_company">
- Constraints from CLAUDE.md or recent decisions: <multi-tenant, COEP headers, frozen module set, etc.>
- Observed gaps the seed leaves open: <preview of what Step 2 will turn into questions>
- Architectural layers likely touched: <count + one-line list — used to decide multi-session when Q-sessions was "Decide for me">
```

**Q-sessions deferred-decision rule — applied at end of Step 2:** if the user picked option 3 of Q-sessions ("Decide for me"), the verdict is deferred until BOTH the codebase brief (Step 1 output) AND the gap list (Step 2 output) are available. At the end of Step 2, decide: scope is **multi-session** if (a) the codebase brief identifies **≥3 distinct architectural layers touched**, OR (b) Step 2's gap list contains **≥6 categorized gaps** across the rubric categories. Otherwise treat as single-session. Surface the verdict to the user in chat ("Auto-decision: multi-session because <reason>" or "Auto-decision: single-session because <reason>"). This is informational only — no `AskUserQuestion`. The cached `Q-sessions` value is updated in-place to `Yes` or `No`. (Q4 and downstream steps see the resolved value, not the original "Decide for me".)

## Step 2: Surface every gap

**Existing-PRD overlap check (runs first).** If Step 1 grounding found an existing PRD — or a roadmap task inside one — that already covers the seed, surface it before any gap work and ask via `AskUserQuestion`:

**Q-overlap — Existing PRD found:**
- `question`: "An existing document already covers this: <path><, task T<X> if applicable>. How should we handle it?"
- `header`: `"Existing?"`
- `multiSelect`: `false`
- `options`:
  1. **Update the existing PRD** (Recommended) — "Revise that document instead of writing a second one."
  2. **Write a new PRD that replaces it** — "The new document links back to the old one and marks the overlapping part as replaced."
  3. **Keep both, continue separately** — "Two documents will describe the same feature — I accept that risk."
  4. **Stop** — "I'll read the existing document first and come back."

On option 1, this run becomes a revision: Step 5 synthesis edits the existing file in place (same filename, sections updated, roadmap task IDs preserved). On option 2, at save time add a markdown link to the old PRD and add one line under its overlapping section or task: `Superseded by <new path>.` On option 3 (or when no overlap exists), continue as normal.

Now the Elephant analyzes `$ARGUMENTS` and the codebase brief, and produces a complete list of gaps. Categories to cover (omit only if genuinely n/a):

- **Who & why**: target user persona, the job-to-be-done, the trigger / moment of need
- **What**: in-scope behavior, out-of-scope explicitly, MVP vs. full, feature variants or modes
- **How well**: success metrics (numerical where possible), performance budgets, accessibility level, scale assumptions
- **When**: deadline if any, dependencies on other work, sequencing
- **Constraints**: budget, tech stack restrictions, compliance (GDPR / SOC2 / PCI / industry-specific), brand voice, multi-tenant scoping, internationalization, offline behavior
- **Failure modes**: what does the user see when each thing breaks; rollback plan; degraded modes
- **Pricing & go-to-market** (if a paid feature): tier, packaging, sales motion
- **Instrumentation**: what events / logs / metrics fire; what dashboards exist for it after launch

Print the gap list grouped by category. Number every gap globally (G1, G2, …). Each gap is one line: the question and why it matters.

Then ask via `AskUserQuestion`:

**Q4 — Gap prioritization:**
- `question`: "Which gaps should we fill in before I draft the PRD? (Anything you don't pick goes into the PRD's Open Questions section.)"
- `header`: `"Gaps"`
- `multiSelect`: `true`
- `options` — produce one option per gap, **but** AskUserQuestion supports at most 4 explicit options (the harness auto-injects a 5th "Other"). If there are more gaps than fit, group them: each option represents a category (e.g. "Who & why — 3 gaps", "How well — 4 gaps") and the user picks categories to fill; multiSelect is true, so selecting all four fills everything detected. The default kit:
  1. **Who & why** — "Who it's for, what they're trying to get done, and what prompts them to use it."
  2. **What & scope** — "What's included, what's left out, and the smallest useful version."
  3. **How well** — "Success numbers, speed, accessibility, and expected load."
  4. **Constraints, failure modes & instrumentation** — "Legal rules, tech limits, budget, what users see when something breaks, and how we'll measure it after launch."

If the gap count is small (≤4) AND each gap is sharp and self-contained, present individual gaps as the options instead of categories. Use judgment.

## Step 3: Fill the selected gaps

For every gap the user selected, ask one `AskUserQuestion` per gap. Each question is structured: present the gap, list 2-3 plausible answers (the Elephant's best educated guesses based on the codebase brief and `$ARGUMENTS`) plus a Defer option — at most 4 explicit options total. The harness auto-injects a 5th "Other (specify in chat)" on every `AskUserQuestion`; never add your own Other. Concrete pattern:

```
Q5+ — <Gap label>:
- question: "<the gap, phrased as a question>"
- header: "<short tag>"
- multiSelect: false (or true when genuinely multi-pick, e.g. "Which platforms?")
- options:
  1. <plausible answer 1, with one-line justification>
  2. <plausible answer 2>
  3. <plausible answer 3 — omit when only two are plausible>
  4. **Defer to PRD's Open Questions** — "I don't know yet — note it as an open question in the PRD."
```

If the user picks **Defer**, write that gap into the PRD's Open Questions section verbatim and move on. If the user picks the auto-injected **Other** and types an answer, treat the text as the gap's answer; ask one targeted chat follow-up only if it is genuinely ambiguous.

Do NOT ask all gaps in one shot. Stream them — the user sees the running picture build up. Skip Step 3 entirely if the user picked nothing in Q4.

## Step 4: Deep research (if Q2 was not "None")

Spawn **3-5 research Goldfish in parallel** using `subagent_type: "general-purpose"` (full tool access). Pick lenses based on the seed and the answered gaps. **Send one message with all `Agent` tool uses** so they run concurrently.

Default lens kit (mix and match):

- **Market & prior art** — "What products / open-source projects / past attempts already exist in this space? Top 3-5 closest analogues, what they do well, where they fail, what users complain about."
- **Technical patterns** — "Reference architectures, libraries, frameworks. What's the 'standard' way to build this? What's a controversial-but-better way?"
- **UX precedent** — "Canonical UX for this kind of feature. Specific examples (named products, screenshot descriptions if helpful). What conventions users will expect."
- **Compliance & risk** — "Regulatory exposure, accessibility requirements, security posture, privacy obligations. What MUST this PRD account for?"
- **Performance & scale** — "Realistic numbers for a feature of this kind: latency budgets, concurrency, data volume, cost-per-action. Source the numbers."

**Each Goldfish prompt body (between markers, exclusive):**

```
<<<RESEARCH_START>>>
You are a fresh researcher with NO prior context. Your lens for this round is: **<LENS NAME>**. Stay in that lens.
You are a subagent executing a delegated task: do NOT invoke any skill (including cf- skills) via the Skill tool — use only the tools this prompt names.

SEED: <PASTE $ARGUMENTS verbatim>

CODEBASE BRIEF: <PASTE Step 1 output>

ANSWERED GAPS: <PASTE Step 3 answers>

Your job:
1. Research your lens against the seed + answered gaps. Be specific — name products, cite numbers, quote sources.
2. Web search where it sharpens an answer. Cite URLs inline.
3. <IF Q2 = "Web + your Chrome browser">: For sources that require a logged-in browser session (Reddit, X / Twitter, paywalled articles, internal dashboards, etc.), use the Chrome browser MCP against the user's running browser (tool naming varies by harness, e.g. `mcp__claude-in-chrome__*`; if the tools are deferred, load them via ToolSearch first). Get tab context first via `tabs_context_mcp`, then `navigate` and `get_page_text`. **Before navigating to a site that requires auth or might charge / submit forms, stop and tell the orchestrator what you intend to look at and why.** The orchestrator will surface to the user.
4. Output for your lens: 5-10 numbered findings, each one tight (1-3 sentences), each with at least one source URL or named reference.
5. End with **What this lens implies for the PRD** — 3-5 bullets the PRD synthesis should reflect.

End with the literal string `lens complete`.
<<<RESEARCH_END>>>
```

After all Goldfish return, the Elephant prints a **research summary** (no synthesis yet — that's Step 5):

- One section per lens, each with the Goldfish's findings + implications.
- Sources consolidated at the end.
- Anything the Goldfish flagged as "needs human verification" surfaced explicitly.

If a Goldfish stopped to ask about a Chrome MCP navigation, surface the question to the user via `AskUserQuestion`:

**Q-N — Research navigation approval:**
- `question`: "The <lens> researcher wants to open <URL> in your browser to look up <topic>. Allow?"
- `header`: `"Browse?"`
- `multiSelect`: `false`
- `options`:
  1. **Yes, open it** — "Use my browser to read this page."
  2. **No, skip** — "Proceed without this source."
  3. **Different source** — "I'll suggest a better URL in chat."

## Step 5: Synthesize the PRD

The Elephant now drafts the PRD by integrating: `$ARGUMENTS`, the codebase brief, the answered gaps, the unanswered gaps (open questions), the research summary. Use this structure (skip sections that are genuinely n/a; mark sections "TBD" if the gap was deferred to Open Questions):

```
# PRD: <title>

## Executive summary
<2-4 sentences: what, who for, why now>

## Problem statement
<the underlying user / business problem, stated independently of solution>

## Target users
<persona(s), JTBD, trigger / moment of need — from gap answers>

## Current state
<from codebase brief: what exists today, what's adjacent, what we'd reuse vs. replace>

## Proposed solution
<the shape of the answer — high-level, NOT implementation>

## Scope
**In:** <bullets>
**Out:** <bullets — explicitly>

## User stories / Jobs-to-be-done
<as-a / I-want / so-that, or JTBD format>

## Functional requirements
<numbered list, each requirement testable>

## Non-functional requirements
- **Performance:** <budgets>
- **Accessibility:** <level, e.g. WCAG 2.1 AA>
- **Security & privacy:** <auth, data handling, PII>
- **Multi-tenant / scoping:** <if applicable>
- **i18n / localization:** <if applicable>
- **Offline / degraded modes:** <if applicable>

## Success metrics
<numerical where possible, with target values + measurement method>

## Risks & mitigations
<table or bulleted list: risk, likelihood, impact, mitigation>

## Implementation hints — OR — Implementation roadmap
<see "Implementation block" subsection just after this template; emit single-session OR multi-session, never both>

## Open questions
<gaps the user deferred, plus anything research surfaced as needing human verification>

## Sources & references
<all Goldfish citations, deduplicated, grouped by theme>

## Out-of-scope follow-ups
<noted, not built; future PRDs>
```

(End of the universal PRD template. The conditional Implementation block below replaces the `## Implementation hints — OR — Implementation roadmap` placeholder in the template above with one of the two concrete sections, picked by `Q-sessions`.)

### Implementation block — single-session form (Q-sessions = "No")

Emit this section in the PRD verbatim:

~~~
## Implementation hints

<loose; refined later in /cf-feature: layer ordering, data model sketch, key dependencies>
~~~

### Implementation block — multi-session form (Q-sessions = "Yes" or auto-decided Yes)

Emit this section in the PRD with placeholders substituted per the decomposition rubric below:

~~~
## Implementation roadmap

This PRD is implemented across multiple `/cf-feature` sessions. Each task below = one session's worth of work, sized so a fresh session can pick up the task cold without re-interpreting the PRD.

Status legend: `Not started` | `Done` (only two states; no in-between).

### T1 — <short title>
**Status:** Not started
**Depends on:** —
**In scope:**
- <bullet per concrete deliverable>
**Out of scope:**
- <bullets>
**Surfaces touched:** <file paths grouped by layer>
**Interfaces:** <function signatures / API request-response shapes / DB columns / schema fragments — concrete enough that two implementers converge>
**Verification:** <test names, manual steps, walkthrough criteria>
**Next command:** `/cf-feature implement T1 from <PRD path>`

### T2 — <title>
**Status:** Not started
**Depends on:** T1
[same shape as T1]
~~~

**Decomposition rubric (the Elephant uses this to size tasks at synthesis time):**
- Target **2-6 tasks** total. If decomposition would produce >6, the PRD is too big — pause before continuing synthesis and ask via `AskUserQuestion`:

  **Q-toobig — Task budget exceeded:**
  - `question`: "This PRD splits into <N> tasks — more than the 6-task budget. How should we proceed?"
  - `header`: `"Too big"`
  - `multiSelect`: `false`
  - `options`:
    1. **Narrow the scope** (Recommended) — "Tell me in chat what to cut; I'll re-plan with fewer tasks."
    2. **Split into multiple PRDs** — "Tell me in chat where to split; this run covers the first document."
    3. **Continue anyway** — "Keep all <N> tasks; I accept that each session's slice will be thinner."
- **Per-task size budget:** ≤8 surfaces touched (file paths), ≤1 schema migration, ≤1 new top-level architectural module. "Top-level architectural module" is stack-relative:
  - **Rails**: a new `app/<dir>/`, a new Sidekiq queue, or a new engine under `engines/`.
  - **Flutter**: a new feature folder under `lib/<feature>/`, or a new BLoC/Cubit family.
  - **Node/Workers**: a new `packages/<name>/`, or a new top-level Worker route module.
  - **Python (Django)**: a new `apps/<name>/` Django app, or a new app-level package under the project root.
  - **Python (FastAPI / Flask)**: a new router module / blueprint package, or a new top-level service module.
  - **Go**: a new top-level package under `cmd/<name>/`, `internal/<pkg>/`, or `pkg/<name>/`.
  - **Generic fallback**: a new top-level directory the manifests don't yet reference.
- **Every task MUST have ALL eight fields filled below the heading** (Status, Depends on, In scope, Out of scope, Surfaces touched, Interfaces, Verification, Next command). No `TBD`. No stubs. If a field would be `TBD` for a task, the task is under-decomposed — split it or specify the missing field.
- **Re-synthesis loop:** if the first synthesis pass emits any `TBD` field, re-synthesize that task with stricter prompting. Max **2 attempts** per task. If still `TBD` after 2 attempts, emit the PRD with a `## TODO: synthesis incomplete` block listing the TBD fields per task. Document this in chat — do NOT block via `AskUserQuestion` (this is a synthesis output, not a user-choice gate).
- **Task IDs:** `T1`, `T2`, ..., `Tn`. No zero-padding (T1, not T01). No upper cap (T999+ is allowed but the 2-6 budget makes it irrelevant in practice).
- **`Depends on` syntax:** comma-separated task IDs like `T1, T2` (no "and"), or a single em-dash `—` (U+2014) for no dependencies. Cross-PRD dependencies are NOT supported in v1.3 — same-PRD references only.
- **Task title constraints:** single-line only. If a title would contain a newline, rephrase it. Plain ASCII strongly preferred for the title to keep the Step 8 PRD `Edit` simple (Unicode in titles works but the Edit is more fragile if the user hand-edits the PRD between sessions).
- **Heading separator is critical:** the `### T<N> — <title>` heading uses an **em-dash** (U+2014) between the ID and the title. /cf-feature's Step 0a and Step 8 grep on this exact character. Do NOT substitute a hyphen-minus (`-`, U+002D) or en-dash (`–`, U+2013) when authoring or hand-editing the PRD — those won't match and the skill will fall to `G-task-missing` or `G-edit-fail`. If you copy a PRD template from somewhere else, verify the em-dash codepoint before saving.
- **Field naming is canonical:** the field labels emitted MUST be exactly `**Status:**`, `**Depends on:**`, `**In scope:**`, `**Out of scope:**` (no parenthetical), `**Surfaces touched:**`, `**Interfaces:**`, `**Verification:**`, `**Next command:**`. These match the parser regexes in `/cf-feature` Step 0a.3.f (see cf-feature SKILL.md). Adding a parenthetical clarifier (e.g. `**Out of scope (deferred):**`) WILL break the parser — put any clarifier in the body, not the label.
- **`Next command` substitution at PRD save:** before writing the PRD to disk in Step 7, replace every `<PRD path>` placeholder inside the emitted `Next command` lines with the resolved save path (the actual file path the PRD is being written to). The placeholder is intended to be resolved at synthesis time, not preserved as a literal token. Likewise, replace `<short title>` / `<title>` placeholders with the actual task titles produced by decomposition. After Step 7 substitution, the PRD on disk has fully resolved `Next command` lines that the user can copy verbatim.

**Open Knowledge Format (OKF) cross-links.** In the PRD body, wherever you reference an upstream artifact — the seeding GitHub issue, a related PRD, the CLAUDE.md the codebase brief drew on — write it as a markdown link (`[issue #42](https://github.com/...)`, `[related PRD](other-prd.md)`) rather than bare text. These links are what make a saved PRD walkable as part of an [OKF](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) bundle (markdown + YAML-frontmatter docs whose links form a knowledge graph). The OKF frontmatter block itself is stamped onto the file at save time — see Step 7 — so it only exists on the disk artifact, never in the chat-only print.

Print the full PRD.

## Step 6: User review

Ask via `AskUserQuestion`:

**Q-final-1 — PRD verdict:**
- `question`: "What's next for this PRD?"
- `header`: `"Verdict"`
- `multiSelect`: `false`
- `options`:
  1. **Approve as-is** — "Looks good — go ahead and save / hand off as I chose earlier."
  2. **Refine specific sections** — "I'll pick which sections to revise."
  3. **Reject and restart** — "The PRD missed the mark. Start over from the first questions."
  4. **Stop here** — "Print only, don't save or hand off."

If **Refine specific sections**, ask:

**Q-refine — Which sections:**
- `question`: "Which parts need revision?"
- `header`: `"Refine"`
- `multiSelect`: `true`
- `options` (4 buckets — at most 4 explicit options; a section not listed is reachable via the auto-injected "Other"):
  1. **Framing** — "Executive summary, Problem statement, Target users, Current state."
  2. **Solution & scope** — "Proposed solution, Scope, User stories."
  3. **Requirements & metrics** — "Functional, Non-functional, Success metrics."
  4. **Risks, roadmap & open items** — "Risks, Implementation block, Open questions, Sources."

For each picked bucket, ask in chat with one targeted prompt naming the bucket's sections ("Which of Executive summary / Problem / Target users / Current state, and what should change?"). Re-draft the affected sections, re-print the PRD, re-ask Q-final-1.

If **Reject and restart**, go back to Step 0.

## Step 7: Output

Drive the output by what the user picked in Q3 (output target). Each Q3 selection produces a side-effect:

- **Save as `<path>`**: write the PRD to disk. Resolve the target path in this order: an existing PRD location if the project has one (`docs/prds/`, `prd/`, or one referenced from CLAUDE.md); else `docs/prds/<slug>-<YYYY-MM-DD>.md` if a `docs/` tree exists; else `docs/specs/<slug>-<YYYY-MM-DD>.md`; else `notes/prds/<slug>-<YYYY-MM-DD>.md`. Derive the slug from the PRD title (kebab-case, lowercase) and date from `date +%Y-%m-%d`. If the directory doesn't exist, create it. If the resolved path already exists, do NOT overwrite — append `-2` (then `-3`, …) to the slug and tell the user. **Stamp OKF frontmatter on the file** (see "OKF frontmatter" below) so the saved PRD is a valid [Open Knowledge Format](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) doc. Confirm the path back to the user.
- **Save to memory**: write the cross-cutting policies / constraints the PRD discovered (NOT the full PRD body — just the durable nuggets that future sessions should know) for future sessions to recall. **Target, in order:** (a) if a `docs/okf/` bundle directory exists, OR the user asks for OKF, write the nugget as an OKF doc at `docs/okf/<slug>.md` (one concept per file; create `docs/okf/index.md` with a one-line pointer if absent); (b) otherwise fall back to the project's existing memory system or CLAUDE.md, as before. Either way, surface the diff before applying. When writing an OKF nugget, stamp the same frontmatter shape as the PRD block below but with `type` reflecting the nugget's concept (e.g. `Policy`, `Constraint`, `Decision`), its own one-line `description`, tags, timestamp, and generator — the "type is always PRD" rule applies ONLY to the saved PRD artifact.
- **Hand off to `/cf-feature`**: print the literal command the user can paste to invoke `/cf-feature`. Only emit if the PRD was actually written to disk (i.e. Q3 also includes "Save as a PRD doc" or "Save to memory" with a path). If Q3 selected ONLY "Print and chat only" + "Hand off to /cf-feature after", surface a warning in chat ("PRD wasn't saved to disk; carry-over command has no PRD path. Save first, then re-emit the handoff line.") and skip the handoff line. Otherwise, two cases:
  - **If `Q-sessions = Yes` AND the PRD has an Implementation roadmap with at least one task:** wrap T1's `Next command` (copied verbatim from the saved roadmap) as: `Run <Next command> when ready.` — e.g. `Run /cf-feature implement T1 from docs/prds/<slug>-<date>.md when ready.` The bare command between `Run ` and ` when ready.` is the paste-able part.
  - **Otherwise (single-session):** emit the form `Run /cf-feature <one-line description> when ready.` where `<one-line description>` is sourced from the PRD's executive summary in a way that does NOT start with the literal word `implement` (otherwise it would collide with the PRD-task regex in `/cf-feature` Step 0a). Prefer description verbs like `add`, `build`, `wire`, `support`, `enable`. Example: `Run /cf-feature add multi-tenant export to CSV (per docs/prds/export-2026-05-17.md) when ready.` Do NOT auto-invoke either form.
- **Print and chat only**: do nothing further.

If multiple Q3 options were picked, do all of them.

### OKF frontmatter

When the PRD is written to disk (the "Save as `<path>`" target), prepend this YAML frontmatter block above the `# PRD: <title>` line so the file is a valid [Open Knowledge Format](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) doc — a markdown body with structured frontmatter that any OKF consumer (an agent, a visualizer, a `/cf-feature` Goldfish) can index:

~~~
---
type: PRD
title: <the PRD title, without the leading "PRD: ">
description: <one-line executive summary>
resource: <GitHub issue URL the PRD was seeded from, if any — OMIT this line entirely if there is none>
tags: [prd, <1-3 lowercase area tags derived from the domain, e.g. export, billing, auth>]
timestamp: <ISO-8601 UTC>
generator: claudeflows/<plugin version, read at save time from ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json; use "unknown" if unreadable>
---
~~~

Rules:
- **`timestamp`** is filled at save time from `date -u +%Y-%m-%dT%H:%M:%SZ` (Bash). Do not hand-write it.
- **`type`** is always exactly `PRD` for the saved PRD artifact (memory nuggets carry their own concept type — see "Save to memory" above). This is the one field OKF requires; everything else is conventional.
- The frontmatter is **additive** — it sits above the PRD body and does NOT touch the `**Status:**` / `**Surfaces touched:**` body-field labels that `/cf-feature` Step 0a parses. Leave those exactly as the template emits them.
- This block exists ONLY on the disk artifact. Never include it in the chat-only print (Step 5) or the "Print and chat only" output.

## Final report

Print to the user:
- PRD title (one line)
- Depth + research scope chosen
- Codebase brief one-line summary
- Gaps surfaced / filled / deferred (counts)
- Research lenses run
- Flow stats: <N> Goldfish spawned (codebase grounding + research lenses)
- Where the PRD lives now (file path, memory entry, both, or chat-only)
- Next action (e.g. "Run `/cf-feature ...` when ready" or "Open questions need user input before this is shippable")

**STOP.** Do NOT commit; auto mode does not override the project's commit policy. If the PRD was saved to disk, it's a new file the user will commit themselves when ready. If the user later asks you to commit it in a follow-up turn, follow the convention you observe in `git log` (subject style, ticket reference, trailers) and do not add `Co-Authored-By: Claude` unless the user's existing log already uses it.
