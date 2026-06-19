# profiles/general/hooks/

General Claude Code hooks that apply to all profiles.

## Propagation contract

On `devos install` or `devos sync`, hooks from this directory are copied to `.dev-os/hooks/`. They take lower precedence than profile-specific hooks.

Hook precedence (highest first):
1. `.claude/hooks/` — project-local overrides
2. `profiles/default/hooks/` — default profile hooks (project-specific; apply per `devos install`)
3. `profiles/general/hooks/` — general hooks (this dir; apply to all profiles)
4. `scripts/hooks/` — git hooks and CI scripts (not Claude Code hooks)

## Adding a hook

1. Write the hook script in this directory.
2. Use `#!/usr/bin/env bash` shebang.
3. Exit 0 always for observation hooks; non-zero to block for gate hooks.
4. Run `devos sync` to propagate to `.dev-os/hooks/`.
