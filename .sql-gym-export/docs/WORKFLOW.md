# Development workflow

sql-gym uses **ChatPRD + `prd/` + Linear + GitHub**. This document is the playbook; [AGENTS.md](../AGENTS.md) is the short agent-facing summary.

## Tool roles

| Tool | Owns |
|------|------|
| **ChatPRD** | Authoritative specs; optional cloud copy |
| **`prd/`** (in repo) | Committed specs agents and humans read |
| **Linear** | Backlog, cycles, issue status, priorities |
| **GitHub** | Code, branches, PRs, CI |

Do not duplicate full PRD text in Linear issues — link `prd/…` and list acceptance criteria.

## Phased delivery (outline only)

Phases will be defined in `prd/00-product-vision.md` after requirements gathering. Expected shape (names and scope **TBD**):

| Phase | Typical focus |
|-------|----------------|
| 0 | Sample data, problem format, CLI or API grading |
| 1 | Web UI: editor, run, deterministic grade |
| 2 | AI hints (e.g. local Ollama) |
| 3 | Problem generator + concept/difficulty filters |
| 4 | Hosting, limits, optional warehouse connection |

Update [prd/README.md](../prd/README.md) when phases are approved.

## End-to-end flow

```text
1. write-prd
   → ChatPRD + prd/00-product-vision.md
   → prd/phase-N-….md for the active phase only

2. implement-from-prd
   → Milestone plan (files, order, risks) → user approves

3. Linear
   → Parent epic per phase; child issues from milestones
   → Labels: phase-N, area:*, type:feature|spike|chore

4. Code + GitHub PR
   → Branch: cursor/<desc>-0eb3 or feature/GYM-NN-<desc>
   → PR title: GYM-NN: <summary>

5. check-prd-alignment (before merge)

6. update-prd + close Linear issues; deferrals → PRD "Future work"
```

## Linear conventions

- **Project:** sql-gym (or your team’s equivalent)
- **Epic:** one parent issue per phase (e.g. `Phase 0 – Data & grading`)
- **Issue title:** `Phase N | Short title`
- **Issue body template:**

  ```markdown
  **PRD:** prd/phase-N-….md § "<section>"
  **Acceptance criteria**
  - [ ] …
  **Out of scope**
  - …
  ```

## GitHub conventions

- **Default branch:** `main`
- **PRs:** use [.github/pull_request_template.md](../.github/pull_request_template.md)
- **Done:** merged PR + Linear issue closed + PRD updated if scope changed

## Agent session prompts (examples)

```text
Requirements pass: help draft prd/00-product-vision.md; ask clarifying questions first.
```

```text
Working on Linear GYM-42. Read prd/phase-1-….md § "Run SQL". Follow docs/WORKFLOW.md.
Propose a plan before editing files.
```

```text
PR ready for GYM-42: run tests, check-prd-alignment against prd/phase-1-….md.
```

## ChatPRD plugin

Enable the ChatPRD Cursor plugin for this repo. Skills: `write-prd`, `implement-from-prd`, `check-prd-alignment`, `update-prd`.

## What agents must not do

- Invent product requirements or mark phases complete without PRD updates
- Use an LLM to decide pass/fail on SQL answers
- Expand scope beyond the active Linear issue / PRD section without user approval
