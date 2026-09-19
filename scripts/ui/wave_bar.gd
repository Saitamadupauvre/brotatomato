extends Control
## Minecraft-raid-style "enemies left" bar. Hidden until an altar wave
## starts; reads its bound AltarBehavior via signals only, never polls.

@onready var _bar: ProgressBar = %WaveProgressBar
@onready var _label: Label = %WaveLabel


func _ready() -> void:
	hide()


func bind_altar(altar: AltarBehavior) -> void:
	altar.wave_started.connect(_on_wave_started)
	altar.wave_progress.connect(_on_wave_progress)
	altar.wave_cleared.connect(_on_wave_cleared)


func _on_wave_started(count: int) -> void:
	_bar.max_value = max(count, 1)
	_bar.value = count
	_label.text = "Enemies left: %d" % count
	show()


func _on_wave_progress(remaining: int) -> void:
	_bar.value = remaining
	_label.text = "Enemies left: %d" % remaining


func _on_wave_cleared() -> void:
	hide()
