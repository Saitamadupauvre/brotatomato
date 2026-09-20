class_name CardData
extends ItemData
## Pokémon-card-style boost: one passive (always-on while equipped) plus
## one active (triggered by a hotbar key, on its own cooldown). Won as a
## random gamble draw from CardShopMenu (weighted LootTable, see
## resources/cards/card_gamble_loot.tres), equipped into one of
## GameState.equipped_cards' 3 slots via the inventory menu's Card row.

enum Passive { NONE, PLOT_GROWTH_SPEED, PLAYER_DAMAGE, PLAYER_SPEED, GOLD_GAIN }
enum Active { NONE, INSTANT_HARVEST, DAMAGE_BURST, DASH_RESET, GOLD_RUSH }

@export var passive: Passive = Passive.NONE
## Fractional bonus applied by GameState.get_passive_multiplier (e.g. 0.25 = +25%).
@export var passive_value: float = 0.0

@export var active: Active = Active.NONE
## Magnitude interpreted per Active type (damage amount, gold amount, ...).
@export var active_value: float = 0.0
@export var active_cooldown: float = 10.0


## Human-readable passive/active blurbs, shared by every place a card
## needs to describe itself (inventory tooltips, gamble draw result) so
## the wording only lives in one place.
func describe_passive() -> String:
	var pct := "+%d%%" % int(passive_value * 100)
	match passive:
		Passive.PLOT_GROWTH_SPEED: return "%s plot growth speed" % pct
		Passive.PLAYER_DAMAGE: return "%s attack damage" % pct
		Passive.PLAYER_SPEED: return "%s move speed" % pct
		Passive.GOLD_GAIN: return "%s gold gained" % pct
		_: return "None"


func describe_active() -> String:
	match active:
		Active.INSTANT_HARVEST: return "Instant Harvest (ripen nearest plot)"
		Active.DAMAGE_BURST: return "Damage Burst (%d dmg nearby)" % int(active_value)
		Active.DASH_RESET: return "Dash Reset"
		Active.GOLD_RUSH: return "Gold Rush (+%d gold)" % int(active_value)
		_: return "None"


func describe() -> String:
	return "%s\nPassive: %s\nActive: %s (%ds cooldown)" % [
		display_name, describe_passive(), describe_active(), int(active_cooldown),
	]
