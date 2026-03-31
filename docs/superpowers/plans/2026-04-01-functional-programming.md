# Functional Programming Rule Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Claude Code rule enforcing functional programming patterns and prohibiting OOP patterns.

**Architecture:** Single rule file in `.claude/rules/` following the existing NEVER-phrased convention from `rule-style.md`.

**Tech Stack:** Markdown rule file for Claude Code.

---

### Task 1: Create the functional programming rule file

**Files:**
- Create: `.claude/rules/functional-programming.md`

**Step 1: Create the rule file**

```markdown
# Functional Programming

- NEVER use classes when a plain function or module of functions will do. If a framework requires a class, keep it as a thin wrapper and extract all logic into pure functions.
- NEVER use mutable state. Prefer `const`, `readonly`, frozen objects, and immutable data structures.
- NEVER use inheritance. Use composition and higher-order functions instead.
- NEVER write methods with side effects without isolating them at the boundary. Keep core logic as pure functions.
- NEVER use imperative loops (`for`, `while`) when a declarative alternative exists (`map`, `filter`, `reduce`, `flatMap`, etc.).
```

**Step 2: Verify the file renders correctly**

Run: `cat .claude/rules/functional-programming.md`
Expected: The rule content above, properly formatted.

**Step 3: Commit**

```bash
git add .claude/rules/functional-programming.md
git commit -m "feat: add functional programming rule"
```

### Task 2: Push and open draft PR

**Step 1: Push**

```bash
git push
```

**Step 2: Open draft PR**

```bash
gh pr create --draft --title "feat: add functional programming rule" --body "$(cat <<'EOF'
## Summary
- Adds `.claude/rules/functional-programming.md` enforcing FP patterns
- Prohibits classes (unless framework-required), mutable state, inheritance, impure core logic, and imperative loops
- Follows existing NEVER-phrased rule convention

## Test plan
- [ ] Verify rule file exists at `.claude/rules/functional-programming.md`
- [ ] Verify rules follow NEVER convention from `rule-style.md`
- [ ] Start a new Claude Code session and verify the rule is picked up

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
