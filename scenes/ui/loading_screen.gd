class_name LoadingScreen
extends CanvasLayer
## Full-screen overlay shown briefly by SceneRouter during scene swaps.
## Purely cosmetic — no real async loading, the game is small enough
## that a fixed-duration overlay reads as a loading screen. Fades to
## black then back in so every scene change (menu included) reads as a
## deliberate transition instead of a hard cut.

@onready var _bg: ColorRect = $Background


func fade_in(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, duration)
	await tw.finished


func fade_out(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 0.0, duration)
	await tw.finished
