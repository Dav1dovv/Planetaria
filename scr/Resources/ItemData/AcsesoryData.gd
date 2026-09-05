@tool
@icon("res://common/icons/helpcon4.png")
extends ItemData
class_name AccessoryData

@export_category("Accessory Effects")
## Пассивные эффекты, которые активируются только когда аксессуар находится в любом слоте хотбара.
## Держатся, пока аксессуар экипирован — длительность самого Effect-ресурса
## не важна, снимаются явно в deactivate() (см. EffectManager.apply_passive_effect).
@export var effects: Array[Effect] = []

@export_group("Visual")
## Иконка для слота (автоматически берётся из ItemData.icon, но можно переопределить)
@export var slot_background: Texture2D
## Цвет рамки для аксессуара в UI (золотой для эпичности)
@export var ui_border_color: Color = Color.GOLD

# Автоматически применяет все эффекты к игроку (вызывается Hotbar)
func activate(player: Node) -> void:
	if not player.has_method("apply_passive_effect"):
		push_warning("AccessoryData '%s': у %s нет apply_passive_effect() — эффекты не применены" % [item_name, player])
		return
	for effect in effects:
		player.apply_passive_effect(effect)
	print("Accessory '%s' activated" % item_name)

# Снимает все эффекты от этого аксессуара
func deactivate(player: Node) -> void:
	if not player.has_method("remove_passive_effect"):
		return
	for effect in effects:
		player.remove_passive_effect(effect)
	print("Accessory '%s' deactivated" % item_name)

# Для UI: переопределение update_ui в InventorySlot (добавь в InventorySlot.gd)
func update_accessory_ui(slot: InventorySlot) -> void:
	if slot.get("border"):
		slot.border.modulate = ui_border_color
	# Или добавь рамку/эффект свечения
