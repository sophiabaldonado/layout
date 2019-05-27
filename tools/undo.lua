local Undo = {}

function Undo:controllerpressed(hand, button)
  local isLeft = button == 'touchpad' and self.layout:touchpadDirection(hand) == 'left'
  if isLeft and not self.layout.hands[hand].hover then
    self.layout:undo()
  end
end

return Undo
