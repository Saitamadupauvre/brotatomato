# Architecture

Conventions for file layout, scene composition, and class/resource design in this project. Design decisions (mechanics, values) live in the GDD; this file is about *how code and scenes are structured*, not *what the game does*. See [When to deviate](#when-to-deviate) before treating anything here as a hard rule — this is jam code, not a shipped engine.

## Core principle: dependency direction

Everything below is one idea applied repeatedly: **dependencies point inward, toward data, never sideways between peers.**

```
UI  ──reads──▶  GameState  ◀──writes──  Gameplay (dungeon, camp)
 │                  │
 └──never calls───▶ │
                     ▼
              (signals fan out to whoever's listening)

Entities  ──never reference──▶  other sibling Entities directly
Entities  ──emit signals / mutate GameState──▶  which fans out
```

If you're about to write `get_node("../../Something")`, `get_parent().get_parent()`, or have `Enemy` directly poke `Player.hp -= 1`, stop — that's a sideways dependency and it's the #1 way a 2-person jam codebase turns into merge-conflict soup by day 2. Every cross-object interaction in this project goes through one of: **signals, GameState, groups, or the SceneRouter.** No exceptions, because exceptions are exactly what stops scaling past 2 scenes.

## File architecture

```
res://
  scenes/
    camp/            # Camp.tscn and sub-scenes (plot, villager, buildings)
    dungeon/         # Dungeon.tscn, rooms, enemies
    ui/               # HUD, transition screens, card-choice screen
    shared/           # scenes reused across camp+dungeon (pickup VFX, floating text)
  scripts/
    autoload/         # singletons: GameState, SceneRouter, EventBus (see below)
    entities/         # player, enemies, villager, tomato — behavior scripts
    components/        # reusable node-attachable behavior: HealthComponent, HitboxComponent, HurtboxComponent
    systems/           # card system, economy/resources, wave spawner
    data/              # class_name Resource *definitions* (EnemyData, CardData) — the schema, not the instances
  resources/            # .tres *instances* of the data/ schemas: goblin.tres, fireball_card.tres
  assets/
    sprites/
    audio/
```

Rules:
- **`scripts/data/` vs `resources/` is a hard split.** `data/enemy_data.gd` defines the `EnemyData` class (schema + defaults). `resources/enemies/goblin.tres` is one instance of it, edited entirely in the inspector. Nobody hand-edits a `.tres` as text, and nobody puts gameplay logic in `data/` beyond trivial computed getters (`get_dps() -> float: return damage / attack_cooldown`).
- **`components/` holds behavior meant to be reused by composition**, not inheritance — a `HealthComponent.tscn` gets instanced as a child of both `Player.tscn` and `Enemy.tscn`. See [Scene architecture](#scene-architecture).
- A scene's script lives next to its `.tscn` only when it's genuinely scene-specific glue (rare — e.g. `Dungeon.tscn`'s own root script coordinating room state). Reusable entity logic goes in `scripts/entities/`, referenced by the scene via the Script field.
- Don't reorganize existing files to match this layout preemptively (see CLAUDE.md) — align new files to it as they're written. `scenes/player/player.gd` staying where it is until there's a second entity to justify moving it is fine.

## Scene architecture

- **One script per scene root node.** Child nodes get scripts only if they have independent behavior (a hitbox with its own `Area2D` logic); pure visual/structural children don't.

- **Composition over scene-inheritance.** Build `Enemy.tscn` as a `CharacterBody2D` with `HealthComponent.tscn`, `HitboxComponent.tscn`, `HurtboxComponent.tscn` as instanced children, instead of a `Enemy → FlyingEnemy → BossEnemy` scene-inheritance chain (`Ctrl+Shift+I` "Inherit"). Scene inheritance in Godot is a binary diff nightmare in git — two people editing an inherited chain in parallel is close to guaranteed conflict. Composition means new enemy types are built by dragging component scenes into a new `CharacterBody2D`, no shared ancestor to conflict over.

  A component talks to its owner through a narrow contract, not a hard type reference:
  ```gdscript
  # scripts/components/hurtbox_component.gd
  class_name HurtboxComponent
  extends Area2D

  signal damage_taken(amount: int)

  func take_damage(amount: int) -> void:
      damage_taken.emit(amount)
  ```
  The owning `Enemy`/`Player` script connects `hurtbox.damage_taken` to its own `_on_damage_taken`, and decides what "taking damage" means for it (lose HP, lose a tomato, whatever). The component never assumes who its parent is.

- **UI never touches gameplay state directly.** UI scenes/scripts read from `GameState` and listen to its signals; they never call `GameState.tomatoes -= 1` themselves. Gameplay code (dungeon hit detection, camp harvest click) is what mutates `GameState`; `GameState` emits a signal; UI redraws in response. This is what makes the HUD swappable/rebuildable without touching gameplay code, and it's what makes "why did my tomato count change" a one-place grep (`GameState.gd`) instead of a codebase-wide hunt.

- **No cross-scene hard references, ever.** Never `get_node("../../Player")`, never export a `NodePath` that reaches outside the current scene's own tree. Cross-scene/cross-entity communication goes through exactly one of:
  - **Signals** — one-shot events with a payload (`tomato_harvested(tomato: Tomato)`, `life_lost(remaining: int)`). Prefer this for "something happened."
  - **GameState / autoload properties** — persistent shared state that outlives any one scene. Prefer this for "what's true right now."
  - **Groups** (`add_to_group("enemies")`, `get_tree().get_nodes_in_group("enemies")`) — when you need to broadcast to or query a *category* of nodes without owning references to any specific one (e.g. an AoE card effect hitting "all enemies in dungeon").
  - **An EventBus autoload**, only if you find yourself connecting the same signal across more than ~3 unrelated scenes by hand (see [Scaling past MVP](#scaling-past-mvp-if-there-is-time)). Don't build it upfront — signals + GameState cover the whole MVP.

- **SceneRouter owns every scene transition.** Nothing calls `get_tree().change_scene_to_file()` outside `SceneRouter`. This keeps Camp ↔ Prep ↔ Dungeon ↔ Summary ↔ Card-choice as one linear, greppable flow instead of scattered `change_scene` calls that are each a potential state-desync bug (e.g. leaving the dungeon without saving carried-tomatoes back to GameState).

- **Instancing over `preload` + manual `add_child` scattered everywhere.** For anything spawned more than once (enemies, tomatoes, floating damage numbers), preload the `PackedScene` once as a const at the top of the spawning script, then `.instantiate()` per spawn:
  ```gdscript
  const ENEMY_SCENE: PackedScene = preload("res://scenes/dungeon/enemy.tscn")
  ...
  var enemy := ENEMY_SCENE.instantiate()
  enemy.data = goblin_data # inject the EnemyData resource
  add_child(enemy)
  ```
  This is also the seam where a future object pool would slot in (see below) without changing calling code.

## Class architecture

- **`class_name` + typed Resources for data.** Define game data (enemy stats, card definitions, tomato variants) as `Resource` subclasses with `class_name`, saved as `.tres`. Designers tweak values in the inspector; code gets typed autocomplete instead of dict key typos, and adding a new enemy is "duplicate a `.tres`, tweak numbers," not "edit a script."

  ```gdscript
  # scripts/data/enemy_data.gd
  class_name EnemyData
  extends Resource

  @export var display_name: String = ""
  @export var max_hp: int = 10
  @export var move_speed: float = 80.0
  @export var damage: int = 1
  @export var attack_cooldown: float = 1.0
  ```

  The `Enemy` scene script holds `@export var data: EnemyData`, reads from it in `_ready()`, and never hardcodes numbers. This is what makes balancing a same-day-of-deadline activity instead of a code-and-recompile one.

- **Enums for closed sets of states/categories**, not strings. `enum TomatoState { CARRIED, PLANTED }`, `enum CardCategory { COMBAT, MANAGEMENT, AGILITY }`. Catches typos at parse time instead of at runtime three days into debugging, and `match` on an enum gets exhaustiveness-ish clarity that `match` on strings doesn't.

- **State machines as an enum + `match`, not a class hierarchy — until a single entity has 4+ states with real per-state logic.** `Player` with `IDLE`/`MOVING`/`DASHING` is fine as one script with an `enum State` and a `match _state:` in `_physics_process`. If an entity's state count grows (e.g. a boss with wind-up/attack/stagger/enrage, each with distinct enter/exit logic), promote to a small state-object pattern: one `class_name` script per state implementing `enter(owner)`, `physics_update(owner, delta)`, `exit(owner)`, held in a dictionary keyed by the enum. Don't build the state-object machinery before a second entity actually needs it — see [When to deviate](#when-to-deviate).

- **`@export` every tunable value** (speed, damage, cooldown, growth time) — inspector iteration is faster than editing GDScript and re-running for jam-speed tuning. Already the pattern in `player.gd`; keep it consistent everywhere new.

- **Signals named in past tense**, declared at the top of the class that owns the event (`signal tomato_harvested(tomato: Tomato)`), typed payload always. A signal is a public API — treat its name and payload shape as something another dev (or you, tomorrow) reads without opening the emitting script.

- **Keep the class hierarchy flat.** No custom base-class hierarchies beyond what Godot gives you (`Node2D`, `CharacterBody2D`, `Resource`). A `class_name` on a script that adds real behavior/data is good; a `class_name` that exists just to group things or to prepare for hypothetical future subclasses is not — YAGNI applies harder in a 2-day jam than anywhere else.

- **Static typing where it clarifies, not everywhere.** Type function signatures and exported vars always (`func heal(amount: int) -> void`); local inference (`var x := 5`) is fine when the type is obvious from the right-hand side. The goal is catching bugs and getting autocomplete, not satisfying a linter.

- **Duck-typing over interfaces for one-off cross-cutting behavior.** Godot doesn't have interfaces; for something like "can this be picked up," prefer `if target.has_method("on_picked_up"): target.on_picked_up()` over inventing an `Interactable` base class that everything has to inherit from. Reach for a shared component (see above) instead of a marker interface when the behavior is substantial, not just a single method check.

## Data flow & persistence pattern

- **`GameState` is the single source of truth for anything that must survive a scene change**: carried tomatoes, plot states, villager list, resources, unlocked card tiers. If a value needs to exist after `SceneRouter` swaps scenes, it lives in `GameState`, not in a node that's about to be freed.
- **Save/load (if there's time — out of MVP per CLAUDE.md) is "serialize GameState's exported fields to a `.tres`/JSON and back."** Because `GameState`'s persisted fields are already the full picture of "what matters across scenes," a save system is a thin serializer around it, not a parallel state store to keep in sync. Don't build this until the MVP loop works — see CLAUDE.md's MVP list.
- **Read paths are cheap, write paths are narrow.** Anything can read `GameState.tomatoes`. Only a small, known set of call sites should write to it (harvest-click handler, dungeon hit handler, dungeon-death handler) — if you find yourself mutating `GameState` from a UI script or a component, that's the signal something's inverted; route it through a signal back to whichever system owns that mutation.

## Scaling past MVP (if there is time)

Everything above is sized for the MVP. If time allows and these specific pressures show up, here's the next increment — don't build any of this speculatively:

- **EventBus autoload** — only once 3+ unrelated systems need to react to the same event and direct signal-connecting gets unwieldy (e.g. "enemy died" needs to reach loot, camp population, and a quest tracker). It's just another autoload with `signal`s on it that nobody owns state on, purely a relay.
- **Object pooling** — only if profiling (or visible stutter) shows enemy/projectile `instantiate()`/`queue_free()` churn is a real cost. Godot's instancing is fast enough for a single fixed dungeon room; don't pre-build a pool for content that doesn't exist yet.
- **A second dungeon room / room-transition system** — reuse `SceneRouter`'s pattern (one owner of transitions) rather than growing ad-hoc room-swap logic inside `Dungeon.tscn`.
- **State-object pattern** for entities whose `match`-based state machine has grown past ~4 states with real enter/exit logic (see above).

## When to deviate

This is a 2-day jam, not a shipped product. If a rule here costs more time than it saves, skip it and note the shortcut in the commit message — don't stop mid-jam to "fix" architecture unless it's actively causing merge conflicts or bugs. The ordering that matters: **playable loop first** (see CLAUDE.md's MVP list), **architecture only in service of getting there without the two of you blocking each other on `.tscn`/script conflicts.** Everything in this file exists to prevent merge pain and enable inspector-speed tuning — if a shortcut doesn't threaten either of those, take it.
