---
name: cf-mode
description: "Set or show how claudeflows routes plain-language requests into /cf- flows. Modes: auto (announce and invoke the matching flow), suggest (offer the flow in one line, run only on consent — the default), off (flows run only via explicit /cf-* commands). Writes .claudeflows/mode in the current directory. Invoke when the user runs /cf-mode or asks to change, quiet, or disable claudeflows auto-routing."
argument-hint: "auto | suggest | off (no argument shows the current mode)"
---

Set the claudeflows routing mode for this project, or report it. This skill is small and mechanical — no subagents, no questions beyond what is specified here.

## How the mode is resolved (highest wins)

1. `CLAUDEFLOWS_MODE` environment variable
2. `.claudeflows/mode` file in the directory Claude was started from (one word: `auto`, `suggest`, or `off`)
3. Legacy opt-out: `CLAUDEFLOWS_QUIET=1` or an empty `.claudeflows/quiet` file → `off`
4. Default: `suggest`

What each mode means (this is what the `SessionStart` routing hint injects):

- **auto** — when a request clearly matches a flow, announce it and invoke the skill.
- **suggest** (default) — offer the matching flow in one short line and invoke only if the user agrees; a decline is not re-offered in the same session.
- **off** — no proactive routing at all; flows run only via explicit `/cf-*` commands.

In every mode, explicit `/cf-*` invocations work unchanged, and flows are never offered for follow-up turns inside work already in progress, trivial edits, or directly answerable questions.

## Steps

1. **Resolve the current mode** using the precedence above (check the env var, then read `.claudeflows/mode`, then the legacy quiet markers).

2. **No argument** → report the current mode, where it comes from (env var, mode file, legacy quiet marker, or default), and the three options with one-line meanings. Stop — do not change anything.

3. **Argument given** → it must be exactly `auto`, `suggest`, or `off` (case-insensitive). Anything else: say it is not a valid mode, list the options, stop.

4. **Apply**: write the mode word as the sole content of `.claudeflows/mode` (create the `.claudeflows/` directory if needed; no trailing whitespace). If a legacy `.claudeflows/quiet` file exists, delete it — the mode file supersedes it.

5. **Warn on overrides**: if `CLAUDEFLOWS_MODE` is set in the environment, tell the user it takes precedence over the file they just wrote, so the change will not take effect until they unset it.

6. **Adopt immediately**: the injected hint text refreshes only at the next session start, so from this point in the current session, follow the newly set mode yourself — it supersedes whatever routing hint was injected earlier.

7. **Confirm** in one or two lines: the new mode, what behavior to expect, and a suggestion to add `.claudeflows/` to the repo's `.gitignore` if it is not already ignored (check, don't assume).
