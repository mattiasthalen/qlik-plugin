# Statusline Path + Branch Decisions

## Decision 1: Extend Existing Script vs Separate Scripts

**Context:** Adding path and git branch display to statusline. Script is ~60 lines, will grow to ~90.

**Options considered:**
- **A) Extend existing `statusline.sh`** *(chosen)* — Add path+branch logic to same script. Keeps single file, simple execution, easy to test as unit.
- **B) Separate `gitinfo.sh` script** — Separation of concerns, independently testable. But adds orchestration overhead and two files for a simple statusline. *Rejected.*
- **C) Inline commands in settings.json** — No script files needed. Unmaintainable, untestable. *Rejected.*

**Decision:** Extend existing script. Not enough complexity to justify splitting. Single file is easier to template across repos.

## Decision 2: Path Display Format

**Context:** Statusline needs to show where Claude is working. Could be project root or a git worktree.

**Options considered:**
- **A) Full relative path** (e.g., `primer/.worktrees/feat/my-feature`) — Verbose, eats statusline space. *Rejected.*
- **B) Basename + worktree name** *(chosen)* (e.g., `primer > my-feature`) — Compact, shows both project identity and worktree context. Arrow separator is clear.
- **C) Leaf directory only** (e.g., `my-feature`) — Loses project context. *Rejected.*

**Decision:** `basename > worktree-basename` when in worktree, plain `basename` otherwise. Detected by comparing `git rev-parse --show-toplevel` with project root.

## Decision 3: Git Status Indicator Format

**Context:** Need to show branch name plus dirty/untracked/ahead/behind state.

**Options considered:**
- **A) Compact inline** (e.g., `feat/thing *+2-1`) — Dense, `+`/`-` can be confused with diff context. *Rejected.*
- **B) Arrows for ahead/behind** *(chosen)* (e.g., `feat/thing *! ↑2 ↓1`) — Unicode arrows are unambiguous. `*` for dirty, `!` for untracked. Omit each indicator when clean/zero.

**Decision:** Arrow format. `*` dirty, `!` untracked, `↑N` ahead, `↓N` behind. Each omitted when not applicable.

## Decision 4: Portability Fixes

**Context:** Statusline renders as `Opus 4 6[1m]` on some systems due to `echo -e` and awk differences.

**Options considered:**
- **A) Keep `echo -e` and debug per-system** — Whack-a-mole across shells. *Rejected.*
- **B) Use `printf '%b\n'` and simplify model name parsing** *(chosen)* — `printf %b` is POSIX-portable for escape interpretation. Simpler sed chain avoids mawk/gawk divergence.

**Decision:** Replace `echo -e` with `printf '%b\n'`. Simplify awk model parser to sed-only chain. Fix both bugs in same pass.
