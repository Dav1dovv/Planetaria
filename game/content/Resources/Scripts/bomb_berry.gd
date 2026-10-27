extends Harvest_item
class_name ExplosiveHarvestable

## Harvestable-объект, который после полной добычи (durability <= 0)
## выполняет настраиваемое действие — ресурс типа HarvestAction,
## назначаемый в инспекторе.
##
## Для взрыва: создайте новый ресурс типа ExplodeAction (.tres) и
## перетащите его в поле harvest_action.
##
## Для других объектов в будущем — создайте свой класс-наследник
## HarvestAction (например SpawnCreatureAction) и назначьте его сюда же,
## без изменения кода этого скрипта.

@export var harvest_action : HarvestAction


func _ready() -> void:
	super._ready()
	collected.connect(_on_collected)


func _on_collected() -> void:
	if harvest_action:
		harvest_action.execute(self)
