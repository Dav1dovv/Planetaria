# PriceTierPool.gd
# Один "ценовой уровень" товаров странствующего торговца:
# набор предметов + диапазон цен + сколько случайных позиций брать из пула.
class_name PriceTierPool
extends Resource

@export var tier_name: String = "Дешёвые"

## Пул предметов этой категории — торговец будет выбирать из них случайно.
@export var items: Array[ItemData] = []

## Диапазон цены за 1 шт. (случайно в этих пределах при генерации ассортимента).
@export var price_min: int = 1
@export var price_max: int = 5

## Сколько разных позиций из этого пула попадёт в ассортимент за один "заход".
@export var slots_count: int = 2

## Диапазон количества (stock) на позицию.
@export var stock_min: int = 1
@export var stock_max: int = 3
