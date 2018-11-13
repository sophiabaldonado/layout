-- Delet

local Delete = {}

Delete.name = 'Delete'
Delete.context = 'hover'
Delete.button = 'right'
Delete.icon = 'delete.png'

function Delete:use(controller, entity)
  self.layout:removeEntity(entity)
end

return Delete
