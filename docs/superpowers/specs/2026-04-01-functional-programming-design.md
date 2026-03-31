# Functional Programming Rule - Design Spec

## Goal

Add a Claude Code rule that enforces functional programming patterns and prohibits object-oriented patterns across all generated code, regardless of language.

## Scope

- Applies to all code in all languages
- Strict by default, with a pragmatic escape hatch for framework-mandated classes

## Design

### Rule File

`.claude/rules/functional-programming.md` containing layered "NEVER" rules (per `rule-style.md`):

1. **No classes** — NEVER use classes when functions suffice. Framework-required classes must be thin wrappers with logic extracted into pure functions.
2. **No mutable state** — NEVER use mutable state. Prefer const, readonly, frozen objects, immutable data structures.
3. **No inheritance** — NEVER use inheritance. Use composition and higher-order functions.
4. **No impure core logic** — NEVER write methods with side effects without isolating them at the boundary. Keep core logic pure.
5. **No imperative loops** — NEVER use imperative loops when declarative alternatives exist (map, filter, reduce, flatMap).

### Approach Chosen

Layered rules with escape hatch (Option C) — strict FP discipline with a single pragmatic concession for framework requirements. Preferred over a hard ban (too rigid) or categorized rules (too heavy for one concept).
