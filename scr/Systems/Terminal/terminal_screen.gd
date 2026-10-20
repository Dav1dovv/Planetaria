extends PanelContainer
class_name TerminalScreen
## «Экран» консоли: рамка берётся из Theme (Theme Type Variation = TerminalScreen),
## а этот скрипт добавляет только эффект включения монитора — вспышка и раскрытие из линии.
## Вызови boot() — экран «включится».

@export_group("Включение монитора")
@export_range(0.05, 1.0, 0.01) var open_time: float = 0.22
@export_range(0.05, 1.0, 0.01) var flash_time: float = 0.3
## Насколько ярко вспыхивает экран при включении (1 = без вспышки).
@export_range(1.0, 4.0, 0.1) var flash_brightness: float = 2.0


func boot(delay: float = 0.0) -> void:
	pivot_offset = size * 0.5
	scale = Vector2(1.0, 0.04)
	modulate = Color(flash_brightness, flash_brightness, flash_brightness, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale:y", 1.0, open_time).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color.WHITE, flash_time).set_delay(delay)
