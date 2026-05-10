---
name: cf-question
description: Answer a question with a fast parallel Goldfish sweep — read-only, no clarifying prompts, no code changes
argument-hint: a question, "how does X work?", "what does Y do?", "should I A or B?"
disable-model-invocation: true
---

Answer a question using the Elephant/Goldfish pattern, **lite**: spawn 2-3 Goldfish in parallel, each on a narrow lane, synthesize a tight answer. The aim is a fast, well-grounded reply — not a brief, not a plan, not a diff.

Use this when the user wants an **answer**, not an artifact: a "how does this work?", a "what's the difference between X and Y?", a "should I do A or B?", a "where does this live in the codebase?". For early-stage divergent thinking use `/cf-brainstorm`; for requirements use `/cf-prd`; for code changes use `/cf-feature` or `/cf-bug`.

`$ARGUMENTS` is the question. If empty, ask once for one in chat (a single short prompt — not `AskUserQuestion`) and stop until the user replies.

## Hard rules

- **No `AskUserQuestion` calls.** This command does not interrogate the user. If the question is ambiguous, pick the most plausible reading, state it in one line at the top of the answer ("Reading this as: …"), and proceed. The user can correct in chat on the next turn.
- **Read-only.** No `Edit`, no `Write`, no `Bash` commands that mutate state, no commits, no PRs, no file creation, no saving the answer to disk. If the user later asks to save, that's a separate turn.
- **Fast.** One Goldfish wave, no second wave, no contrarian sweep. Total wall time should feel like a quick lookup, not a research project.
- **Cite.** When the answer rests on a file, give `path:line`. When it rests on the web, give the URL. Unsourced claims are fine for general knowledge but flag them as such ("from background knowledge, not verified here").

## Step 1: Classify the question (silent)

Pick exactly one shape. This drives lens selection and whether web search is on.

- **Codebase question** — "where is X?", "how does Y work in this repo?", "what does Z do?". Goldfish read the repo. Web off by default.
- **Conceptual / how-to** — "how does OAuth PKCE work?", "what's the difference between mutex and semaphore?". Web on, focused. Repo not relevant.
- **Decision / comparison** — "should I use Redis or Postgres for this?", "Vitest vs Jest for this stack?". Web on for prior art; repo on if the decision is repo-specific (check manifests).
- **Mixed** — both repo grounding and external context matter (e.g. "how should we add rate limiting given our current setup?"). Both lanes on.

Do not print the classification — just use it.

## Step 2: Spawn 2-3 parallel Goldfish

Pick lenses to match the shape. Send a **single message with multiple `Agent` tool uses** so the Goldfish run in parallel.

Default lens kits per shape:

- **Codebase**: 2 Goldfish — one **locator** (`subagent_type: "Explore"`) for the most relevant `path:line` citations; one **explainer** (`subagent_type: "general-purpose"`) for how the code actually flows.
- **Conceptual**: 2 Goldfish — one **primary** (authoritative explanation, web search on); one **counterpoint** (common misconceptions, edge cases, or "what people get wrong here", web search on).
- **Decision**: 3 Goldfish — **option A advocate**, **option B advocate**, **pragmatist** (what the repo / context actually constrains; reads manifests if relevant).
- **Mixed**: 3 Goldfish — one **codebase locator** (Explore), one **external research** (general-purpose, web on), one **synthesist** (general-purpose, gets both lanes' job in miniature so you have a cross-cutting perspective).

If the question is genuinely tiny and a single Goldfish is enough (e.g. "what file defines X?"), use one. Default is two; three only when the shape demands it.

Each Goldfish gets:
- `description: "Question Goldfish — <lens name>"`
- The full `$ARGUMENTS` verbatim
- Its lens, in one sentence
- An instruction to be brief: **3-8 bullets max**, with citations
- A hard read-only constraint: no file edits, no shell mutations, no `Bash` beyond read-only commands like `git log`, `cat`, `rg`, `ls`, `gh issue view`. Web search allowed per shape.
- The literal closing string `answer ready` so you know it finished

**Prompt body to send to each Goldfish (between markers, exclusive):**

```
<<<QUESTION_START>>>
You are a fresh agent with NO prior context. The user asked a question and you are one of 2-3 parallel Goldfish answering it. Stay in your lane.

USER QUESTION (verbatim):
<PASTE $ARGUMENTS>

YOUR LENS: <LENS NAME — one sentence describing what to focus on>

Constraints:
- Read-only. No file edits, no shell mutations, no commits. Web search is <ON / OFF per shape>.
- Be brief: 3-8 bullets total. Each bullet ≤2 sentences.
- Cite. For repo claims: `path:line`. For web claims: URL. For background knowledge: prefix with "(unverified)".
- Do not propose next steps, do not write a plan, do not produce code. Just answer the lens.

End with the literal string `answer ready`.
<<<QUESTION_END>>>
```

Substitute `<LENS NAME>` and the web-search ON/OFF flag per Goldfish.

## Step 3: Synthesize the answer

Read every Goldfish output. The Elephant produces the answer in this shape — keep it tight:

```
ANSWER

<If the question was ambiguous: "Reading this as: <one-line interpretation>". Otherwise omit.>

<2-5 sentence direct answer to the question. Lead with the conclusion. No preamble.>

KEY POINTS
- <bullet 1 — with citation if applicable>
- <bullet 2 — with citation>
- <bullet 3 — with citation>
- <bullet 4 — optional>
- <bullet 5 — optional>

<If shape was "Decision":>
RECOMMENDATION
- <one line — which option, and the single load-bearing reason>

<If lenses disagreed materially:>
WHERE THE LENSES DISAGREED
- <one or two bullets — the disagreement is itself useful signal>

SOURCES
- <path:line or URL>
- <path:line or URL>
```

Length budget: the whole printed answer is **under 250 words** for codebase / conceptual / mixed shapes, **under 400 words** for decision shapes. If you blow the budget, you're writing a brief — cut.

## Step 4: Stop

No `AskUserQuestion`. No "want me to dig deeper?" footer. No "should I save this?". The user reads the answer and replies if they want more.

If the answer hits a wall (e.g. all Goldfish came back empty, or the question genuinely cannot be answered without more info), say so plainly in one sentence at the end and name the single piece of missing information that would unblock you. Do not list five clarifying questions.

**STOP.** No commit, no file writes, no follow-up prompts.
