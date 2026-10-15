extends Node
class_name QuestReporter

## Дизайнерский компонент: сообщает системе заданий о событии. Вешается на любой
## объект и настраивается в Инспекторе — код писать не нужно.
## Примеры: Area2D у входа в пещеру («найти пещеру»), NPC («союз заключён»).
## Вызвать вручную: report() — например, из сигнала в Инспекторе.

## Тип события (см. QuestData.Kind)
@export var kind: QuestData.Kind = QuestData.Kind.ALLIANCE
## ID события/расы/моба — должен совпадать с target_id в задании (пусто = любое)
@export var target_id: String = ""
@export var amount: int = 1
## Пусто = текущая планета
@export var planet_name: String = ""
## Сработать только один раз за сессию
@export var only_once: bool = true
## Необязательно: репорт, когда в эту зону входит игрок
@export var trigger_area: Area2D
@export var report_on_ready: bool = false

var _reported: bool = false


func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
	if report_on_ready:
		report.call_deferred()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		report()


func report() -> void:
	if only_once and _reported:
		return
	_reported = true
	var planet := planet_name if not planet_name.is_empty() else Global.current_location
	Global.report_planet_event(planet, kind, target_id, amount)
