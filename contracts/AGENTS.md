---
id: contracts-agents
title: Contracts — Component-Centric Contract System
kind: agents
status: active
created: 2026-08-14
updated: 2026-08-17
---

# Contracts — Component-Centric Contract System

## Map {#map}

- [Purpose](#purpose) — contract + journal pair model
- [Structure](#structure) — what files live here and their roles
- [Contract index](#contract-index) — list of component contracts
- [Change cycle](#change-cycle) — the episode workflow with its audit passes (RULE-audit-pass)
- [Operational rules](#rules) — how to create, amend, and maintain contracts
- [Naming conventions](#naming) — file and item-ID naming
- [Adaptation notes](#adaptation) — differences from the parent harness (`~/dev/qoder-skills`)

## Purpose {#purpose}

This directory contains permanent, component-centric Design Contracts. Each component is described by a pair of files: a contract and its journal.

- The **contract** is the homogenized present-tense specification of the component: the single normative source, carrying no version markers. **MUST** — the contract is exhaustive enough that `statusline-command.sh` can be recreated from it practically as-is. The script is the runtime render of the contract; the contract leads.
- The **journal** is the provenance ledger: change episodes with their intent, corrections, and the technical chronicle. The journal has no normative force.

Model inherited from the parent harness `~/dev/qoder-skills` (`contracts/AGENTS.md` there), which itself adapts the flagship repo `tgwizard`; this repo adapts it further to a single-component project. The link to the parent harness is procedural, not referential: a hash pin plus a periodic adaptation check (`harness-check.sh`), declared in the root `AGENTS.md`.

- **MAY** — prose content may be written in Russian (the working language of this repo and of the parent harness).
- **MUST** — LLM markup structure (frontmatter fields, anchors, item IDs, section names) remains in English.

## Structure {#structure}

Every file in this directory is one of: (a) this AGENTS.md index, (b) a component contract (`<component>.md`), or (c) a component journal (`<component>-journal.md`). No BACKLOG file exists by construction: the contract system was installed together with the component, and a new component may not exist without a contract; agreed refactor proposals live as Risks/Q&A entries in the component contract (precedent: QA-1) or as `analysis/` research, not in a separate store.

- **AGENTS.md role** — single entry point: contract index, status, and operational rules.
- **Contract role** — homogenized current specification. Required body sections: Map, Purpose, Invariants, Specification, Acceptance gates, Risks, Q&A. The contract carries a pointer to its journal (Map and frontmatter `refs`). No Scope sections, no History, no Implementation status, no version markers: normative deltas are folded into the body at change time (see the change cycle), and their record lives in the journal.
- **Journal role** — provenance ledger, strictly non-normative: the script is never edited from a journal entry. Content: episodes (`EP-N`) carrying delta intent and the list of touched clauses, correction entries, audit-pass records (findings and their disposition), and the chronicle (`CHANGE-*`). Episode status: `pending → implemented | cancelled`; only the status field mutates, the intent text never does (inline supersession pointers inside migrated intent text, e.g. `*(Superseded: EP-N…)*`, are read-only annotations, not mutations). The journal is created together with the contract: for a new component it starts with `EP-1 (status: pending)` carrying the designed specification, rendered into the script and marked `implemented` in the same creation commit; for a backfilled component `EP-1` carries the snapshot of the current state.
- **Reconstruction** — the contract alone is the current truth; no derivation from deltas is ever required to read or edit the component.
- `analysis/*.md` holds research artifacts; contracts reference them via `refs` frontmatter and inline links. Research is not normative; a contract clause is.
- **Boundary** — repo-level mechanics (sync, runtime deploy, hooks, release flow, parent-harness pin) never belong in a component's Specification: the component is harness-deployment-neutral, and repo-level mechanics live in the root `AGENTS.md` and `README.md`. Acceptance gates MAY carry repo mechanics of the change procedure (sync/push/status checks). The parent's boundary exception for `release-skills` (repo mechanics as its user-visible capability, user-confirmed in the parent repo) does not apply here: no component of this repo has repo mechanics as its capability (see the adaptation research).

## Contract index {#contract-index}

One line per contract: description and contract status. No scope tails.

- **IDX-1** — [statusline.md](statusline.md) — Qoder CLI status line: single POSIX-sh script rendering one compact line (model + context window, ctx % used, live subagent counter, git working-tree diff, branch, path) with graceful degradation, incremental transcript cache, and byte-exact ANSI output. Status: active.

## Change cycle {#change-cycle}

One change episode:

1. Design the delta.
2. Record it as journal episode `EP-N (status: pending)` — intent text plus the list of touched clauses.
3. Homogenize: fold the delta into the contract per RULE-homogenization (draft → independent bidirectional reconciliation → classify residuals → iterate until zero unclassified residuals).
4. Audit the contract draft per RULE-audit-pass: an independent audit-prompts pass by a separate agent; objective defects are fixed or accepted with a recorded decision; outcome and dispositions go to the journal.
5. Optional: journal corrections discovered while folding or auditing.
6. Edit `statusline-command.sh` per the contract only, then `./sync.sh push` so that `./sync.sh status` is clean.
7. Audit the rendered script per RULE-audit-pass (the render is a new artifact and may carry defects the contract lacks); optionally refine the contract if implementation diverged — any deviation from the episode intent is recorded as a correction entry in the journal.
8. Episode status → `implemented`.

- Creation of a new component follows the same episode shape, in one commit: contract (designed specification) + journal starting with `EP-1 (pending)` + IDX line here + the artifact per the contract + sync + the RULE-audit-pass audits; `EP-1` is marked `implemented` in that commit. For a backfill, the audit runs on the snapshot and never silently edits it: findings are accepted (recorded) or open the next episode once EP-1 is closed.
- One episode = one commit (journal + contract + artifact + sync), made after the episode status is `implemented` — the render audit of step 7 runs before the commit. No push mid-episode.
- Invariant: the contract is never behind the code — it equals it or leads it.

## Operational rules {#rules}

- **RULE-contract-monopoly** — normative force belongs to the contract alone. The script is edited per the contract only; a journal entry is never the source for a code edit.
- **RULE-one-contract-per-component** — one contract + one journal per component: `contracts/<component>.md` and `contracts/<component>-journal.md`. A change episode never gets its own contract file; it is recorded as an episode in the component's journal and folded into the contract.
- **RULE-contract-first** — a component is never edited without its contract + journal pair: the episode cycle above is the only way a component change happens, and a component without a pair first receives a backfill contract (snapshot of the current state) + journal approved by the user. There is no trivial-wording bypass.
- **RULE-reconstructability** — the contract carries the component's full normative content as the homogenized present. If the script and the contract disagree, the contract is amended in the same change that resolves the disagreement; silent drift is a defect.
- **RULE-homogenization** — folding a delta into the contract is iterative: draft from (contract + delta); independent bidirectional reconciliation by a separate pass/agent (every clause of the source has an image in the draft; every clause of the draft has a source); each residual classified as (a) folding error → fix, (b) editorial integration → journal note, (c) contract gap or contradiction → options to the user, decision recorded in the journal. Stop when zero unclassified residuals remain. Minimal executable form: a fresh re-read of the contract and the delta without relying on the draft; a separate subagent when available. A class (c) residual arising without user access leaves the episode `pending` with the unresolved residuals enumerated until the user decides. Migration of a legacy delta chain is one fold of the full chain; residuals in class (c) are questions about the current state only.
- **RULE-audit-pass** — a contract draft and the script rendered from it pass an independent audit by a separate agent: the methodology of the `audit-prompts` skill; where that skill is unavailable, an equivalent LLM-text audit per its methodology. When the audited component encodes executable mechanics (commands, paths, sync/hook behavior — as this repo's component does), the render pass additionally applies the `audit-code` methodology for mechanical fidelity. Findings are objective defects only (evidence, consequence, proposed change, confidence); stylistic preferences are not findings. Iteration follows the skill's re-audit cap: fix → re-audit; if that re-audit changes the text, at most one further pass, then apply its fixes and stop — final fixes are accepted without another pass. The pass closes when zero objective defects remain or the remaining ones are accepted by the user with a recorded decision; an unresolved defect without user access leaves the episode `pending` with the defect enumerated. Pass outcomes and residual dispositions are recorded in the journal (episode body and/or chronicle). Minimal executable form for tiny deltas (wording-only, single-clause): a fresh independent re-read of the changed sections with their immediate context instead of a full pass; a separate subagent when available. For a backfill episode the audit runs on the snapshot and never silently edits it: findings are accepted with a recorded decision or, unresolved without user access, leave the episode `pending` with the defect enumerated; agreed fixes open the next episode once this one is closed.
- **RULE-journal-additive** — journal entries are added; of an existing entry only the status field mutates; deviations, cancellations, and late corrections are new entries referencing the original.
- **RULE-pending-single** — a journal holds at most one pending episode. A session that finds a pending episode first completes or cancels it (cancellation is a correction entry referencing the episode); no new episode is opened until the pending one is closed.
- **RULE-episode-numbering** — `EP-1`, `EP-2`, ... strict sequential integers per journal. Never reuse, never delete.
- **RULE-gate** — acceptance criteria are contract clauses (`GATE-N`); their pass/fail outcomes are recorded in the journal — in the implementing episode body (`GATE-N: pass|fail — <grounds>`) and/or the chronicle. Gate numbering is sequential, never reused, never deleted. Gates for future episodes are worded generically (what is checked on any change of the kind), so the acceptance section does not accumulate vacuous criteria.
- **RULE-invariant-supersession** — an `INV-N` may be revised when it no longer describes the active component. Keep its identifier stable; the prior wording and the rationale live in the journal episode or correction.
- **RULE-provenance** — the contract carries no provenance links to its change lineage (the journal pointer as pair-member is not provenance). Each episode lists the contract clauses it touches (INV, GATE, RISK, QA, Specification sections); a clause's lineage is reconstructed by searching its ID in the journal. The contract keeps a digest of settled decisions (rejected alternatives included) in Risks/Q&A.
- **RULE-contract-gate** — the pre-push hook fails a push when the component artifact lacks `contracts/<component>.md`, `contracts/<component>-journal.md`, or an IDX line here. There is no backlog mechanism: the system started with the component covered, and a new component may not be added to any backlog list (see RULE-contract-first).
- **RULE-obsolescence** — when a component is removed, its contract, journal, IDX line, and README line are removed in the same change; git history carries the archive. No tombstones.
- **RULE-cross-refs** — a change touching several contracts updates all of them; link contracts and `analysis/` files with Markdown links.

## Naming conventions {#naming}

- **File naming** — contract: `contracts/<component>.md`; journal: `contracts/<component>-journal.md` (kebab-case). The component name is the established term for the user-visible capability (`statusline`), not necessarily the artifact file name (`statusline-command.sh`); the artifact ↔ contract mapping is listed in the pre-push hook's `OBJECTS`.
- **Section anchors** — contract: `#map`, `#purpose`, `#invariants`, `#specification`, `#gates`, `#risks`, `#qa`; journal: `#episodes`, `#chronicle`.
- **Item IDs** — line-start IDs: `INV-N`, `GATE-N`, `RISK-N`, `QA-N` (contract); `EP-N` (journal episodes); `CHANGE-YYYY-MM-DD-<tag>` (chronicle).
- **Contract frontmatter** — `id`, `title`, `kind: contract`, `status`, `created`, `updated`, `owners`, `refs` (journal link included). No content-version field.
- **Journal frontmatter** — `id`, `title`, `kind: journal`, `contract` (pointer to the contract), `created`, `updated`.
- **Q&A entries** — carry either `Decision:` (accepted or rejected, with date and confirmation) or `Status: open|resolved|rejected`; one scheme per entry, consistent within the contract.

## Adaptation notes {#adaptation}

Differences from the parent harness `~/dev/qoder-skills`, deliberate (adaptation without reduction):

- **Object boundary** — a contract boundary is one component (the status line, artifact `statusline-command.sh`), matching the parent's one-contract-per-skill feature-boundary rule. There are no skill directories and no naming model for skills; the parent's naming-model section does not apply here.
- **Artifact ↔ contract mapping** — the parent maps skill directory name → contract file name 1:1; here the mapping is declared in the pre-push hook (`OBJECTS`) because the artifact is a root-level file whose stem differs from the component name.
- **No BACKLOG** — the parent's hook carries a backlog of pre-contract-system skills; here the contract system predates any component edit, so the backlog mechanism is absent by construction (RULE-contract-gate). The parent's `contracts/BACKLOG.md` (a store of agreed refactor proposals) is likewise absent: open questions live in the component contract's Risks/Q&A (precedent: QA-1) — see the adaptation research.
- **No release-skills boundary exception** — the parent's user-confirmed exception (repo mechanics as the skill's user-visible capability) has no object here: no component of this repo has repo mechanics as its capability.
- **RULE-contract-first retained** — the parent operationalizes contract-first through the episode cycle; this repo keeps the rule under its established name because the public text (`README.md`, «contract-first cycle») uses the term and `contracts/statusline.md` (RISK-2) references the rule name.
- **RULE-obsolescence aligned with the parent** — the tombstone variant (contract kept as `status: superseded`) adopted on 2026-08-14 is superseded by the parent's canonical rule: removal removes contract, journal, IDX line, and README line in the same change; git history archives (see the adaptation research).
- **Backfill without a research file** — the baseline was backfilled by code inspection of the existing script (no external research existed to record); the research requirement applies to design changes going forward (harness-adaptation research itself is [../analysis/2026-08-14-harness-adaptation-research.md](../analysis/2026-08-14-harness-adaptation-research.md)).
- **No application version, no sprints** — inherited from the parent: the chronicle is keyed by date (`CHANGE-YYYY-MM-DD-<tag>`), and no release versioning exists.
- **Reconstructability over brevity** — the Specification **MUST** carry the full component specification (behavior-level: segments, formats, colors, thresholds, fallbacks, caching algorithm), so contracts are as long as reconstruction requires. Terse-chronicle discipline still applies.
