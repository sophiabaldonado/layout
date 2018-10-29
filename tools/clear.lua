local Clear = {}

Clear.name = 'Clear'

function Clear:controllerpressed(controller, button)
  if button == 'menu' then
    local other = self.layout:getOtherController(controller)
    if other and other:isDown('menu') then
      for k in pairs(self.layout.state.entities) do
        self.layout.state.entities[k] = nil
      end
    end
  end
end

return Clear
