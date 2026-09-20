class_name CardData
extends ItemData
## Pokémon-card-style boost: one passive (always-on while equipped) plus
## one active (triggered by a hotbar key, on its own cooldown). Bought
## from CardShop for gold, equipped into one of GameState.equipped_cards'
## 3 slots via the inventory menu's Card row.

enum Passive { NONE, PLOT_GROWTH_SPEED, PLAYER_DAMAGE, PLAYER_SPEED, GOLD_GAIN }
enum Active { NONE, INSTANT_HARVEST, DAMAGE_BURST, DASH_RESET, GOLD_RUSH }

@export var price: int = 0

@export var passive: Passive = Passive.NONE
## Fractional bonus applied by GameState.get_passive_multiplier (e.g. 0.25 = +25%).
@export var passive_value: float = 0.0

@export var active: Active = Active.NONE
## Magnitude interpreted per Active type (damage amount, gold amount, ...).
@export var active_value: float = 0.0
@export var active_cooldown: float = 10.0
