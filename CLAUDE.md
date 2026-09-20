# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Full GDD (source of truth for design decisions): https://claude.ai/artifact/Qg8dwB6UmtbsKyv3XSEWWe — this file is a technical summary, not a replacement. See also `ARCHITECTURE.md` for file-layout/scene/class conventions — this file covers what's built and the big-picture patterns; ARCHITECTURE.md covers the "how."

## Project

Solo top-down management/combat hybrid (Moonlighter, Cult of the Lamb inspirations), built for a 2-day, 2-person game jam. Scope must stay minimal — check the MVP list below before adding anything not explicitly requested.

**Core mechanic:** number of carried tomatoes = player's lives in the dungeon. A villager wandering the camp *is* a life (harvesting a ripe plot spawns a villager and grants a life in the same step — there's no separate "carried tomato" pickup step). No life cap — overkill is intentional.

## Stack

- Godot 4.7.2, GL Compatibility renderer
- GDScript, typed where practical (`var hp: int`, `func heal(amount: int) -> void`)
- No C# unless explicitly needed (nothing in scope requires it)

## Running

No build step, no automated tests. Open the project in Godot 4.7 and press F5 (starts at Camp, `run/main_scene` in `project.godot` → `scenes/main/main.tscn`), or `godot4 --path .` if the CLI binary is available. To iterate on the dungeon/combat in isolation without walking there from Camp, open `scenes/dungeon/dungeon.tscn` directly and press F6 ("run current scene").

## Architecture

Both Camp (`scenes/main/main.tscn`) and Dungeon (`scenes/dungeon/dungeon.tscn`) exist and are connected: `SceneRouter` owns every scene transition, triggered by walking up to a `SceneTransitionPoint` interactable and pressing E. Dying (`GameState.player_died`, at 0 tomatoes) auto-routes back to Camp and resets the run.

**Autoloads**: `GameState` (persistent state — tomatoes/lives, a generic item inventory, plots, villagers), `SceneRouter` (scene transitions, listens for death), `DisplayManager` (fullscreen toggle only, no other responsibility).

**The `Behavior`/`BehaviorHost` composition framework is the dominant pattern in this codebase** — most gameplay objects are built from it, so it's worth understanding before touching any entity:
- `Behavior` (`scripts/components/behavior.gd`) is the base class; a `BehaviorHost` (`scripts/components/behavior_host.gd`) holds `Behavior` children and `broadcast(event_name, payload)`s named events to them.
- `InteractableComponent` (an `Area2D`) detects the `"player"` group in range and broadcasts `player_in_range` / `player_out_of_range` / `interacted` (E-press) to its own `Host`.
- Generic, entity-agnostic behaviors (`OutlineBehavior`, `PromptBehavior`) just react to those events and work on anything.
- Entity-specific behaviors reuse the exact same mechanism for their own logic: `PlotBehavior` (camp plot state machine: `EMPTY → SEEDED → GROWING → RIPE`), `ContainerBehavior`/`GiveItemBehavior` (loot), `SceneTransitionBehavior`.
- `Enemy` drives the same `BehaviorHost` for a different, recurring event instead of one-shot interactions: it broadcasts `physics_tick` (with `delta`) every physics frame, so enemy movement and attack AI are themselves swappable `Behavior`s (see below) rather than hardcoded per enemy type.
- **Pattern for adding a new interactable or enemy type**: instance a shared *base* scene (`scenes/components/interactable.tscn`, `scenes/dungeon/enemy_base.tscn`) and drop the desired `Behavior` children under its `Host` — no new code. Existing variants: `shop.tscn`, `container.tscn`, `plot.tscn`, `scene_transition_point.tscn` (Interactable-based); `enemy_slime/imp/brute/charger/archer.tscn` (Enemy-based).

**Combat** (`scripts/components/{health,hurtbox,hitbox}_component.gd`): `HurtboxComponent` (`Area2D`) just re-emits `damage_taken`; `HitboxComponent` (`Area2D`) deals its `damage` to any `HurtboxComponent` it overlaps; `HealthComponent` tracks HP and emits `died`. Collision layers: `1` = physics bodies (walls, default — also where the player's own `CharacterBody2D` sits), `4` = player hurtbox, `8` = enemy hurtbox — each side's Hitbox sets `collision_mask` to the *other* side's hurtbox layer. Camp's walls/obstacle also carry layer `2` (`collision_layer = 3`, i.e. `1|2`) so `Villager` — on its own layer `16`, `collision_mask = 2` — clamps to walls without colliding with the player or other villagers.

**Enemy AI is two independent, swappable `Behavior` slots** dropped under `enemy_base.tscn`'s `Host`: a movement behavior (`ChaseMovementBehavior`, `KiteMovementBehavior`) and an attack behavior (`ContactAttackBehavior`, `MeleeAttackBehavior`, `DashAttackBehavior`, `RangedAttackBehavior`). They coordinate through small shared state on `Enemy` itself (`player`, `movement_locked`) — an attack behavior sets `movement_locked` while it owns `velocity` for a swing/dash burst, so movement and attack behaviors never fight over it.

**Data vs. resources** (per ARCHITECTURE.md's split, now populated): `scripts/data/{item_data,enemy_data,loot_entry}.gd` are schemas; `resources/{items,enemies}/*.tres` are the instances.

**UI reads `GameState` via signals**, per convention — with one deliberate exception: `scenes/ui/shop_menu.gd` calls `GameState.remove_item`/`add_item` directly on a purchase click, rather than routing through a signal to some other system. This was a pragmatic jam-speed call, not an oversight — know it's there before assuming the "UI never mutates state" rule is absolute.

**Villagers** — `scenes/main/main.gd` instances a `Villager` (`scenes/entities/villager.tscn`, `scripts/entities/villager.gd`) wherever `GameState.villager_spawned` fires. `Villager` is a `CharacterBody2D` with a self-contained idle/wander state machine (no `Behavior`/`BehaviorHost`, since it has no interaction or attack logic to compose) — random direction, random timers, clamped to camp bounds by ordinary wall collision like Player/Enemy. Still visual only, no role (matches MVP scope).

## Mechanics summary (full detail in GDD)

- **Camp = safe zone**, no threats. 4 tomato plots at start, timer-based growth (2-3 min), harvest by interacting with a ripe plot.
- Plot placement via a grid-snapped placement cursor (key G), spending gold, is implemented. (Materials-based crafting/growth-speedup was cut as out of scope — plots and the Breeding House are gold-only purchases now.)
- **Dungeon**: one fixed room, 5 enemy variants across the 4 attack archetypes (contact, melee, dash, ranged). Getting hit = lose a tomato. 0 tomatoes = death, return to camp. Tomatoes lost in the dungeon are gone permanently (enemies never drop tomatoes/seeds).
- **Villagers**: Farmer Tomato (auto-harvest), Blacksmith Tomato (crafts from loot), rest are decorative with no function — none of the special roles are implemented yet.
- **Card system** (Rounds-like): at cumulative tomato thresholds (20/50/100...), player picks 1 of 3 random cards (Combat / Management / Agility categories). Open questions live in the GDD. Not implemented.

## MVP (must work, 2 days, 2 people)

1. Movement + attack in one fixed dungeon room, 1-2 basic enemies. — **done** (5 enemy variants)
2. Lives-as-tomatoes working (lose on contact, death at 0, return to camp). — **done**
3. Camp: 4 plots, timer growth, click to harvest. — **done** (harvest is E-press, not click — see Architecture)
4. Unharvested ripe tomato → villager spawns (visual only, no role). — **done**, in the simplified "villager = life" form described above
5. Full playable loop: camp → dungeon (1 room) → return → camp. — **done**

**Out of scope unless there's spare time:** working Farmer/Blacksmith roles, a second room, the card system, sound beyond 1-2 essential effects, save between sessions, options/settings. (Plot expansion was originally in this list but has since been built.)

## Code conventions

- `snake_case` for variables/functions, `PascalCase` for class/script/node names.
- Signals named in past tense (`tomato_harvested`, `life_lost`), not imperative.
- One script per scene root node; UI observes GameState via signals rather than mutating it directly (see the shop_menu exception above).
- Comments in English.

## Working in this repo

- Check this file and the GDD before implementing a mechanic whose exact value (growth time, damage, etc.) isn't fixed yet — unchecked boxes in the GDD's "Open questions" mean the decision is still pending: propose a reasonable value rather than blocking, but flag it.
- Don't add functionality outside the MVP unless explicitly asked — scope is intentionally tight.
- Before hand-writing detection/state/UI-toggle logic for a new interactable or enemy type, check whether composing existing `Behavior`s onto the relevant base scene already gets you there.
