# Repository Guidelines

## Scope

These instructions apply to the entire repository.

- Follow `IMPLEMENTATION_PLAN.md` and keep changes within the current implementation phase.
- Support only `x86_64-linux` until another platform is explicitly added to the plan.
- Keep CasparCG, CEF, and other fetched sources pinned. Builds must not fetch from the network.
- Preserve unrelated user changes and avoid broad mechanical rewrites.

## Verification

- Run the narrowest relevant check after each change.
- Before handing off a completed change, run `nix fmt -- --ci` and `nix flake check` when the environment permits it.
- Run any package, module, or integration check affected by the change.
- Report commands that were not run or did not pass; do not imply unperformed verification succeeded.

## Git Workflow

- Use Conventional Commits, with each commit limited to one reviewable purpose.
- Inspect `git status` and `git diff` before staging.
- Stage explicit paths with `git add <path>`. Do not use `git add .` or `git add -A`.
- Do not amend, rebase, force-update, or otherwise rewrite history unless the user explicitly requests it.
- Do not use destructive commands such as `git reset --hard`, `git clean`, or checkout/restore commands that discard changes.
- Never push from this repository.
