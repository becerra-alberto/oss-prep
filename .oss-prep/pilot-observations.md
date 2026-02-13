# oss-prep Pilot Observations

Mock run target: oss-prep itself (`~/Tools/oss-prep`)

## Phase 0: Reconnaissance

1. **Initiation unclear** — Wasn't sure how to start oss-prep. User should be guided through invocation, not dropped into validation checks cold.
2. **No progress indicator** — No sense of what step I'm on or how many remain. User needs a visible phase tracker / progress bar.
3. **Data dump without context** — Presented with project profile data without explanation of why it matters or what decisions it informs.
4. **Not using AskUserQuestion** — Claude Code has a structured question UI (AskUserQuestion tool) but the orchestrator uses plain text prompts instead. Worse UX.
5. **Phase 0 too passive** — Recon should be inquisitive: ask about goals, propose paths, surface choices. Not just state facts and assume the user understands the implications.
6. **Messy initial flow** — Startup validation, state init, and phase entry blend together. Needs cleaner separation and structure so the user knows what's happening at each stage.

## Phase 1: Secrets & Credentials Audit

7. **Why not parallel phases?** — Phases 1 (Secrets), 2 (PII), and 3 (Dependencies) are independent scans. They could run concurrently to save time. The sequential gating adds wait time without adding value for non-blocking phases.
8. **Discovery without suggestions** — Findings are well-grounded but stop at "here's what we found." Need actionable suggestions: what to do, how hard it is, and whether the tool can auto-fix it.
9. **No visual signal for "all clear"** — When everything is fine (4 low, zero real secrets), that good news should be celebrated / made obvious. Instead it reads like a wall of findings that happen to be low. Need better UI to distinguish "clean scan" from "problems found."
10. **No effort/scale indicator on findings** — Each finding should communicate effort to remediate (auto-fixable, 5-min manual fix, requires decision, etc.) so the user can gauge the work ahead.

## Phase 2: PII Audit

11. **Hard to parse what was reviewed** — The PII audit covers 8 categories but results are a wall of text. Need a summary table showing each category, its status (clean/findings), risk level, and suggested action at a glance.
12. **Effort column unclear if tracked** — When the summary says a finding has "effort: auto-resolved at Phase 8," it's unclear whether that becomes a tracked action item or just informational text the user has to remember. Findings with deferred remediation should be explicitly recorded as pending actions in state.
