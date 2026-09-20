extends MenuPanel
## Crop chest dashboard: shows carried vs stored crop counts, deposit/
## withdraw one at a time. Reads/writes GameState only.

@onready var _carried_label: Label = %CarriedLabel
@onready var _stored_label: Label = %StoredLabel
@onready var _deposit_button: Button = %DepositButton
@onready var _withdraw_button: Button = %WithdrawButton


func _ready() -> void:
	super()
	add_to_group("chest_ui")
	UITheme.style_button(_deposit_button)
	UITheme.style_button(_withdraw_button)
	_deposit_button.pressed.connect(_on_deposit_pressed)
	_withdraw_button.pressed.connect(_on_withdraw_pressed)
	GameState.item_changed.connect(_on_item_changed)
	GameState.crop_stored_changed.connect(_on_crop_stored_changed)


func open() -> void:
	_refresh()
	show()


func _on_item_changed(item_id: String, _count: int) -> void:
	if item_id == "crop":
		_refresh()


func _on_crop_stored_changed(_count: int) -> void:
	_refresh()


func _on_deposit_pressed() -> void:
	GameState.deposit_crop(1)


func _on_withdraw_pressed() -> void:
	GameState.withdraw_crop(1)


func _refresh() -> void:
	_carried_label.text = "Carried: %d" % GameState.get_item_count("crop")
	_stored_label.text = "Stored: %d" % GameState.crop_stored
