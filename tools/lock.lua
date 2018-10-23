local Lock = {}

Lock.name = 'Lock'
Lock.context = 'hover'
Lock.button = 'left'
Lock.lockpick = true

function Lock:use(controller, entity)
  self.layout:setLocked(entity, not entity.locked)
end

return Lock
