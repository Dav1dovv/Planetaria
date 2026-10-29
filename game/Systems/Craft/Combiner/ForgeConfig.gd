## ForgeConfig.gd
## ВСЕ числа баланса комбинатора в одном месте (правится в Inspector, файл forge_config.tres).
## Менять баланс не нужно в коде: открой forge_config.tres и крути значения.
extends Resource
class_name ForgeConfig

@export_group("Слоты")
## Всего слотов комбинации (основа + добавки). По GDD — 4.
@export_range(2, 6) var max_slots: int = 4
## Сколько ОРУЖИЙ можно добавить к основе (по GDD — только одно)
@export_range(0, 2) var max_donor_weapons: int = 1

@export_group("Прочность")
## «Стабильная» прочность комбинированного оружия (GDD: 100)
@export_range(10, 500) var base_durability: int = 100
## Потолок прочности, если свойства её повышают
@export_range(10, 500) var durability_cap: int = 130
@export_range(5, 100) var min_durability: int = 15
## Сколько прочности теряем за каждые +100% силы (DPS) сверх основы. 0.5 = −50% за каждое «удвоение».
@export_range(0.0, 2.0, 0.05) var overpower_durability_k: float = 0.5

@export_group("Стрельба от второго оружия")
## Урон снаряда относительно урона основы. Удар остаётся полным, снаряды слабее (идут сверху, на каждом замахе)
@export_range(0.1, 1.5, 0.05) var shoot_damage_mult: float = 0.6

@export_group("Лимиты множителей (защита от «сломал игру в ноль»)")
@export_range(1.0, 5.0, 0.05) var max_damage_mult: float = 2.0
@export_range(1.0, 3.0, 0.05) var max_speed_mult: float = 1.6
@export_range(0.1, 1.0, 0.05) var min_total_mult: float = 0.4

@export_group("Цена (монеты)")
@export var fee_base: int = 10
## Доля цены каждого ресурса/реликвии, которая уходит в плату
@export_range(0.0, 2.0, 0.05) var fee_price_k: float = 0.5
@export_range(0.0, 2.0, 0.05) var fee_donor_k: float = 0.4
## Доплата за каждые +100% силы
@export var fee_power: int = 60

@export_group("Ремонт")
## Сколько прочности даёт единица ресурса за каждую монету её цены (price)
@export_range(0.1, 10.0, 0.1) var repair_per_price: float = 2.0
@export var repair_min_per_unit: int = 5
