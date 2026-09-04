extends Node2D
class_name PlayerSkin

@export var player_skins: Array[Texture]
@export var player_sprites: Array[Sprite2D]
@onready var head_sprites: Sprite2D = $Body/Head

var skin_index: int = 0
var head_inex:  int = 0  # опечатка сохранена намеренно — используется везде

# Флаг: был ли скин уже задан извне (через мультиплеер)
# Если true — не перезаписываем из Global в _ready
var _skin_set_externally: bool = false

func _ready() -> void:
	# В мультиплеере скин придёт через apply_skin_rpc от сервера.
	# Для своего игрока берём из Global, для чужих — ждём RPC.
	var is_multiplayer_active = (
		multiplayer.multiplayer_peer != null and
		not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	)

	if is_multiplayer_active:
		# Определяем чей это скин по имени родительского узла (peer_id)
		var parent = get_parent()
		if parent and parent.name.is_valid_int():
			var peer_id = int(parent.name)
			if peer_id == multiplayer.get_unique_id():
				# Это наш игрок — берём скин из Global
				skin_index = Global.player_skin_index
				head_inex  = Global.player_skin_head_index
				update_skin()
			# else: чужой игрок — не трогаем, ждём apply_skin_rpc от сервера
		else:
			# Имя не число — одиночная игра внутри мультиплеера, берём из Global
			skin_index = Global.player_skin_index
			head_inex  = Global.player_skin_head_index
			update_skin()
	else:
		# Одиночная игра — как раньше
		print("head index: " + str(Global.player_skin_head_index) + "| Skin index: " + str(Global.player_skin_index))
		skin_index = Global.player_skin_index
		head_inex  = Global.player_skin_head_index
		update_skin()


func update_skin() -> void:
	if player_skins.size() == 0:
		return
	skin_index = wrapi(skin_index, 0, player_skins.size())
	head_inex  = wrapi(head_inex,  0, player_skins.size())
	for sprite in player_sprites:
		sprite.texture = player_skins[skin_index]
	head_sprites.texture = player_skins[head_inex]


func _on_next_pressed() -> void:
	skin_index += 1
	update_skin()

func _on_previus_pressed() -> void:
	skin_index -= 1
	update_skin()

func _on_next_head_pressed() -> void:
	head_inex += 1
	update_skin()

func _on_previus_head_pressed() -> void:
	head_inex -= 1
	update_skin()

func randomSkin():
	randomize()
	skin_index = randi() % player_skins.size()
	randomize()
	head_inex = randi() % player_skins.size()
	update_skin()
	print("buttton pressed")
