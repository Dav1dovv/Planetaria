# save_load_button.gd
extends Button

@onready var skin: PlayerSkin = $HBoxContainer2/HBoxContainer/TextureRect/Skin

@export var player_name_label: Label
@export var date_label:        AutoSizeLabel
@export var textures: Array[Texture2D] = []

var slot_name: String = ""


func setup_slot(save_data: Dictionary) -> void:
	player_name_label.text = save_data.get("player_name", "Новое сохранение")
	slot_name              = save_data.get("slot_name", "")

	var ts: int = save_data.get("last_save_time", 0)
	if ts > 0:
		var d := Time.get_datetime_dict_from_unix_time(ts)
		date_label.text = "%02d.%02d.%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]
	else:
		date_label.text = "Нет данных"

	var skin_idx: int = save_data.get("skin_index", 1)
	var head_idx: int = save_data.get("head_index", 1)
	skin.skin_index = skin_idx
	skin.head_inex  = head_idx
	skin.update_skin()


func _on_delete_pressed() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text        = "Вы уверены, что хотите удалить сохранение \"%s\"?\nЭто действие нельзя отменить!" % player_name_label.text
	confirm.get_ok_button().text     = "Удалить"
	confirm.get_cancel_button().text = "Отмена"
	confirm.confirmed.connect(_confirm_delete)
	get_tree().current_scene.add_child(confirm)
	confirm.popup_centered()


func _confirm_delete() -> void:
	SaveLoad.delete_save(slot_name)

	var save_load_slot = get_node("/root").find_child("SaveLoadSlot", true, false)
	if save_load_slot:
		save_load_slot.update_save_slots()

	queue_free()
