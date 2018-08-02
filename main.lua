layout = require 'layout'

function lovr.load()
  layout:init()
  -- skybox = require('sky_lua')()
	shader = require('lighting')()
	lovr.graphics.setShader(shader)
end

function lovr.update(dt)
  layout:update(dt)
end

function lovr.draw()
	if layout.active then
		lovr.graphics.setBackgroundColor(.078, .078, .098)
    -- lovr.graphics.setShader(skybox)
	else
		lovr.graphics.setBackgroundColor(.423, .616, .678)
    -- lovr.graphics.setShader(shader)
	end

  layout:draw()
end

function lovr.controlleradded(...)
  layout:controlleradded(...)
end

function lovr.controllerremoved(...)
  layout:controllerremoved(...)
end

function lovr.controllerpressed(...)
  layout:controllerpressed(...)
end

function lovr.controllerreleased(...)
  layout:controllerreleased(...)
end
