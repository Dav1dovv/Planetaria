extends RefCounted
class_name DialogueLock

## Блокировка управления на время диалога.
##
## Баллон диалога вызывает lock() при старте и unlock() при завершении; движение,
## бой и взаимодействие спрашивают is_locked(). Счётчик, а не флаг: вложенные или
## наложившиеся диалоги не разблокируют игрока раньше времени.
##
## Почему не Global.is_opened_menu: тот флаг переключают десятки окон, и любое из них
## могло бы случайно «разморозить» игрока посреди реплики.

static var _count: int = 0


static func lock() -> void:
	_count += 1


static func unlock() -> void:
	_count = maxi(0, _count - 1)


static func is_locked() -> bool:
	return _count > 0


## Аварийный сброс (например, при загрузке сцены/слота).
static func reset() -> void:
	_count = 0
