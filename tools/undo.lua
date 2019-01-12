local Undo = {}

function Undo:controllerpressed(controller, button)
  local isLeft = button == 'touchpad' and self.layout:touchpadDirection(controller) == 'left'
  if isLeft and not self.layout.controllers[controller].hover then
    self.layout:undo()
  end
end

return Undo
