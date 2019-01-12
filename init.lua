local base = ((... or '') .. '/'):gsub('%.', '/'):gsub('/?init', ''):gsub('^/+', '')

local json = require('cjson')
local actions = require(base .. 'actions')

local layout = {}

function layout:init(filename, config)
  self.config = config or {}
  self.pool = lovr.math.newPool(4096, true)
  self.tools = self:glob('tools', { 'lua' }, true)
  self.assets = self:glob('assets', { 'lua', 'obj', 'gltf', 'glb' }, false)
  self.accents = self:glob('accents', { 'lua' }, true)
  self.transform = self.pool:mat4():save()
  self:refreshControllers()
  self:load(filename)
end

function layout:save(filename)
  filename = filename or self.filename
  if not filename then return false end
  return lovr.filesystem.write(filename, json.encode(self.state))
end

function layout:load(filename)
  self.state = filename and lovr.filesystem.isFile(filename) and json.decode(lovr.filesystem.read(filename)) or { objects = {} }
  self.history = { undo = {}, redo = {} }
  self.filename = filename
  self.objects = {}
  self:sync()
end

function layout:dispatch(action)
  assert(actions[action.type], string.format('No handler for action %q', action.type or 'nil'))
  local state = actions[action.type](self.state, action, self.history)

  if self.state ~= state then
    table.insert(self.history.undo, self.state)
    self.history.redo = {}
    self.state = state
    self:sync()
  end
end

function layout:undo()
  if #self.history.undo > 0 then
    table.insert(self.history.redo, self.state)
    self.state = table.remove(self.history.undo)
    self:sync()
  end
end

function layout:redo()
  if #self.history.redo > 0 then
    table.insert(self.history.undo, self.state)
    self.state = table.remove(self.history.redo)
    self:sync()
  end
end

function layout:sync()
  local lookup = {}

  -- Add objects in the level that we don't know about
  for _, data in ipairs(self.state.objects) do
    local id = data.id

    if not self.objects[id] then
      self.objects[id] = setmetatable({
        id = id,
        data = data,
        asset = self.assets[data.asset],
        position = self.pool:vec3():save(),
        rotation = self.pool:quat():save(),
        scale = 1,
        locked = false,
        hovered = false
      }, self.assets[data.asset])
    end

    local object = self.objects[id]
    object.data = data
    object.position:set(data.x, data.y, data.z)
    object.rotation:set(data.angle, data.ax, data.ay, data.az)
    object.scale = data.scale
    object.locked = data.locked
    lookup[id] = true
  end

  -- Remove objects that aren't in the level anymore
  for id in pairs(self.objects) do
    if not lookup[id] then
      for _, controller in ipairs(self.controllers) do
        if self.controllers[controller].hover == self.objects[id] then
          self.controllers[controller].hover = nil
        end
      end

      self.objects[id] = nil
    end
  end

  self:save()
end

function layout:translate(...)
  self.transform:translate(...)
end

function layout:rotate(...)
  self.transform:rotate(...)
end

function layout:scale(...)
  self.transform:scale(...)
end

function layout:getTransform(transform)
  return self.transform:copy()
end

function layout:setTransform(transform)
  self.transform:set(transform)
end

function layout:update(dt)
  self.pool:drain()

  for _, tool in ipairs(self.tools) do
    if tool.update then
      tool:update(dt)
    end
  end

  self:updateHovers()
end

function layout:draw()
  lovr.graphics.push()
  lovr.graphics.transform(self.transform)

  for _, object in pairs(self.objects) do
    if object.draw then
      object:draw()
    end

    for _, accent in ipairs(self.accents) do
      if not accent.filter or accent:filter(object) then
        accent:draw(object)
      end
    end
  end

  lovr.graphics.pop()

  for _, tool in ipairs(self.tools) do
    if tool.draw then
      tool:draw()
    end
  end

  for _, controller in ipairs(self.controllers) do
    lovr.graphics.cube('fill', self:cursorPosition(controller, true), .01)
  end
end

function layout:controllerpressed(controller, button)
  self:updateHovers()
  for _, tool in ipairs(self.tools) do
    if tool.controllerpressed then
      tool:controllerpressed(controller, button)
    end
  end
end

function layout:controllerreleased(controller, button)
  self:updateHovers()
  for _, tool in ipairs(self.tools) do
    if tool.controllerreleased then
      tool:controllerreleased(controller, button)
    end
  end
end

function layout:refreshControllers()
  self.controllers = lovr.headset.getControllers()
  for i, controller in ipairs(self.controllers) do
    self.controllers[controller] = {
      instance = controller,
      other = self.controllers[3 - i],
      hover = nil
    }
  end
end

layout.controlleradded = layout.refreshControllers
layout.controllerremoved = layout.refreshControllers

function layout:cursorPosition(controller, raw)
  local offset = .075
  local direction = self.pool:vec3(lovr.math.orientationToDirection(controller:getOrientation()))
  local position = self.pool:vec3(controller:getPosition()):add(direction:mul(offset))
  return raw and position or self.pool:vec3(self.transform:copy(self.pool):invert():transformPoint(position))
end

function layout:updateHovers()
  for _, object in pairs(self.objects) do
    object.hovered = false
  end

  for _, controller in ipairs(self.controllers) do
    local object = self:getClosestHover(controller)

    if self.controllers[controller].hover ~= object then
      controller:vibrate(object and .001 or .0005)
      self.controllers[controller].hover = object
    end

    if object then
      object.hovered = true
    end
  end
end

function layout:getClosestHover(controller, lockpick)
  local cursor = self:cursorPosition(controller)
  local distance, closest = math.huge, nil

  for _, object in pairs(self.objects) do
    if not object.locked or lockpick then
      local d = cursor:distance(object.position)
      if d < distance and self:isHovered(object, controller) then
        distance = d
        closest = object
      end
    end
  end

  return closest, distance
end

function layout:isHovered(object, controller)
  if not object.asset.model then return false end

  local controllers = controller and { controller } or self.controllers
  local center, size = self:getModelBox(object.asset.model, object.scale)

  for _, controller in ipairs(controllers) do
    if self:testPointBox(self:cursorPosition(controller), object.position + center, object.rotation, size) then
      return controller
    end
  end

  return false
end

function layout:getModelBox(model, scale)
  scale = scale or 1
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local min = self.pool:vec3(minx, miny, minz)
  local max = self.pool:vec3(maxx, maxy, maxz)
  local center = max:copy(self.pool):add(min):mul(.5)
  local size = max:sub(min)
  return center:mul(scale), size:mul(scale)
end

function layout:testPointBox(point, position, rotation, scale)
  local transform = self.pool:mat4()
  transform:translate(position)
  transform:rotate(rotation)
  transform:scale(scale)
  transform:invert()
  x, y, z = transform:transformPoint(point)
  return x >= -.5 and y >= -.5 and z >= -.5 and x <= .5 and y <= .5 and z <= .5
end

function layout:touchpadDirection(controller)
  if not controller:isTouched('touchpad') then return nil end
  local x, y = controller:getAxis('touchx'), controller:getAxis('touchy')
  local angle = math.atan2(y, x)
  local quadrant = math.floor((angle % (2 * math.pi) + (math.pi / 4)) / (math.pi / 2))
  return ({ [0] = 'right', [1] = 'up', [2] = 'left', [3] = 'down' })[quadrant]
end

function layout:glob(kind, extensions, instantiate)
  local result = {}

  local loaders = {
    lua = function(path) return select(2, assert(pcall(select(2, assert(pcall(lovr.filesystem.load, path)))))) end, -- haha
    obj = function(path) return { model = lovr.graphics.newModel(path) } end,
    gltf = function(path) return { model = lovr.graphics.newModel(path) } end,
    glb = function(path) return { model = lovr.graphics.newModel(path) } end
  }

  local exts = {}
  for i, ext in ipairs(extensions) do exts[ext] = true end

  local function loadItem(path, key)
    if type(path) == 'table' then
      key = key or (kind:gsub('^%a', string.upper):gsub('s$', '') .. ' ' .. #result)
      local instance = instantiate and setmetatable({ layout = self }, { __index = path }) or path
      if not instantiate then instance.__index = instance end
      instance.key = key
      result[key] = instance
      table.insert(result, instance)
      if instance.init then instance:init() end
    elseif lovr.filesystem.isFile(path) then
      local ext = path:match('%.(%a+)$')
      if loaders[ext] and exts[ext] then
        loadItem(loaders[ext](path), key)
      end
    elseif lovr.filesystem.isDirectory(path) then
      for _, file in ipairs(lovr.filesystem.getDirectoryItems(path)) do
        if not file:match('^%.') then
          loadItem(path .. '/' .. file, key .. (#key > 0 and '.' or '') .. file:gsub('%.%a+$', ''))
        end
      end
    end
  end

  self.config[kind] = self.config[kind] or {}
  if type(self.config[kind]) == 'string' then self.config[kind] = { self.config[kind] } end

  if lovr.filesystem.isDirectory(base .. kind) then
    table.insert(self.config[kind], 1, base .. kind)
  end

  for i, path in ipairs(self.config[kind]) do
    loadItem(path, '')
  end

  return result
end

return layout
