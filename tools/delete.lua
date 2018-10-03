-- Delet

local Delete = {}

Delete.direction = 'down'

function Delete:controllerpressed(controller, button)
  if button ~= 'touchpad' or self.layout:getTouchpadDirection(controller) ~= self.direction then return end

  local entity = self.layout:getClosestEntity(controller)
  if entity and not entity.focused and not entity.locked then
    self.layout:removeEntity(self.layout:getClosestEntity(controller))
  end
end

return Delete
