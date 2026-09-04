extends Resource
class_name HarvestAction

## Базовый класс для действий, которые выполняются после того,
## как Harvestable-объект будет полностью добыт (durability <= 0).
##
## Чтобы добавить новое поведение — создайте новый скрипт-ресурс,
## наследующий HarvestAction, и переопределите execute().
## Примеры: ExplodeAction (взрыв), SpawnCreatureAction (вылезает моб),
## ChainReactionAction (поджигает соседние объекты) и т.д.
##
## Готовый ресурс назначается в инспекторе в поле
## ExplosiveHarvestable.harvest_action (или любого другого наследника
## Harvestable, который добавит такое же поле).

func execute(harvestable: Node2D) -> void:
	push_warning("HarvestAction.execute() не переопределён в ресурсе: " + str(resource_path))
