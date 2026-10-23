extends RefCounted
class_name ControllerGlyphs

## Подписи кнопок под подключённый контроллер (GDD: «иконки подсказок меняются под
## контроллер; у Nintendo подтверждение и отмена на других кнопках»).
##
## Godot называет кнопки по ПОЛОЖЕНИЮ: JOY_BUTTON_A — всегда нижняя. На Xbox нижняя = A,
## на PlayStation = Крест, на Switch = B. Поэтому подпись берём по семейству контроллера.
##
## Использование:  ControllerGlyphs.button_label(JOY_BUTTON_Y)   ->  "Y" / "Triangle" / "X"
##                 ControllerGlyphs.action_label("CallInventory")  ->  подпись кнопки действия

enum Family { XBOX, PLAYSTATION, SWITCH }


## Принудительное семейство для проверки подсказок без контроллера: ControllerGlyphs.forced_family = 1
## (0 = Xbox, 1 = PlayStation, 2 = Switch, -1 = определять по подключённому геймпаду)
static var forced_family: int = -1


static func family(device: int = 0) -> Family:
	if forced_family >= 0:
		return forced_family as Family
	var joy_name := Input.get_joy_name(device).to_lower()
	if joy_name.contains("playstation") or joy_name.contains("ps4") or joy_name.contains("ps5") \
			or joy_name.contains("dualshock") or joy_name.contains("dualsense") or joy_name.contains("sony"):
		return Family.PLAYSTATION
	if joy_name.contains("nintendo") or joy_name.contains("switch") or joy_name.contains("joy-con") \
			or joy_name.contains("pro controller"):
		return Family.SWITCH
	return Family.XBOX


static func button_label(button: int, device: int = 0) -> String:
	var fam := family(device)
	match button:
		JOY_BUTTON_A: return ["A", "Cross", "B"][fam]
		JOY_BUTTON_B: return ["B", "Circle", "A"][fam]
		JOY_BUTTON_X: return ["X", "Square", "Y"][fam]
		JOY_BUTTON_Y: return ["Y", "Triangle", "X"][fam]
		JOY_BUTTON_LEFT_SHOULDER: return ["LB", "L1", "L"][fam]
		JOY_BUTTON_RIGHT_SHOULDER: return ["RB", "R1", "R"][fam]
		JOY_BUTTON_BACK: return ["View", "Create", "−"][fam]
		JOY_BUTTON_START: return ["Menu", "Options", "+"][fam]
		JOY_BUTTON_LEFT_STICK: return ["L3", "L3", "L3"][fam]
		JOY_BUTTON_RIGHT_STICK: return ["R3", "R3", "R3"][fam]
		JOY_BUTTON_DPAD_UP: return "D-pad ↑"
		JOY_BUTTON_DPAD_DOWN: return "D-pad ↓"
		JOY_BUTTON_DPAD_LEFT: return "D-pad ←"
		JOY_BUTTON_DPAD_RIGHT: return "D-pad →"
	return "Button %d" % button


static func axis_label(axis: int, value: float, device: int = 0) -> String:
	var fam := family(device)
	match axis:
		JOY_AXIS_TRIGGER_LEFT: return ["LT", "L2", "ZL"][fam]
		JOY_AXIS_TRIGGER_RIGHT: return ["RT", "R2", "ZR"][fam]
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "Left stick"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "Right stick"
	return "Axis %d" % axis


## Подпись первой кнопки геймпада у действия; "" если у действия нет геймпад-события.
static func action_label(action: String, device: int = 0) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return button_label((event as InputEventJoypadButton).button_index, device)
		if event is InputEventJoypadMotion:
			var m := event as InputEventJoypadMotion
			return axis_label(m.axis, m.axis_value, device)
	return ""
