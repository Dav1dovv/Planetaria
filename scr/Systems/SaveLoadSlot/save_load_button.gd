# save_load_button.gd
extends Button

## Испускается после удаления сохранения. Слушает save_load_slot.gd.
signal deleted(slot_name: String)

@export var player_name_label: Label
@export var date_label: Label   # AutoSizeLabel наследуется от Label, так что тип совместим

# Осталось в Save_load_Button.tscn, в коде не используется.
# Можно удалить вместе со строкой textures = ... в .tscn.
@export var textures: Array[Texture2D] = []

const NAME_LABEL_PATH := "HBoxContainer2/HBoxContainer/Charachter_name"
const DATE_LABEL_PATH := "HBoxContainer2/HBoxContainer/Date"

var slot_name: String = ""


func _ready() -> void:
	_resolve_labels()


## Если экспорты не подцепились (другая копия сцены, переименованный узел),
## ищем лейблы по путям. Если и так не нашли, пишем в лог, в какой сцене проблема.
func _resolve_labels() -> void:
	if player_name_label == null:
		player_name_label = get_node_or_null(NAME_LABEL_PATH) as Label
	if date_label == null:
		date_label = get_node_or_null(DATE_LABEL_PATH) as Label

	if player_name_label == null or date_label == null:
		push_error("[SaveLoadButton] Label nodes not found. Scene: '%s', name_label=%s, date_label=%s" % [
			scene_file_path, player_name_label, date_label
		])


func setup_slot(save_data: Dictionary) -> void:
	_resolve_labels()
	if player_name_label == null or date_label == null:
		return

	player_name_label.text = str(save_data.get("player_name", "Новое сохранение"))
	slot_name              = str(save_data.get("slot_name", ""))

	# JSON отдаёт числа как float, поэтому приводим явно
	var ts: int = int(save_data.get("last_save_time", 0))
	if ts > 0:
		var d := Time.get_datetime_dict_from_unix_time(ts)
		date_label.text = "%02d.%02d.%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]
	else:
		date_label.text = "Нет данных"


func _on_delete_pressed() -> void:
	var shown_name: String = player_name_label.text if player_name_label else slot_name

	var confirm := ConfirmationDialog.new()
	confirm.dialog_text        = "Вы уверены, что хотите удалить сохранение \"%s\"?\nЭто действие нельзя отменить!" % shown_name
	confirm.ok_button_text     = "Удалить"
	confirm.cancel_button_text = "Отмена"
	confirm.confirmed.connect(_confirm_delete.bind(confirm))
	confirm.canceled.connect(confirm.queue_free)

	get_tree().current_scene.add_child(confirm)
	confirm.popup_centered()


func _confirm_delete(confirm: ConfirmationDialog) -> void:
	SaveLoad.delete_save(slot_name)
	confirm.queue_free()
	deleted.emit(slot_name)
	queue_free()
