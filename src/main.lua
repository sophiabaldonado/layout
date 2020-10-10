layout = require 'layout'

function lovr.load()
  layout:init()
end

function lovr.update(dt)
  layout:update(dt)
end

function lovr.draw()
  layout:draw()
end
