local json = require 'cjson'

local base = (...):match('^(.*)[%./]+$') or ''
base = base:gsub('%.', '/')

local layout = {}

local function outBack(t, b, c)
  local s = 1.70158
  t = t - 1
  return c * (t * t * ((s + 1) * t + s) + 1) + b
end

----------------
-- Callbacks
----------------
function layout:init(config)
  self.config = config or {}
  self.config.cursorSize = self.config.cursorSize or .01
  self.config.haptics = type(self.config.haptics) == 'nil' and true or self.config.haptics
  self.config.inertia = type(self.config.inertia) == 'nil' and true or self.config.inertia

  self.state = { entities = {} }

  self.focus = {}
  self.hover = {}
  self.toolHoverTimes = {}

  self:loadTools()
  self:loadModels()
  self:loadAccents()
  self:refreshControllers()

  self:eachTool('init')
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
  for _, entity in ipairs(self.state.entities) do
    self:applyInertia(entity, dt)
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
  self:drawEntities()
  self:drawAccents()
  self:drawToolUI()
  self:eachTool('draw')
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

function layout:drawCursors()
  for _, controller in ipairs(self.controllers) do
    local x, y, z = self:getCursorPosition(controller)
    lovr.graphics.setColor(1, 1, 1)
    lovr.graphics.cube('fill', x, y, z, self.config.cursorSize)
  end
end

function layout:getClosestHover(controller, includeLocked, includeFocused)
  local x, y, z = self:getCursorPosition(controller)
  local minDistance, closestEntity = math.huge, nil
  for _, entity in ipairs(self.state.entities) do
    local d = (x - entity.x) ^ 2 + (y - entity.y) ^ 2 + (z - entity.z) ^ 2
    if d < minDistance and self:isHovered(entity, controller, includeLocked, includeFocused) then
      minDistance = d
      closestEntity = entity
    end
  end
  return closestEntity, math.sqrt(minDistance)
end

----------------
-- Entities
----------------
function layout:addEntity(kind, x, y, z, scale, angle, ax, ay, az)
  table.insert(self.state.entities, {
    locked = false,
    kind = kind,
    x = x, y = y, z = z,
    scale = scale,
    angle = angle, ax = ax, ay = ay, az = az,
    vx = 0, vy = 0, vz = 0, vs = 0, vax = 0, vay = 0, vaz = 0
  })

  self:dirty()
  return self.state.entities[#self.state.entities]
end

function layout:removeEntity(entity)
  for i = 1, #self.state.entities do
    if self.state.entities[i] == entity then
      table.remove(self.state.entities, i)
      break
    end
  end
  self:dirty()
end

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
  local model = self.models[t.kind]
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

function layout:drawEntities()
  for _, entity in ipairs(self.state.entities) do
    local model = self.models[entity.kind]
    local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
    local cx, cy, cz = (minx + maxx) / 2 * entity.scale, (miny + maxy) / 2 * entity.scale, (minz + maxz) / 2 * entity.scale
    lovr.graphics.push()
    lovr.graphics.translate(entity.x + cx, entity.y + cy, entity.z + cz)
    lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
    lovr.graphics.translate(-entity.x - cx, -entity.y - cy, -entity.z - cz)
    lovr.graphics.setColor(1, 1, 1)
    model:draw(entity.x, entity.y, entity.z, entity.scale)
    lovr.graphics.pop()
  end
end

function layout:drawAccents()
  for _, entity in ipairs(self.state.entities) do
    for _, key in ipairs(self.accents) do
      local accent = self.accents[key]
      if not accent.filter or accent:filter(entity) then
        accent:draw(entity)
      end
    end
  end
end

----------------
-- IO
----------------
function layout:dirty()
  if self.config.onChange then
    self.config.onChange(self.state)
  end
end

function layout:loadModels()
  local function addModel(model, key)
    self.models[key] = model
    table.insert(self.models, key)
  end

  local function loadModel(path, key)
    key = key or ('Model ' .. #self.models)

    local isModel = tostring(path) == 'Model'
    local isFile = type(path) == 'string' and lovr.filesystem.isFile(path) and (path:match('%.obj$') or path:match('%.gltf$'))
    local isFolder = type(path) == 'string' and lovr.filesystem.isDirectory(path)

    if isModel then addModel(path, key)
    elseif isFile then loadModel(lovr.filesystem.load(path)(), key)
    elseif isFolder then
      for _, file in ipairs(lovr.filesystem.getDirectoryItems(path)) do
        loadModel(path .. '/' .. file, key .. '.' .. path:gsub('%.%a+$', ''))
      end
    end
  end

  self.models = {}
  self.config.models = self.config.models or {}

  if lovr.filesystem.isDirectory(base .. '/models') then
    table.insert(self.config.models, 1, base .. '/models')
  end

  for i, path in ipairs(self.config.models) do
    loadModel(path)
  end
end

function layout:loadAccents()
  local function addAccent(accent, key)
    self.accents[key] = accent
    table.insert(self.accents, setmetatable({ layout = self }, { __index = key }))
  end

  local function loadAccent(path, key)
    key = key or ('Accent ' .. #self.accents)

    local isAccent = type(path) == 'table'
    local isFile = type(path) == 'string' and lovr.filesystem.isFile(path) and path:match('%.lua$')
    local isFolder = type(path) == 'string' and lovr.filesystem.isDirectory(path)

    if isAccent then addAccent(path, key)
    elseif isFile then loadAccent(lovr.filesystem.load(path)(), key)
    elseif isFolder then
      for _, file in ipairs(lovr.filesystem.getDirectoryItems(path)) do
        loadAccent(path .. '/' .. file, key .. '.' .. path:gsub('%.%a+$', ''))
      end
    end
  end

  self.accents = {}
  self.config.accents = self.config.accents or {}

  if lovr.filesystem.isDirectory(base .. '/accents') then
    table.insert(self.config.accents, 1, base .. '/accents')
  end

  for i, path in ipairs(self.config.accents) do
    loadAccent(path)
  end
end

----------------
-- Tools
----------------
function layout:loadTools()
  local function addTool(tool, key)
    self.tools[key] = setmetatable({ layout = self }, { __index = tool })
    table.insert(self.tools, key)
  end

  local function loadTool(path, key)
    key = key or ('Tool ' .. #self.tools)

    local isTool = type(path) == 'table'
    local isFile = type(path) == 'string' and lovr.filesystem.isFile(path) and path:match('%.lua$')
    local isFolder = type(path) == 'string' and lovr.filesystem.isDirectory(path)

    if isTool then addTool(path, path.key or key)
    elseif isFile then loadTool(lovr.filesystem.load(path)(), key)
    elseif isFolder then
      for _, file in ipairs(lovr.filesystem.getDirectoryItems(path)) do
        loadTool(path .. '/' .. file, key .. '.' .. path:gsub('%.%a+$', ''))
      end
    end
  end

  self.tools = {}
  self.config.tools = self.config.tools or {}

  if lovr.filesystem.isDirectory(base .. '/tools') then
    table.insert(self.config.tools, 1, base .. '/tools')
  end

  for i, path in ipairs(self.config.tools) do
    loadTool(path, '')
  end
end

function layout:eachTool(action, ...)
  for _, tool in ipairs(self.tools) do
    if tool[action] then tool[action](tool, ...) end
  end
end

function layout:drawToolUI()
  local offsets = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
  local haligns = { up = 'center', down = 'center', left = 'right', right = 'left' }
  local valigns = { up = 'bottom', down = 'top', left = 'middle', right = 'middle' }

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
