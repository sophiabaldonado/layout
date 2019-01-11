layout = require 'init'

function lovr.load()
  layout:init('level.json')
end

function lovr.update(dt)
  layout:update(dt)
end

function lovr.draw()
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
