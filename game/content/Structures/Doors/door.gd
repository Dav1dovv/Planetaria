extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite

var closed : bool = true
@onready var static_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D


func _on_rapier_area_2d_body_entered(body: Node2D) -> void:
	sprite.play("Open")
	await sprite.animation_finished
	static_collision.disabled = true
	$Open.play()


func _on_rapier_area_2d_body_exited(body: Node2D) -> void:
	sprite.play("Close")
	static_collision.disabled = false
	$Close.play()
