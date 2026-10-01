extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite

var closed : bool = true
@onready var static_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D


func _on_rapier_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		closed = !closed
		if closed:
			sprite.play("Close")
			static_collision.disabled = false
		else:
			sprite.play("Open")
			await sprite.animation_finished
			static_collision.disabled = true


#func _on_rapier_area_2d_body_exited(body: Node2D) -> void:
	#if body.is_in_group("Player"):
		#closed = false
		#static_collision.disabled = closed
		#sprite.play("Close")
