local Lock = {}

Lock.name = 'Lock'
Lock.context = 'hover'
Lock.button = 'left'
Lock.lockpick = true

function Lock:use(controller, entity)
  entity.locked = not entity.locked
  self.layout:dirty()
end

return Lock
