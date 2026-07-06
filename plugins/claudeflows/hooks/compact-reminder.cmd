:; [ -n "$CLAUDEFLOWS_QUIET" ] && exit 0; [ -f .claudeflows/quiet ] && exit 0; echo "claudeflows: a context compaction just occurred. If a /cf- skill is mid-flight, re-Read its SKILL.md (and any reference file it loaded) before executing the next step. Never reproduce a template, sentinel, or gate spec from memory."; exit 0
@echo off
if defined CLAUDEFLOWS_QUIET exit /b 0
if exist .claudeflows\quiet exit /b 0
echo claudeflows: a context compaction just occurred. If a /cf- skill is mid-flight, re-Read its SKILL.md (and any reference file it loaded) before executing the next step. Never reproduce a template, sentinel, or gate spec from memory.
