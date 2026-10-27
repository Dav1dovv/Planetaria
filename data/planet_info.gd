extends Resource
class_name PlanetInfo
## Карточка планеты для консоли выбора. Один файл .tres на планету:
## common/Resources/PlanetInfo/*.tres. Чтобы добавить планету — Создать ресурс → PlanetInfo,
## заполнить поля и добавить файл в список Planets корневого узла PlanerChooser (в инспекторе).

## Ключ сцены в SceneRegistry (то, что передаётся в change_scene). Если сцены с таким ключом нет,
## планета показывается как «NO SIGNAL» и не запускается.
@export var id: String = ""
## Сколько топлива нужно на прыжок.
@export var fuel_cost: int = 10
## Цвет подсветки планеты (свечение и орбита).
@export var tint: Color = Color.WHITE
## Область картинки планеты в атласе Planet.png (x, y, ширина, высота в пикселях).
## Свободные: ледяная (104,8,17,17), лавовая (60,80,12,12), звезда (4,53,41,41), пёстрая (49,50,19,19).
@export var icon_region: Rect2i = Rect2i(0, 0, 32, 32)
## Ключи перевода для досье справа от картинки.
@export var type_key: String = ""
@export_multiline var description_key: String = ""
