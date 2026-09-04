extends CanvasLayer

var player

@onready var hud: Control = $HUD
@onready var inventory: Inventory = $HUD/Inventory
@onready var death_menu: Control = $DeathMenu
@onready var pause_menu: Control = $PauseMenu


#func _on_inventory_visibility_changed() -> void:
	#if inventory.visible:
		#pause_menu.visible = false
	


func call_death():
	death_menu.death()
	hud.visible = false
	pause_menu.visible = false
	pause_menu.anotherMenuOpened = true
