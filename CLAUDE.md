# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Full GDD (source of truth for design decisions): https://claude.ai/artifact/Qg8dwB6UmtbsKyv3XSEWWe — this file is a technical summary, not a replacement.

## Project

Solo top-down management/combat hybrid (Moonlighter, Cult of the Lamb inspirations), built for a 2-day, 2-person game jam. Scope must stay minimal — check the MVP list below before adding anything not explicitly requested.

**Core mechanic:** number of carried tomatoes = player's lives in the dungeon. An unharvested ripe tomato becomes a villager wandering the camp (same entity, two states: carried = life, planted/grown = villager). No life cap — overkill is intentional.

## Stack

- Godot 4.7.2, GL Compatibility renderer
- GDScript, typed where practical (`var hp: int`, `func heal(amount: int) -> void`)
- No C# unless explicitly needed (nothing in scope requires it)

## Running

No build step, no automated tests. Open the project in Godot 4.7 and press F5, or `godot4 --path .` if the CLI binary is available. `run/main_scene` in `project.godot` points at `scenes/main/main.tscn`.

## Current state vs. target architecture

The project is still bootstrap-stage — only player movement exists, no camp/dungeon/UI yet.

- `scenes/player/player.gd` — the only gameplay script so far. `CharacterBody2D`, 8-direction movement via `Input.get_vector("move_left", "move_right", "move_up", "move_down")` (actions mapped to WASD/arrows in `project.godot`'s `[input]` section), plus a dash (action `dash`, Shift/Space): direction locks in at dash start (current input, or last move direction if none held), speed/duration/cooldown are `@export`ed. Wall/obstacle collision is handled by `move_and_slide()` against `StaticBody2D` — don't write custom collision logic.
- `scenes/main/main.tscn` — a test arena (walls, one obstacle, noise-textured ground), not the real Camp or Dungeon scene. Expect it to be replaced.

Target structure to converge toward as real content lands (don't mass-reorganize existing files to match it preemptively — align new files to it instead):

```
scenes/{camp,dungeon,ui}/
scripts/{autoload,entities,systems}/
assets/{sprites,audio}/
resources/        # .tres: card/enemy definitions etc.
```

## Autoloads (not yet implemented, per GDD)

- **GameState** — persistent cross-scene state: carried tomatoes (lives), plot count, per-plot growth state, villager list (incl. special roles Farmer Tomato / Blacksmith Tomato), resources (gold, craft materials), unlocked card tiers.
- **SceneRouter** — handles Camp ↔ Prep ↔ Dungeon ↔ Summary ↔ Card-choice transitions.

Avoid direct cross-scene references (`get_node("../../Other")`) — use signals or GameState instead.

## Mechanics summary (full detail in GDD)

- **Camp = safe zone**, no threats. 4 tomato plots at start, timer-based growth (2-3 min), click to harvest.
- Growth beyond a natural cap requires dungeon-sourced materials to speed up or expand plots (passive anti-farm, no active punishment).
- **Dungeon**: one fixed room for MVP, 1-2 enemy types, top-down real-time combat. Getting hit = lose a tomato. 0 tomatoes = death, return to camp. Tomatoes lost in the dungeon are gone permanently (enemies never drop tomatoes/seeds).
- **Villagers**: Farmer Tomato (auto-harvest), Blacksmith Tomato (crafts from loot), rest are decorative with no function.
- **Card system** (Rounds-like): at cumulative tomato thresholds (20/50/100...), player picks 1 of 3 random cards (Combat / Management / Agility categories). Open questions live in the GDD.

## MVP (must work, 2 days, 2 people)

1. Movement + attack in one fixed dungeon room, 1-2 basic enemies.
2. Lives-as-tomatoes working (lose on contact, death at 0, return to camp).
3. Camp: 4 plots, timer growth, click to harvest.
4. Unharvested ripe tomato → villager spawns (visual only, no role).
5. Full playable loop: camp → dungeon (1 room) → return → camp.

Suggested split: one person on dungeon/combat, one on camp/management, to parallelize.

**Out of scope unless there's spare time:** working Farmer/Blacksmith roles, a second room, plot expansion, the card system, sound beyond 1-2 essential effects, save between sessions, options/settings.

## Code conventions

- `snake_case` for variables/functions, `PascalCase` for class/script/node names.
- Signals named in past tense (`tomato_harvested`, `life_lost`), not imperative.
- One script per scene root node; no gameplay logic in UI scripts — UI observes GameState via signals, never mutates state directly.
- Comments in English.

## Working in this repo

- Check this file and the GDD before implementing a mechanic whose exact value (growth time, damage, etc.) isn't fixed yet — unchecked boxes in the GDD's "Open questions" mean the decision is still pending: propose a reasonable value rather than blocking, but flag it.
- Don't add functionality outside the MVP unless explicitly asked — scope is intentionally tight.
