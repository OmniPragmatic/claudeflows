---
name: cf-brainstorm
description: "Divergence flow for a rough or half-formed idea ('I have an app idea but I am not sure what it should be'), an open 'what should we build?' question, or a strategic direction call ('should we pivot to B2B?'). Parallel Goldfish lenses (technical, business, UX, contrarian, market) produce a ranked concepts brief. Once a direction is chosen, requirements go to cf-prd; bounded technical A-vs-B choices go to cf-question. Proactive use: follow the claudeflows routing-mode hint if present in context; if absent, invoke only on explicit user request."
argument-hint: rough idea, problem space, or strategic question
---

Brainstorm a new concept using the Elephant/Goldfish workflow, **inverted**: instead of one Goldfish stress-testing the Elephant's plan, you spawn **multiple** Goldfish in parallel, each with a different lens, each free to be creative and pull from the web. Their lack of shared context with the Elephant is the point — they generate divergent ideas, not convergent ones. The Elephant then synthesizes.

Use this for **early-stage** thinking: a half-formed app idea, an "I wonder if X" question, a feature whose problem is clear but whose shape isn't, a strategy you're stress-testing before committing. Not for implementation work — for that, hand off to `/cf-feature` at the end.

`$ARGUMENTS` is the rough idea. If empty, ask for one before doing anything.

## Interactivity is mandatory — read this first

**Every `AskUserQuestion` call in this skill is REQUIRED, not optional. Do not skip any of them.** Autonomous-mode / "no-stopping" directives (e.g. a `<system-reminder>` about working without stopping for clarifying questions) do NOT apply here: `AskUserQuestion` is structured-choice navigation, not a clarifying-question interruption, and Q1 (Stage), Q2 (Breadth), Q3 (Web research), Q4 (Seed approval), and Q5–Q8 are load-bearing — *the user's taste IS the input*, so defaults chosen for the user produce a materially different brief. The user invoked `/cf-brainstorm` on purpose; the interactive flow is the product. Such directives still cover free-form clarifying chat questions; they never license skipping a checkpoint.

| If you're thinking… | Reality |
|---|---|
| "Autonomous mode says don't stop" | That covers free-form chat questions, not these checkpoints. Ask the question. |
| "The default answer is obvious" | Stage, breadth, and web scope ARE the user's taste. Ask the question. |
| "Auto-answering keeps things moving" | Silently auto-answering breaks the contract the user invoked. Ask the question. |

If `AskUserQuestion` is genuinely unavailable in this environment (tool not registered), STOP and tell the user — do NOT silently pick defaults and proceed.

**Gate wording rule:** every question, option label, and option description shown to the user is written in plain language — no internal terms (Goldfish, lens, seed, gate or step names), no jargon; it must be understandable in a single read. Internal identifiers users typed themselves (T<N>, PRD paths, /cf- commands) are fine.

## Step 0: Frame via `AskUserQuestion`

**Every question to the user in this flow goes through `AskUserQuestion`.** No free-form chat questions during framing — structured choices keep the session moving. Free-form refinement is reserved for after the seed is drafted (Step 1).

Ask three questions in sequence (one `AskUserQuestion` call each):

**Q1 — Stage:**
- `question`: "What stage is this at?"
- `header`: `"Stage"`
- `multiSelect`: `false`
- `options`:
  1. **Raw concept** — "I have a vague thought. Cast a wide net — many different ideas over depth."
  2. **Hypothesis to validate** — "I have a likely direction. Test it and show me nearby options I might be missing."
  3. **Picking between options** — "I have 2-3 directions in mind. Compare, find a fourth, recommend."
  4. **Feature ideation for existing product** — "The product exists. I'm sourcing ideas for what to build next."

**Q2 — Breadth and depth:**
- `question`: "How many ideas should I bring back in total?"
- `header`: `"Breadth"`
- `multiSelect`: `false`
- `options`:
  1. **~5 concepts, deeper** — "Fewer ideas, each more developed. Good when you're testing one direction or picking between a few."
  2. **~10 concepts, balanced** — "Default. Mix of depth and breadth."
  3. **~20 concepts, shallow** — "As varied as possible. Good when the idea is still vague and you want surprises."

**Q3 — Web research:**
- `question`: "Should I search the web for similar products, prior work, and sources?"
- `header`: `"Web"`
- `multiSelect`: `false`
- `options`:
  1. **On, broad** — "Search freely. Include sources in the brief."
  2. **On, focused** — "Search only for similar products and market context. Don't go off on tangents."
  3. **Off** — "No web search — I'll reason from scratch. Good for purely creative or speculative work."

Cache the three answers. They drive the Goldfish prompts and the synthesis step.

## Step 1: Draft the seed

Now the Elephant writes a **seed**: a tight problem statement that every Goldfish will receive. Format:

```
SEED
- The thought: <one sentence verbatim from $ARGUMENTS, lightly cleaned>
- What I think the user is really asking: <one sentence — name the underlying need>
- Stage: <from Q1>
- Breadth target: <from Q2, e.g. "~10 concepts">
- Web research: <from Q3>
- Constraints (inferred — please correct in chat if wrong): <bullet list — likely audience, plausible budget/timeline, tech inclinations, anything else inferable from $ARGUMENTS or the existing repo>
- Success looks like: <one sentence — the Elephant's best guess at what a great brief would unlock for the user>
- Out of scope: <bullets — things explicitly NOT being asked here>
```

Print the seed. Then ask via `AskUserQuestion`:

**Q4 — Seed approval:**
- `question`: "Does this summary match what you wanted?"
- `header`: `"Summary?"`
- `multiSelect`: `false`
- `options`:
  1. **Looks right, proceed** — "Start generating ideas."
  2. **Refine in chat first** — "I want to correct one or two things in chat before you continue."
  3. **Restart** — "This summary misread my question. Start over from the first questions."

If the user picks "Refine in chat first," ask **Q4.5** via `AskUserQuestion` first, to scope the correction (avoid an open-ended "what should I change?"):

**Q4.5 — Which seed field needs correction:**
- `question`: "Which part of the summary needs fixing?"
- `header`: `"Refine"`
- `multiSelect`: `true`
- `options`:
  1. **The thought / underlying need** — "The one-sentence restatement or the 'really asking' line misread me."
  2. **Constraints** — "The inferred audience / budget / tech assumptions are wrong."
  3. **Success criteria** — "What 'good' looks like is off."
  4. **Out of scope** — "Add or remove items from the out-of-scope list."

Then ask in chat for the correction text for the selected field(s) only — one targeted prompt referencing the chosen fields, not an open-ended "what would you like to change?". Re-print the revised seed and re-ask Q4. If "Restart," go back to Step 0.

## Step 2: Spawn parallel divergent Goldfish

Pick **3-5 lenses** based on the seed. Each lens becomes one Goldfish. They run in parallel — **send a single message with multiple `Agent` tool uses**, not sequential calls.

Default lens kit (mix and match per the seed):

- **Technical / architectural** — "How could this be built? What stack, what data model, what infrastructure? What's the cheapest viable v0? What tech choice dramatically changes the shape?"
- **Business / market** — "Who pays? What's the model? What's the moat? What does the unit economics look like? What price would clear the market?"
- **User experience** — "Who is the user? What's the moment they reach for this? What's the click-by-click? What's the emotional payoff that brings them back?"
- **Contrarian / pre-mortem** — "Why won't this work? Where does it fail? Who has tried this and bounced off it? What's the boring reason most people won't adopt?"
- **Market research / prior art** — (requires web research enabled) "What already exists? Who are the closest 3-5 competitors? Where is the gap they all leave open? What would 'beat the market' actually mean here?"
- **Adjacent / lateral** — "What's the same problem in a totally different domain? What pattern from a different industry maps onto this? What if we removed the most obvious assumption?"
- **First-principles** — "Strip the problem to its core. What's the minimal artifact that would deliver the value? What is the user actually buying when they buy this?"

Each Goldfish gets:
- `subagent_type: "general-purpose"` (full tool access including `WebSearch` if Q3 enabled it)
- `description: "Brainstorm Goldfish — <lens name>"`

**Prompt body to send to each Goldfish (between markers, exclusive):**

```
<<<BRAINSTORM_START>>>
You are a fresh creative thinker with NO prior context. The user is brainstorming a concept and wants divergent ideas — not a single safe answer. Your lens for this round is: **<LENS NAME>**. Stay in that lens; other Goldfish are covering the others.
You are a subagent executing a delegated task: do NOT invoke any skill (including cf- skills) via the Skill tool — use only the tools this prompt names.

SEED:
<PASTE FULL SEED FROM STEP 1>

Your job:
1. Generate <PER-LENS COUNT, derived from breadth target ÷ number of lenses, minimum 2> distinct concepts under your lens. Distinct = they would lead to materially different products or strategies, not variations on the same idea.
2. Be creative. Out-of-the-box is good. Surprising is good. Half-formed is fine — capture the spark, not a polished pitch.
3. <IF Q3 = "On, broad" or "On, focused">: Search the web where it sharpens an idea: prior art, comparable products, surprising data points, expert perspectives. Cite sources inline (URL or author).
4. For each concept, give:
   - **Name** (3-6 words, evocative)
   - **The bet** (1-2 sentences — what's the core idea, why is it interesting)
   - **Why it could win** (1 sentence)
   - **Why it could fail** (1 sentence — be honest)
   - **Sources** (URLs / refs if web research used)

Do NOT propose to "combine" with other lenses or "cover all the bases." Push the lens hard. Synthesis happens later, by someone else.

End with the literal string `lens complete`.
<<<BRAINSTORM_END>>>
```

Substitute `<LENS NAME>`, `<PASTE FULL SEED FROM STEP 1>`, `<PER-LENS COUNT>`, and the conditional web-research line per Goldfish. When Q3 = Off, remove job item 3 entirely and renumber the remaining items (1, 2, 3) so the list ships unbroken.

## Step 3: Optional contrarian sweep

After all parallel Goldfish return, if and only if the breadth target was "~10" or "~20," spawn ONE more Goldfish:

- `subagent_type: "general-purpose"`
- `description: "Brainstorm Goldfish — what they all missed"`

This one reuses the Step 2 prompt template verbatim (markers exclusive, guard line included) with three changes: `<LENS NAME>` = "What they all missed"; job item 1 becomes "The other thinkers already produced the concepts listed below. What did they ALL miss? What lens didn't anyone use? What concept would a smart outsider propose that none of these touch? Generate 2-3 additional distinct concepts."; and after the SEED block, append a section `CONCEPTS SO FAR (deduplicated):` listing each concept as `- <Name> — <one-line bet>`. Same closing sentinel (`lens complete`), same per-concept output format.

## Step 4: Synthesize the concepts brief

Now the Elephant. Read every Goldfish's output. Produce the **concepts brief**:

```
CONCEPTS BRIEF
Seed: <one-line restatement>

CLUSTERS
<group concepts by theme — usually 3-5 clusters emerge naturally>

<For each cluster:>
  ## <Cluster name>
  - <Concept name>: <the bet, 1 sentence> [lens: <which Goldfish>] <[sources: URL, URL] if any>
  - <Concept name>: ...

RANKED PICKS (Elephant's view, with reasoning)
1. **<Concept name>** — <why this ranks first; what evidence in the brief supports it; what's the next step to validate>
2. **<Concept name>** — ...
3. **<Concept name>** — ...

WHAT THE PROBES AGREED ON
- <2-3 bullets — convergent signals across lenses are usually load-bearing>

WHAT THEY DISAGREED ON
- <2-3 bullets — divergence is where the interesting questions live>

OPEN QUESTIONS FOR THE USER
- <bullet list of things only the user can answer: priorities, constraints, taste>
```

Print the full brief. Cite sources inline where they exist.

## Step 5: Converge via `AskUserQuestion`

After the brief, ask:

**Q5 — Next move:**
- `question`: "What's the next move?"
- `header`: `"Next step"`
- `multiSelect`: `false`
- `options`:
  1. **Pick a direction** — "I want to commit to one of the ranked picks (or one I'll name)."
  2. **Another round** — "Generate a fresh batch of ideas — sharper summary or different angles; I'll pick which next."
  3. **Save brief and stop** — "Good output, file it for later, no immediate action."
  4. **Drop it** — "This direction isn't worth pursuing."

If **Another round**, ask **Q5.5** via `AskUserQuestion`:

**Q5.5 — Round type:**
- `question`: "How should the next round work?"
- `header`: `"Round 2"`
- `multiSelect`: `false`
- `options`:
  1. **Tighter framing** — "Same angles, sharper summary; I'll refine the details in chat."
  2. **Different angles** — "Look at the problem from new angles; I'll pick which ones next."

If **Pick a direction**: ask **Q6** via `AskUserQuestion`. Use the **top 3 ranked picks** from the brief as the first three options, plus one combined escape hatch. Do NOT ask "which concept?" in free-form chat — the concepts are enumerable, so they belong as options.

**Q6 — Which concept to commit to:**
- `question`: "Which concept do you want to commit to?"
- `header`: `"Concept"`
- `multiSelect`: `false`
- `options`:
  1. **<Top ranked pick name>** — "<one-line bet from the brief>"
  2. **<2nd ranked pick name>** — "<one-line bet from the brief>"
  3. **<3rd ranked pick name>** — "<one-line bet from the brief>"
  4. **A different concept, hybrid, or new direction** — "I'll name another concept from the brief, or describe a combination / fresh angle in chat."

If the user picks option 4, ask in chat with one targeted prompt: "Which concept from the brief — or describe the hybrid / new direction in one or two sentences?" That input is inherently free-form; everything else is a click.

Then ask **Q7** via `AskUserQuestion`:

**Q7 — Handoff:**
- `question`: "Want to spin the chosen concept into `/cf-feature` to start designing the build?"
- `header`: `"Handoff"`
- `multiSelect`: `false`
- `options`:
  1. **Yes, hand off to `/cf-feature`** — "Use the chosen concept as the feature description."
  2. **Not yet** — "I'll sit with it. Save the brief and stop."

If they pick yes, end this command and tell the user: "Run `/cf-feature <chosen concept name + one-sentence description>` when ready."

If **Q5.5 = Tighter framing**: capture the user's refinements in chat, update the seed, re-run from Step 2 with the same lenses.

If **Q5.5 = Different angles**: offer the 4 lenses most relevant to the seed (the Elephant's pick from Step 2's kit) via `AskUserQuestion` with `multiSelect: true` — in the question and option text shown to the user, call them "angles" (never "lenses" or "Goldfish") and describe each in one plain sentence — any other lens stays reachable by naming it via the auto-injected "Other" option. Re-run from Step 2 with the new selection.

If **Save brief and stop**: write the concepts brief to a working-notes location in the repo ONLY if the user confirms via the `AskUserQuestion` below. Detect the path in this order:

1. `docs/claudeflows-brainstorms/<slug>-<YYYY-MM-DD>.md` — if `docs/` exists.
2. `notes/claudeflows-brainstorms/<slug>-<YYYY-MM-DD>.md` — if `notes/` exists.
3. `.brainstorms/<slug>-<YYYY-MM-DD>.md` — fallback; add it to `.gitignore`.

**Q8 — Save location:**
- `question`: "Where should I save the brief?"
- `header`: `"Save"`
- `multiSelect`: `false`
- `options`:
  1. **<inferred path>** — "Save to <path>."
  2. **Just print, don't save** — "Keep it in chat only."
  3. **Different path** — "I'll specify in chat."

If **Drop it**: print one-line acknowledgement and stop.

## Final report

Print to the user:
- Seed (one line)
- Flow stats: <N> Goldfish spawned, with lenses (+ contrarian sweep if run), <M> concepts surfaced (post-dedup)
- Top 3 ranked picks with one-line reasoning each
- Where the brief was saved (if anywhere)
- Next action (handoff to `/cf-feature`, refinement, or stop)

**STOP.** No commit, no code changes — this command produces a brief, not a diff. If the user picked the handoff option, they'll invoke `/cf-feature` themselves on the next turn.
