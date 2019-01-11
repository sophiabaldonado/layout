local Redo = {}

function Redo:controllerpressed(controller, button)
  local isRight = button == 'touchpad' and self.layout.util.touchpadDirection(controller) == 'right'
  if isRight and not self.layout.controllers[controller].hover then
    self.layout:redo()
  end
end

return Redo
