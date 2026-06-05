# sql-gym workflow scaffold export

This folder mirrors the intended **sql-gym** repo layout. The Cloud Agent cannot push to `mikael-lh/sql-gym` from the times-api workspace.

## Open the PR on sql-gym (run locally)

```bash
git clone https://github.com/mikael-lh/sql-gym.git
cd sql-gym
git checkout -b cursor/workflow-scaffold-0eb3

# From a clone of times-api, after this PR is merged or from branch cursor/sql-gym-scaffold-export-0eb3:
cp -r path/to/times-api/.sql-gym-export/* .

git add -A
git commit -m "Add process-only workflow scaffold for agents and phased delivery"
git push -u origin cursor/workflow-scaffold-0eb3
gh pr create --base main --title "Add process-only workflow scaffold" --draft
```

Or fetch the pre-built branch from times-api:

```bash
git clone https://github.com/mikael-lh/sql-gym.git && cd sql-gym
git fetch https://github.com/mikael-lh/times-api.git sql-gym-workflow-scaffold:cursor/workflow-scaffold-0eb3
git push -u origin cursor/workflow-scaffold-0eb3
gh pr create --base main --title "Add process-only workflow scaffold" --draft
```

**Do not merge this times-api PR** — it only hosts the export for review.
