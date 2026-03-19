# GitHub Playbook (Current Project State)

## Branches in Use

- `main`: stable/release branch
- `develop`: integration branch
- `feature/brick-offline-first`: offline-first + scanner convergence work
- `feature/data-layer-supabase`: earlier data-layer iteration
- `feature/wire-ui-to-data`: scanner/data wiring iteration

## Daily Flow (Recommended)

1. Update local references:
```bash
git fetch origin
```

2. Start from integration baseline:
```bash
git checkout develop
git pull origin develop
```

3. Create or continue feature branch:
```bash
git checkout -b feature/<task-name>
# or
git checkout feature/<existing-name>
```

4. Commit clearly:
```bash
git add .
git commit -m "feat(scan): add qr lookup fallback handling"
```

5. Push and open PR:
```bash
git push -u origin feature/<task-name>
```

## Handling Divergence Between Feature Branches

Because functionality was developed in multiple branches, compare and reconcile before PR:

```bash
git checkout feature/brick-offline-first
git fetch origin
git merge origin/develop
# or selectively cherry-pick commits from another feature branch
git cherry-pick <commit-sha>
```

Use a conflict strategy that preserves:
- Brick repository and entity model architecture
- latest scanner behavior and history flow

## PR Strategy for This Repo

Preferred merge path:
1. `feature/*` -> `develop`
2. `develop` -> `main`

PR checklist:
- `dart analyze` has no errors
- `flutter pub get` succeeds
- Brick generated files present in `lib/brick/`
- on-device scan and artifact retrieval validated
- scan history add/view/clear validated

## Useful Commands

Inspect branch graph:
```bash
git log --oneline --decorate --graph --all -n 30
```

See local changes:
```bash
git status --short
git diff --name-only
```

See files changed relative to develop:
```bash
git diff --name-only origin/develop...HEAD
```
