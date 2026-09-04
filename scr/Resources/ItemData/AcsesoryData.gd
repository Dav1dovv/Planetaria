@tool
@icon("res://common/icons/helpcon4.png")
extends ItemData
class_name AccessoryData

@export_category("Accessory Effects")
## Пассивные эффекты, которые активируются только когда аксессуар находится в любом слоте хотбара
@export var effects: Array[Effect] = []

@export_group("Visual")
## Иконка для слота (автоматически берётся из ItemData.icon, но можно переопределить)
@export var slot_background: Texture2D
## Цвет рамки для аксессуара в UI (золотой для эпичности)
@export var ui_border_color: Color = Color.GOLD

# Автоматически применяет все эффекты к игроку (вызывается Hotbar)
func activate(player: Node) -> void:
	for effect in effects:
		if player.has_method("apply_passive_effect"):
			player.apply_passive_effect(effect)
		else:
			_apply_direct(player, effect)
	print("Accessory '%s' activated" % item_name)

# Снимает все эффекты от этого аксессуара
func deactivate(player: Node) -> void:
	for effect in effects:
		if player.has_method("remove_passive_effect"):
			player.remove_passive_effect(effect)
		else:
			_remove_direct(player, effect)
	print("Accessory '%s' deactivated" % item_name)

# Прямая логика применения (если у Player нет методов — fallback)
func _apply_direct(player: Node, effect: Effect) -> void:
	match effect.effect_type:
		0:  # Speed boost
			player.speed_multiplier += effect.value
		1:  # Damage boost
			player.damage_multiplier += effect.value
		2:  # Health regen
			player.health_regen += effect.value
		3:  # Defense
			player.defense += effect.value
		# Добавь свои типы эффектов

func _remove_direct(player: Node, effect: Effect) -> void:
	match effect.effect_type:
		0:
			player.speed_multiplier -= effect.value
		1:
			player.damage_multiplier -= effect.value
		2:
			player.health_regen -= effect.value
		3:
			player.defense -= effect.value

# Для UI: переопределение update_ui в InventorySlot (добавь в InventorySlot.gd)
func update_accessory_ui(slot: InventorySlot) -> void:
	if slot.get("border"):
		slot.border.modulate = ui_border_color
	# Или добавь рамку/эффект свечения
