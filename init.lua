local base = (... or ''):match('^(.*)[%./]+$'):gsub('%.', '/')

local json = require 'cjson'
local level = require (base .. '/level')

local layout = {}

----------------
-- Callbacks
----------------
function layout:init(config, data)
  self.config = config or {}
  self.config.cursorSize = self.config.cursorSize or .01
  self.config.haptics = type(self.config.haptics) == 'nil' and true or self.config.haptics
  self.config.inertia = type(self.config.inertia) == 'nil' and true or self.config.inertia

  self.focus = {}
  self.hover = {}
  self.toolHoverTimes = {}

  self:refreshControllers()

  self:glob('tools', { 'lua' }, true)
  self:glob('assets', { 'lua', 'obj', 'gltf', 'glb' }, true)
  self:glob('accents', { 'lua' }, true)

  self:eachTool('init')

  self:load(nil)
end

function layout:load(data)
  if type(data) == 'string' then
    if data:match('^%s*%{') then
      data = json.decode(data)
    elseif lovr.filesystem.isFile(data) then
      data = json.decode(lovr.filesystem.read(data))
    else
      error(string.format('Unable to read level data from %q', data))
    end
  end

  self.level = level:new(data)
  self.objects = {}
  self:sync()
end

function layout:sync()
  for id, object in ipairs(self.objects) do
    if not self.level:findObject(object.id) then
      self.objects[id] = nil
    end
  end

  for id, data in ipairs(self.level.objects) do
    if not self.objects[id] then
      assert(self.assets[data.type], string.format('Unknown object type %q', data.type))
      self.objects[id] = setmetatable({
        position = lovr.math.vec3():save(),
        orientation = lovr.math.quat():save(),
        scale = 1
      }, { __index = self.assets[data.type] })
    end

    local object = self.objects[id]
    object.position:set(data.x, data.y, data.z)
    object.rotation:set(data.angle, data.ax, data.ay, data.az)
    object.scale = data.scale
  end
end

function layout:update(dt)

  -- Update hover state
  for _, controller in ipairs(self.controllers) do
    local hover = self:getClosestHover(controller)
    if hover ~= self.hover[controller] then
      if hover then
        self:vibrate(controller, .002)
        if self.config.onHover then self.config.onHover(entity, controller) end
      end

      self.hover[controller] = hover
      self:eachTool('hover', entity, hovered, controller)
    end
  end

  -- Apply inertia
  for _, object in ipairs(self.objects) do
    self:applyInertia(object, dt)
  end

  -- Use continuous tools
  for controller, focus in pairs(self.focus) do
    focus.tool:use(controller, focus.entity, dt)
  end

  self:eachTool('update', dt)

  local directions = { up = true, down = true, right = true, left = true }
  for _, tool in ipairs(self.tools) do
    if tool.button then
      for _, controller in ipairs(self.controllers) do
        local entity = self:getClosestHover(controller, tool.lockpick)
        local context = entity and 'hover' or 'default'

        if tool.context == context then
          local isTouched = false

          if directions[tool.button] then
            isTouched = controller:isTouched('touchpad') and self:getTouchpadDirection(controller) == tool.button
          else
            isTouched = controller:isTouched(tool.button)
          end

          self.toolHoverTimes[controller] = self.toolHoverTimes[controller] or {}
          self.toolHoverTimes[controller][tool] = isTouched and ((self.toolHoverTimes[controller][tool] or 0) + dt) or 0
        end
      end
    end
  end
end

function layout:draw()
  self:drawCursors()
  self:drawObjects()
  self:drawAccents()
  self:drawToolUI()
  self:eachTool('draw')
end

function layout:drawCursors()
  for _, controller in ipairs(self.controllers) do
    local x, y, z = self:getCursorPosition(controller)
    lovr.graphics.setColor(1, 1, 1)
    lovr.graphics.cube('fill', x, y, z, self.config.cursorSize)
  end
end

function layout:drawObjects()
  for _, object in ipairs(self.objects) do
    object:draw()
  end
end

function layout:drawAccents()
  for _, object in ipairs(self.objects) do
    for _, key in ipairs(self.accents) do
      local accent = self.accents[key]
      if not accent.filter or accent:filter(object) then
        accent:draw(object)
      end
    end
  end
end

----------------
-- Controllers
----------------
function layout:controllerpressed(controller, rawButton)
  local button = rawButton == 'touchpad' and self:getTouchpadDirection(controller) or rawButton

  -- Tries to use a tool.  This or parts of it should be extracted into in the 'tools' section below
  local function useTool(tool)
    if tool.button ~= button then return end

    local entity = self:getClosestHover(controller, tool.lockpick)
    local context = entity and 'hover' or 'default'
    if tool.context ~= context then return end

    -- A continuous tool calls start once, then calls use in update
    -- Non continuous tools just call use once when the button is pressed
    -- TODO is this weird
    if tool.continuous then
      self.focus[controller] = { tool = tool, entity = entity }
      self:vibrate(controller, .003)

      if tool.start then tool:start(controller, entity) end
    else
      if tool.use then tool:use(controller, entity) end
      self:vibrate(controller, .003)
    end
  end

  self:eachTool('controllerpressed', controller, rawButton)

  if self.focus[controller] then
    local tool = self.focus[controller].tool
    if tool.modifiers and tool.modifiers[button] then
      tool.modifiers[button](tool, controller)
    end
  else
    for _, tool in ipairs(self.tools) do
      useTool(tool)
    end
  end
end

function layout:controllerreleased(controller, rawButton)
  local button = rawButton == 'touchpad' and self:getTouchpadDirection(controller) or rawButton
  self:eachTool('controllerreleased', controller, rawButton)

  if self.focus[controller] then
    local tool = self.focus[controller].tool
    if tool.button == button then
      if tool.stop then tool:stop(controller, self.focus[controller].entity) end
      self.focus[controller] = nil
    end
  end
end

function layout:controlleradded(controller)
  self:refreshControllers()
end

function layout:controllerremoved(controller)
  self.hover[controller] = nil

  if self.focus[controller] then
    if self.focus[controller].tool.stop then self.focus[controller].tool:stop() end
    self.focus[controller] = nil
  end

  self:refreshControllers()
end

function layout:refreshControllers()
  self.controllers = lovr.headset.getControllers()
  for i, controller in ipairs(self.controllers) do
    self.controllers[controller] = self.controllers[3 - i]
  end
end

function layout:getOtherController(controller)
  return self.controllers[controller]
end

function layout:getTouchpadDirection(controller)
  local touchx, touchy = controller:getAxis('touchx'), controller:getAxis('touchy')
  local angle, distance = math.atan2(touchy, touchx), math.sqrt(touchx * touchx + touchy * touchy)
  angle = math.floor((angle % (2 * math.pi) + (math.pi / 4)) / (math.pi / 2))
  return ({ [0] = 'right', [1] = 'up', [2] = 'left', [3] = 'down' })[angle] or 'right'
end

function layout:vibrate(controller, ...)
  if self.config.haptics then controller:vibrate(...) end
end

----------------
-- Cursors
----------------
function layout:getCursorPosition(controller)
  local offset = .075
  local x, y, z = controller:getPosition()
  local ox, oy, oz = lovr.math.orientationToDirection(controller:getOrientation())
  return x + ox * offset, y + oy * offset, z + oz * offset
end

function layout:getClosestHover(controller, includeLocked, includeFocused)
  local x, y, z = self:getCursorPosition(controller)
  local minDistance, closestObject = math.huge, nil
  for _, object in ipairs(self.objects) do
    local d = (x - object.x) ^ 2 + (y - object.y) ^ 2 + (z - object.z) ^ 2
    if d < minDistance and self:isHovered(object, controller, includeLocked, includeFocused) then
      minDistance = d
      closestObject = object
    end
  end
  return closestObject, math.sqrt(minDistance)
end

----------------
-- Entities
----------------
function layout:isHovered(entity, controller, includeLocked, includeFocused)

  -- Currently if a controller is focusing on an entity then it can't hover over other entities.
  -- This is okay right now but it prohibits doing interesting things like dragging an entity onto
  -- another entity, so it may need to be adjusted in the future.
  if not controller or (not includeFocused and self.focus[controller]) then return false end
  if not includeLocked and entity.locked then return false end

  local function addMinimumBuffer(minx, maxx, miny, maxy, minz, maxz, scale)
    local w, h, d = (maxx - minx) * scale, (maxy - miny) * scale, (maxz - minz) * scale
    if w <= .005 then minx = minx + .005 end
    if h <= .005 then miny = miny + .005 end
    if d <= .005 then minz = minz + .005 end
    return minx, maxx, miny, maxy, minz, maxz
  end

  local t = entity
  local model = entity.model
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  minx, maxx, miny, maxy, minz, maxz = addMinimumBuffer(minx, maxx, miny, maxy, minz, maxz, t.scale)
  local cx, cy, cz = (minx + maxx) / 2 * t.scale, (miny + maxy) / 2 * t.scale, (minz + maxz) / 2 * t.scale
  minx, maxx, miny, maxy, minz, maxz = t.x + minx * t.scale, t.x + maxx * t.scale, t.y + miny * t.scale, t.y + maxy * t.scale, t.z + minz * t.scale, t.z + maxz * t.scale
  local transform = lovr.math.mat4()
  transform:translate(t.x, t.y, t.z)
  transform:translate(cx, cy, cz)
  transform:rotate(-t.angle, t.ax, t.ay, t.az)
  transform:translate(-cx, -cy, -cz)
  local x, y, z = self:getCursorPosition(controller)
  x, y, z = transform:transformPoint(x - t.x, y - t.y, z - t.z)
  return x >= minx and x <= maxx and y >= miny and y <= maxy and z >= minz and z <= maxz
end

function layout:isFocused(entity, controller)
  for c, focus in pairs(self.focus) do
    if (not controller or c == controller) and focus.entity == entity then
      return true
    end
  end

  return false
end

function layout:applyInertia(entity, dt)
  if not self.config.inertia then return end

  entity.x = entity.x + entity.vx * dt
  entity.y = entity.y + entity.vy * dt
  entity.z = entity.z + entity.vz * dt
  entity.scale = entity.scale + entity.vs * dt

  local v = lovr.math.vec3(entity.vax, entity.vay, entity.vaz)
  local angle = v:length() * dt
  local axis = v:normalize()
  local rot = lovr.math.quat(angle, axis)
  local q = lovr.math.quat(entity.angle, entity.ax, entity.ay, entity.az) * rot
  entity.angle, entity.ax, entity.ay, entity.az = q:getAngleAxis()

  local function lerp(x, y, t) return x + (y - x) * t end
  local function decay(x, t) return lerp(x, 0, 1 - math.exp(-t * dt)) end

  local rate = 6
  entity.vx = decay(entity.vx, rate)
  entity.vy = decay(entity.vy, rate)
  entity.vz = decay(entity.vz, rate)
  entity.vs = decay(entity.vs, rate)
  entity.vax = decay(entity.vax, rate)
  entity.vay = decay(entity.vay, rate)
  entity.vaz = decay(entity.vaz, rate)
end

function layout:glob(kind, extensions, instantiate)
  local result = {}

  local loaders = {
    lua = function(path)
      local ok, chunk = pcall(lovr.filesystem.load, path)
      assert(ok, 'Could not load %q: %s', path, chunk)
      local ok, res = pcall(chunk)
      assert(ok, 'Could not load %q: %s', path, result)
      return res
    end,

    obj = function(path) return { model = lovr.graphics.newModel(path) } end,
    gltf = function(path) return { model = lovr.graphics.newModel(path) } end,
    glb = function(path) return { model = lovr.graphics.newModel(path) } end
  }

  local exts = {}
  for i, ext in ipairs(extensions) do exts[ext] = true end

  local function loadItem(path, key)
    key = key or (kind:gsub('^%a', string.upper):gsub('s$', '') .. ' ' .. #result)

    if type(path) == 'table' then
      local instance = instantiate and setmetatable({ layout = self }, { __index = item }) or item
      result[key] = instance
      table.insert(result, instance)
    elseif lovr.filesystem.isFile(path) then
      local ext = path:match('%.(%a+)$')
      if loaders[ext] and exts[ext] then
        loadItem(loaders[ext](path), key)
      end
    elseif lovr.filesystem.isDirectory(path) then
      for _, file in ipairs(lovr.filesystem.getDirectoryItems(path)) do
        loadItem(path .. '/' .. file, key .. '.' .. path:gsub('%.%a+$', ''))
      end
    end
  end

  self.config[kind] = self.config[kind] or {}
  if lovr.filesystem.isDirectory(base .. '/' .. kind) then
    table.insert(self.config.tools, 1, base .. '/' .. kind)
  end

  for i, path in ipairs(self.config[kind]) do
    loadItem(path, '')
  end

  self[kind] = result
end

----------------
-- Tools
----------------
function layout:eachTool(action, ...)
  for _, tool in ipairs(self.tools) do
    if tool[action] then tool[action](tool, ...) end
  end
end

function layout:drawToolUI()
  local offsets = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
  local haligns = { up = 'center', down = 'center', left = 'right', right = 'left' }
  local valigns = { up = 'bottom', down = 'top', left = 'middle', right = 'middle' }

  local function outBack(t, b, c)
    local s = 1.70158
    t = t - 1
    return c * (t * t * ((s + 1) * t + s) + 1) + b
  end

  lovr.graphics.setColor(1, 1, 1)
  for _, tool in ipairs(self.tools) do
    if tool.icon and tool.button and offsets[tool.button] then
      local offset = offsets[tool.button]

      -- Pls add lovr.graphics.plane(texture, ...) overload
      self.toolMaterial = self.toolMaterial or lovr.graphics.newMaterial()
      self.toolMaterial:setTexture(tool.icon)

      local iconSize = .03
      for _, controller in ipairs(self.controllers) do
        local entity = self:getClosestHover(controller, tool.lockpick)
        local context = entity and 'hover' or 'default'

        if tool.context == context then
          local x, y, z, angle, ax, ay, az = controller:getPose()
          lovr.graphics.push()
          lovr.graphics.transform(x, y, z)
          lovr.graphics.rotate(angle, ax, ay, az)
          lovr.graphics.rotate(-math.pi / 2, 1, 0, 0) -- Make plane parallel to touchpad
          if lovr.headset.getType() == 'vive' then
            lovr.graphics.translate(0, -.048, 0)
            lovr.graphics.rotate(.1, 1, 0, 0)
          end

          local hoverTimeDelay = .5 -- TODO config/constant
          local hoverTime = self.toolHoverTimes[controller][tool]
          if hoverTime > hoverTimeDelay then
            local halign = haligns[tool.button]
            local valign = valigns[tool.button]
            lovr.graphics.setColor(1, 1, 1, math.min((hoverTime - hoverTimeDelay) * 6, 1))
            lovr.graphics.print(tool.name, offset[1] * .04, offset[2] * .04, .01, iconSize * .75, 0, 0, 0, 0, nil, halign, valign)
            lovr.graphics.setColor(1, 1, 1)
          end

          lovr.graphics.setDepthTest('lequal', false)

          local iconScale = 1 + outBack(math.min(hoverTime * 5, 1), 0, 1) * .5
          lovr.graphics.plane(self.toolMaterial, offset[1] * .02, offset[2] * .02, .01, iconSize * iconScale, iconSize * iconScale)
          lovr.graphics.pop()

          lovr.graphics.setDepthTest('lequal', true)
        end
      end
    end
  end
end

return layout
