@icon("res://addons/at-icons/mesh/video_camera.svg")
extends Camera2D
class_name Blaze_camera

var sscount = 0
@export var auto_screenshot : bool = true

var timer = Timer.new()

func _ready():
	timer.wait_time = 5
	timer.start()
	timer.timeout.connect(screenshot)
	var dir = DirAccess.open("user://")
	dir.make_dir("Screenshots")
	
	dir = DirAccess.open("user://Screenshots")
	for n in dir.get_files():
		sscount +=1
	

func screenshot():
	sscount = 0
	var dir = DirAccess.open("user://Screenshots")
	for n in dir.get_files():
		sscount +=1
	await RenderingServer.frame_post_draw
	
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	img.save_png("user://Screenshots/screenshot" + str(sscount) +".png")
	print("screenshot taked")

func _input(event):
	if Input.is_key_pressed(KEY_F2):
		screenshot()
