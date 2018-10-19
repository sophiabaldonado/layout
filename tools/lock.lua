local Lock = {}

Lock.context = 'hover'
Lock.button = 'left'
Lock.lockpick = true

function Lock:use(controller, entity)
  self.layout:setLock(entity, not entity.locked)
end

return Lock
