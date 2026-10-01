extends CanvasLayer

const FUEL = preload("uid://dwmw15dg8pwvd")
@onready var trave: blaze_button = $Panel/VBoxContainer/HBoxContainer/Button

var location_key 
var is_opened: bool = false
var fuel_count := [10,46,25,50]
var fuel_indx


func _on_option_button_item_selected(index: int) -> void:
	location_key = $Panel/VBoxContainer/OptionButton.get_item_text(index)
	fuel_indx = index
	trave.text = "TRAVE X" + str(fuel_count[fuel_indx])

func _ready() -> void:
	visible = false

func _on_button_pressed() -> void:
	if location_key and Global.inventory.has_total_item(FUEL,fuel_count[fuel_indx]):
		Global.inventory.remove_from_total(FUEL,fuel_count[fuel_indx])
		Global.scene_manager.change_scene(location_key,Vector2.ZERO)
		if Global.is_opened_menu && !is_opened:
			return
		is_opened = !is_opened
		Global.is_opened_menu = is_opened
		visible = is_opened


func _on_button_2_pressed() -> void:
	toogle()

func toogle():
	if Global.is_opened_menu && !is_opened:
		return
	is_opened = !is_opened
	Global.is_opened_menu = is_opened
	visible = is_opened
