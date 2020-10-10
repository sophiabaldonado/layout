local Clear = {}

Clear.name = 'Clear'

function Clear:controllerpressed(controller, button)
  if button == 'menu' then
    local other = self.layout:getOtherController(controller)
    if other and other:isDown('menu') then
      for _, entity in ipairs(self.layout.state.entities) do
        self.layout:removeEntity(entity)
      end
    end
  end
end

return Clear
