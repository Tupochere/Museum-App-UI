# Git Branch Workflow (Main + Dev + Feature Branches)

This workflow keeps history clean and avoids force-push on shared branches.

## Branch Model

- `main`
  - Production-ready code only.
  - Protected branch (no direct commits if possible).
- `dev`
  - Integration branch for completed features.
  - Staging area before `main`.
- `feature/<short-name>`
  - One branch per task (UI update, bug fix, etc).

Examples:
- `feature/scan-states`
- `feature/ticket-wallet-ui`
- `feature/events-details-screen`

## One-Time Setup

Run in repo root:

```bash
git checkout -b dev
git push -u origin dev
```

Then on GitHub:
1. Protect `main` (and optionally `dev`).
2. Require Pull Request for merge.

## Daily Workflow

### 1) Start from latest `dev`

```bash
git checkout dev
git pull
```

### 2) Create a feature branch

```bash
git checkout -b feature/<your-feature-name>
```

### 3) Work and commit

```bash
git add .
git commit -m "feat: short clear message"
```

### 4) Push feature branch

```bash
git push -u origin feature/<your-feature-name>
```

### 5) Open Pull Request

- PR: `feature/<name>` -> `dev`
- Get review, merge to `dev`.

### 6) Release to production

- PR: `dev` -> `main`
- Merge only when tested.

## Sync Existing Feature Branch with Dev

Use rebase to keep history linear:

```bash
git checkout dev
git pull
git checkout feature/<your-feature-name>
git rebase dev
```

If rebase conflicts:
1. Resolve files.
2. `git add <file>`
3. `git rebase --continue`

Then push updated feature branch:

```bash
git push --force-with-lease
```

`--force-with-lease` is safe for your own feature branch.  
Do not use force push on `main` or `dev`.

## Rules to Avoid Future Git Problems

1. Never commit directly to `main`.
2. Avoid force push on shared branches (`main`, `dev`).
3. Always pull latest `dev` before creating feature branch.
4. Keep PRs small and focused.
5. Delete merged feature branches.

## Useful Commands

Check status:

```bash
git status
git branch -vv
```

Clean merged local branches:

```bash
git branch --merged dev
```

Delete local feature branch:

```bash
git branch -d feature/<your-feature-name>
```

Delete remote feature branch:

```bash
git push origin --delete feature/<your-feature-name>
```
