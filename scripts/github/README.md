# GitHub Board Setup Scripts

Run these three scripts **once** after creating the PharmaDesk GitHub repository to populate the full Kanban board.

## Prerequisites

- [GitHub CLI](https://cli.github.com/) installed
- Authenticated: `gh auth login`

## Order of execution

```bash
export REPO=your-github-username/PharmaDesk
export START_DATE=2026-06-09   # first day of Week 1 (adjust to your actual start)

# 1. Labels — run first (issues reference labels)
bash scripts/github/create-labels.sh

# 2. Milestones — run second (issues reference milestones)
bash scripts/github/create-milestones.sh

# 3. Issues — run last (references both labels and milestones)
bash scripts/github/create-issues.sh
```

## What gets created

| Script | Creates |
|---|---|
| `create-labels.sh` | 26 labels across Priority, Module, Type, Phase, Status groups |
| `create-milestones.sh` | 10 milestones spanning the 17-week delivery roadmap |
| `create-issues.sh` | 46 issues — 42 RTM entries + 4 infra/NFR issues |

## After running

1. Go to `https://github.com/$REPO/projects` and create a new **Board** project
2. Name it `PharmaDesk — Development`
3. Add columns: **Backlog → Ready → In Progress → In Review → Done**
4. Import all open issues into the board
5. Enable **Workflows** → auto-move to Done when issue is closed
6. Switch to **Roadmap** view and set start/end dates from milestones for the Gantt view
