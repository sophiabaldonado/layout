local Clear = {}

function Clear:controllerpressed(controller, button)
  if button == 'menu' then
    local other = self.layout:getOtherController(controller)
    if other and other:isDown('menu') then
      layout:clearEntities()
    end
  end
end

return Clear
