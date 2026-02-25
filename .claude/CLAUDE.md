# Personal Preferences

## Code Style

- Don't add types, interfaces, or abstractions unless they're used in 3+ places
- Don't create wrapper files (barrels, re-exports) unless asked
- Prefer inline strings over enum constants
- No type casts
- Extract when it hurts, not when it might — generalize out of necessity, not speculation
- Existing code is not sacred — refactor it when it makes the new requirement simpler instead of building around it

## Workflow

- Show the approach in 3 bullets before writing code on architecture/refactor tasks
- Produce output quickly — don't spend rounds exploring without delivering something concrete
- When in a git worktree, run all commands (lint, test, build) from the worktree directory

## Git

- Don't commit or push unless explicitly told to
- Don't amend unless explicitly told to
