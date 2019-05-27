local Redo = {}

function Redo:controllerpressed(hand, button)
  local isRight = button == 'touchpad' and self.layout:touchpadDirection(hand) == 'right'
  if isRight and not self.layout.hands[hand].hover then
    self.layout:redo()
  end
end

return Redo
