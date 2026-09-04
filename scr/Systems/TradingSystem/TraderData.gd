# TraderData.gd
# Ассортимент конкретного торговца. Создаётся как .tres ресурс в инспекторе.
class_name TraderData
extends Resource

@export var trader_name: String = "Торговец"
@export var items: Array[TradeItemEntry] = []

## Множитель цены, по которой торговец СКУПАЕТ предметы у игрока.
## 0.5 = торговец платит половину от "базовой" цены предмета (item.price).
@export var sell_multiplier: float = 0.5
