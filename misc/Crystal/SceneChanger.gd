extends interaction_area
class_name SceneChanger

@export_file("*.tscn") var scene_path: String = ""
@export_enum("Vehana","Ship","Morva") var scene : String = "Vehana"

func _ready() -> void:
	interact = Callable(self,"_do")

func _do():
	Global.scene_manager.change_scene(scene,Vector2.ZERO)
