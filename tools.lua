local controllers = require 'controllers'
controllers:init()
local tools = {}

tools.translate = {
	icon = '',
	activate = function()

	end
}

tools.rotate = {
	icon = '',
	activate = function()

	end
}

tools.scale = {
	icon = '',
	activate = function()

	end
}

tools.satchel = {
	icon = '',
	activate = function()

	end
}

tools.copy = {
	icon = '',
	activate = function(layout)
		local entity
		local entities = layout.entities
    for i = #entities, 1, -1 do
      local controller = controllerHelpers.isHovered(entities[i])
      if controller then
  			entity = controllerHelpers.getClosestEntity(controller)
      end
		end
    if entity then
      local newEntity = tools:newEntityCopy(entity)
    	tools:addToEntitiesList(entities, newEntity)
    end
	end
}

function tools:newEntityCopy(entity)
	local newEntity = {}
  newEntity.model, newEntity.scale, newEntity.typeId, newEntity.locked = entity.model, entity.scale, entity.typeId, false
	newEntity.x, newEntity.y, newEntity.z = entity.x + .1, entity.y + .1, entity.z + .1
  newEntity.angle, newEntity.ax, newEntity.ay, newEntity.az = entity.angle, entity.ax, entity.ay, entity.az

  return newEntity
end

function tools:addToEntitiesList(entities, entity)
	entities[entity] = entity
  table.insert(entities, entity)
end

tools.lock = {
	icon = '',
	activate = function()

	end
}

tools.delete = {
	icon = '',
	activate = function()

	end
}

controllerHelpers = {
	isHoveredByController = function(entity, controller)
	  if not controller then return false end
	  local function addMinimumBuffer(minx, maxx, miny, maxy, minz, maxz, scale)
	    local w, h, d = (maxx - minx) * scale, (maxy - miny) * scale, (maxz - minz) * scale
	    if w <= .005 then
	      minx = minx + .005
	    end
	    if h <= .005 then
	      miny = miny + .005
	    end
	    if d <= .005 then
	      minz = minz + .005
	    end
	    return minx, maxx, miny, maxy, minz, maxz
	  end

	  local t = entity
	  local minx, maxx, miny, maxy, minz, maxz = t.model:getAABB()
	  minx, maxx, miny, maxy, minz, maxz = addMinimumBuffer(minx, maxx, miny, maxy, minz, maxz, t.scale)
	  local cx, cy, cz = (minx + maxx) / 2 * t.scale, (miny + maxy) / 2 * t.scale, (minz + maxz) / 2 * t.scale
	  minx, maxx, miny, maxy, minz, maxz = t.x + minx * t.scale, t.x + maxx * t.scale, t.y + miny * t.scale, t.y + maxy * t.scale, t.z + minz * t.scale, t.z + maxz * t.scale
	  transform:origin()
	  transform:translate(t.x, t.y, t.z)
	  transform:translate(cx, cy, cz)
	  transform:rotate(-t.angle, t.ax, t.ay, t.az)
	  transform:translate(-cx, -cy, -cz)
	  local x, y, z = self:cursorPos(controller):unpack()
	  x, y, z = transform:transformPoint(x - t.x, y - t.y, z - t.z)
	  return x >= minx and x <= maxx and y >= miny and y <= maxy and z >= minz and z <= maxz
	end,
	isHovered = function(entity)
	  for _, controller in ipairs(controllers.get()) do
	    if self:isHoveredByController(entity, controller) then
	      return controller
	    end
	  end
	end
}

return tools
