extends ItemData
class_name TeleporterData

## Телепортер (GDD: «Возврат на корабль»): дорогой расходник. Держишь в руке, жмёшь
## ЛКМ — после короткого заряда переносит на корабль. Тратится только если телепорт
## состоялся: прерванный заряд (урон, смена предмета) предмет не съедает.
##
## Создание: ПКМ в FileSystem -> New Resource -> TeleporterData, положить в папку,
## которую сканирует ItemDB (misc/Content/Items/) — иначе после загрузки сохранения
## предмет превратится в обычный ItemData и потеряет поведение.
##
## Всю логику заряда ведёт TeleportChannel (создаётся из PlayerCombat на ЛКМ).

@export_category("Teleporter")
## Ключ сцены из SceneRegistry, куда переносит. По GDD — корабль.
@export var destination_scene: String = "Ship"
## Сколько секунд заряжается. 0 = мгновенно.
@export_range(0.0, 5.0, 0.1) var channel_time: float = 1.5
## Получение урона прерывает заряд (иначе это был бы бесплатный выход из любого боя)
@export var interrupt_on_damage: bool = true
## Движение прерывает заряд (по умолчанию можно идти, пока заряжается)
@export var interrupt_on_move: bool = false
## Тратить 1 шт. при успешном телепорте
@export var consume_on_use: bool = true
@export var charge_sound: AudioStream
@export var teleport_sound: AudioStream
@export var effect_color: Color = Color(0.45, 0.85, 1.0)


func _init() -> void:
	# Рука «пьёт» — жест подходит к активации; меняется в Инспекторе
	play_anim = "Drink"
