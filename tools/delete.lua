-- Delet

local Delete = {}

Delete.direction = 'down'

function Delete:controllerpressed(controller, button)
  if button ~= 'touchpad' or self.layout:getTouchpadDirection(controller) ~= self.direction then return end

  local entity = self.layout:getClosestHover(controller)
  if entity and not entity.focused and not entity.locked then
    self.layout:removeEntity(self.layout:getClosestHover(controller))
  end
end

return Delete
