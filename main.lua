layout = require 'layout'

function lovr.load()
  layout:init()
	shader = require('lighting')()
	lovr.graphics.setShader(shader)
  lovr.graphics.setBackgroundColor(20, 20, 25)
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

accum = 0
rate = 1 / 60
function lovr.step()
  local dt = lovr.timer.step()
  accum = accum + dt

  while accum >= rate do
    accum = accum - rate

    lovr.event.pump()
    for name, a, b, c, d in lovr.event.poll() do
      if name == 'quit' and (not lovr.quit or not lovr.quit()) then
        return a
      end
      lovr.handlers[name](a, b, c, d)
    end

    if lovr.audio then
      lovr.audio.update()
      if lovr.headset and lovr.headset.isPresent() then
        lovr.audio.setOrientation(lovr.headset.getOrientation())
        lovr.audio.setPosition(lovr.headset.getPosition())
        lovr.audio.setVelocity(lovr.headset.getVelocity())
      end
    end

    if lovr.update then lovr.update(rate) end
  end

  if lovr.graphics then
    lovr.graphics.clear()
    lovr.graphics.origin()

    if lovr.draw then
      if lovr.headset and lovr.headset.isPresent() then
        lovr.headset.renderTo(lovr.draw)
      else
        lovr.draw()
      end
    end

    lovr.graphics.present()
  end

  lovr.timer.sleep(.001)
end
