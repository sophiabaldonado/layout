local tools = require 'tools'
local config = {
	enablePoly = false,
	tools = {
		hover = {
			trigger = tools.translate,
			grip = tools.rotate,
			doubleTrigger = tools.scale,
			menu = tools.satchel,
			joystick1 = tools.copy.activate,
			joystick2 = tools.lock,
			joystick3 = tools.delete,
			joystick4 = nil
		}
	}


}


return config
