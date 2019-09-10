layout = require 'init'

function lovr.load()
  layout:init({
    root = 'assets'
  })
end

function lovr.update(dt)
  layout:update(dt)
end

function lovr.draw()
  layout:draw()
end
