# AGENTS.md

Guidance for **Cursor agents** working in [sql-gym](https://github.com/mikael-lh/sql-gym).

## Product (not specced yet)

sql-gym will be a SQL practice app: problems on real datasets, query execution, deterministic grading, optional AI hints. **Scope and stack are not finalized** until `prd/00-product-vision.md` exists.

Do **not** implement application features, choose frameworks, or invent requirements until that document is written and linked from [prd/README.md](prd/README.md).

## Development workflow (required)

Full playbook: [docs/WORKFLOW.md](docs/WORKFLOW.md).

| Source | Owns |
|--------|------|
| `prd/` + ChatPRD | Requirements, phases, acceptance criteria |
| Linear | Tasks, status, priorities |
| GitHub | Code, PRs, review |

### Before coding

1. Read [prd/README.md](prd/README.md) for the active phase.
2. Read the relevant `prd/phase-*.md` or ChatPRD doc linked there.
3. If the user provides a Linear issue (e.g. `GYM-12`), follow its acceptance criteria only.

### Planning

- New phase or large epic: propose a milestone plan (files + order) and wait for approval.
- Do not start work on a later phase while the active phase in `prd/README.md` is incomplete unless the user explicitly overrides.

### Implementation (when approved)

- **Grading must be deterministic** (e.g. result-set comparison). Do not use an LLM for pass/fail.
- Document PRD deviations in the PR description, not only in chat.

### Before opening or updating a PR

- Run quality checks defined in this repo (add commands here as the stack is chosen).
- Verify acceptance criteria from the Linear issue / PRD section.
- PR title should include the Linear issue ID when applicable (e.g. `GYM-12: Add DuckDB seed loader`).

### After a phase ships

- Remind the human to run **update-prd** (ChatPRD skill) and close the Linear phase epic.

## Secrets

No secrets are committed. When the app is built, document required env vars in `.env.example`. On Cursor Cloud VMs, ask the user to add secrets in Cursor Cloud settings — do not assume local `.env` files exist.

## ChatPRD skills (when the user asks)

| Intent | Skill |
|--------|--------|
| Write or expand specs | write-prd |
| Plan implementation from a PRD | implement-from-prd |
| Pre-merge requirement check | check-prd-alignment |
| Record what shipped vs spec | update-prd |
