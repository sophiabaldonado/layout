local base = ((... or '') .. '/'):gsub('%.', '/'):gsub('/?init', ''):gsub('^/+', '')

local function copy(x)
  if type(x) ~= 'table' then
    return x
  else
    local t = {}
    for k, v in pairs(x) do
      t[k] = copy(v)
    end
    return t
  end
end

----------------
-- Model
----------------
local Model = {}

function Model:init()
  self.models = {}

  self.thread = lovr.thread.newThread [[
    data = require 'lovr.data'
    thread = require 'lovr.thread'
    inbox = thread.getChannel('layout.tools.model.requests')
    outbox = thread.getChannel('layout.tools.model.responses')

    while true do
      local filename = inbox:pop(true)
      local model = data.newModelData(filename)
      outbox:push(filename)
      outbox:push(model, false)
    end
  ]]

  self.thread:start()
  self.inbox = lovr.thread.getChannel('layout.tools.model.responses')
  self.outbox = lovr.thread.getChannel('layout.tools.model.requests')
end

function Model:update(dt)
  while self.inbox:peek() do
    local filename = self.inbox:pop()
    local modelData = self.inbox:pop(true)
    self.models[filename] = lovr.graphics.newModel(modelData)
  end
end

function Model:getModel(filename)
  if not filename then return end

  if self.models[filename] ~= nil then
    return self.models[filename]
  end

  self.outbox:push(filename)
  self.models[filename] = false
  return self.models[filename]
end


----------------
-- Satchel
----------------
local Satchel = {}
Satchel.itemSize = .09

function Satchel:init()
  self.active = true
  self.transform = lovr.math.newMat4():translate(0, 1, -1)
  self.assetList = {}

  local group = self.layout:addObject('layout.group')
  group.x, group.y, group.z = 0, 1, -3
  group.angle, group.ax, group.ay, group.az = 0, 0, 0, 0
  table.insert(self.layout.objects, group)
  local i = 0
  for key, asset in pairs(self.layout.assets) do
    table.insert(self.assetList, asset)
    local object = self.layout:addObject(key)
    object.x = i
    object.angle, object.ax, object.ay, object.az = 0, 0, 0, 0
    table.insert(group.objects, object)
    i = i + 1
  end
end

function Satchel:draw()
  if not self.active then return end

  lovr.graphics.push()
  lovr.graphics.transform(self.transform)
  lovr.graphics.setColor(1, 1, 1)

  for i, asset, x, y in self:items() do
    local model = asset.model and self.layout.tools.model:getModel(asset.model)
    if model then
      local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
      local width, height, depth = maxx - minx, maxy - miny, maxz - minz
      local scale = self.itemSize / math.max(width, height, depth)
      local cx, cy, cz = (minx + maxx) / 2 * scale, (miny + maxy) / 2 * scale, (minz + maxz) / 2 * scale
      model:draw(x - cx, y - cy, 0 - cz, scale, lovr.timer.getTime() * .2, 0, 1, 0)
    end
  end

  lovr.graphics.pop()
end

function Satchel:items()
  local count = #self.assetList
  local spacing = self.itemSize * 2
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local i = 0

  return function()
    i = i + 1
    local asset = self.assetList[i]
    if not asset then return end
    local col = 1 + ((i - 1) % perRow)
    local row = math.ceil(i / perRow)
    local x = -spacing * (perRow - 1) / 2 + spacing * (col - 1)
    local y = spacing * (rows - 1) / 2 - spacing * (row - 1)
    return i, asset, x, y
  end
end


----------------
-- Render
----------------
local Render = {}

function Render:draw()
  local function render(o)
    lovr.graphics.push()
    lovr.graphics.transform(o.x, o.y, o.z, o.sx, o.sy, o.sz, o.angle, o.ax, o.ay, o.az)

    local model = self.layout.tools.model:getModel(o.model)

    if model then
      model:draw()
    end

    if o.objects then
      for i, child in ipairs(o.objects) do
        render(child)
      end
    end

    lovr.graphics.pop()
  end

  local camera = self.layout.tools.camera

  if camera then
    camera:push()
  end

  for _, o in ipairs(self.layout.objects) do
    render(o)
  end

  if camera then
    camera:pop()
  end
end


----------------
-- Cursor
----------------
local Cursor = {}

function Cursor:getPosition(hand)
  if not lovr.headset.isTracked(hand) then
    return vec3(0)
  end

  local x, y, z, angle, ax, ay, az = lovr.headset.getPose(hand)
  local position = vec3(x, y, z)
  local direction = vec3(quat(angle, ax, ay, az):direction())
  local offset = .075
  return position:add(direction:mul(offset))
end

function Cursor:draw()
  local shader = lovr.graphics.getShader()
  lovr.graphics.setShader()
  for _, hand in ipairs(lovr.headset.getHands()) do
    lovr.graphics.setColor(0xffffff)
    lovr.graphics.setPointSize(7)
    lovr.graphics.points(self:getPosition(hand))
  end
  lovr.graphics.setShader(shader)
end


----------------
-- Camera
----------------
local Camera = {}

function Camera:init()
  self.matrix = lovr.math.newMat4()
  self.inverse = lovr.math.newMat4()
  self.invert = true
end

function Camera:push()
  lovr.graphics.push()
  lovr.graphics.transform(self.matrix)
end

function Camera:pop()
  lovr.graphics.pop()
end

function Camera:move(...)
  self.matrix:translate(...)
  self.invert = true
end

function Camera:rotate(...)
  self.matrix:rotate(...)
  self.invert = true
end

function Camera:scale(factor)
  self.matrix:scale(factor)
  self.invert = true
end

function Camera:transform(...)
  return self.matrix:mul(...)
end

function Camera:untransform(...)
  if self.invert then
    self.inverse:set(self.matrix):invert()
    self.invert = false
  end

  return self.inverse:mul(...)
end


----------------
-- Outline
----------------
local Outline = {}

function Outline:draw()
  local function render(o) -- TODO this looks suspiciously similar to Render:draw
    lovr.graphics.push()
    lovr.graphics.transform(o.x, o.y, o.z, o.sx, o.sy, o.sz, o.angle, o.ax, o.ay, o.az)

    local model = self.layout.tools.model:getModel(o.model)
    if model then
      local scale = vec3(o.sx, o.sy, o.sz)
      local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
      local min = vec3(minx, miny, minz)
      local max = vec3(maxx, maxy, maxz)
      local center = vec3(max):add(min):mul(.5):mul(scale)
      local size = max:sub(min):mul(scale)
      lovr.graphics.box('line', center, size)
    else
      -- TODO hi I am probably a group or some other weird asset, what should I do?
    end

    if o.objects then
      for _, child in ipairs(o.objects) do
        render(child)
      end
    end

    lovr.graphics.pop()
  end

  local camera = self.layout.tools.camera

  if camera then
    camera:push()
  end

  for _, o in ipairs(self.layout.objects) do
    render(o)
  end

  if camera then
    camera:pop()
  end
end


----------------
-- Layout!
----------------
local layout = {}

function layout:init(config)
  self.loaders = {
    {
      match = { '%.gltf$', '%.glb' },
      key = function(filename)
        return filename:gsub('^/+', ''):gsub('%.%a+$', ''):gsub('/', '.')
      end,
      load = function(filename)
        return { model = filename }
      end
    }
  }

  self.properties = {
    ['.'] = {
      x = 'number',
      y = 'number',
      z = 'number',
      sx = { type = 'number', default = 1 },
      sy = { type = 'number', default = 1 },
      sz = { type = 'number', default = 1 },
      angle = 'number',
      ax = 'number',
      ay = 'number',
      az = 'number',
      locked = { type = 'boolean', default = false }
    }
  }

  self.tools = {
    model = Model,
    satchel = Satchel,
    render = Render,
    cursor = Cursor,
    camera = Camera,
    outline = Outline
  }

  for key, tool in pairs(config.tools or {}) do
    self.tools[key] = tool or nil
  end

  for i, loader in ipairs(config.loaders or {}) do
    table.insert(self.loaders, loader)
  end

  self.assets = {
    ['layout.group'] = {
      properties = {
        objects = { type = 'table', default = {} }
      }
    }
  }

  local function glob(dir)
    for i, file in ipairs(lovr.filesystem.getDirectoryItems(dir)) do
      local path = dir .. '/' .. file
      if lovr.filesystem.isDirectory(path) then
        glob(path)
      else
        for _, loader in ipairs(self.loaders) do
          for _, pattern in ipairs(loader.match) do
            if path:match(pattern) then
              -- TODO merge data into asset if it already exists
              self.assets[loader.key(path:gsub(config.root, '', 1))] = loader.load(path)
            end
          end
        end
      end
    end
  end

  glob(config.root)

  for key, asset in pairs(self.assets) do
    asset.properties = asset.properties or {}

    -- TODO loop over patterns in shortest-to-longest match order for proper inheritance
    -- TODO merge config.properties into layout/self .properties
    for pattern, properties in pairs(layout.properties) do
      if key:match(pattern) then
        for property, info in pairs(properties) do
          info = type(info) == 'string' and { type = info } or info
          asset.properties[property] = info
        end
      end
    end
  end

  self.objects = {}

  for _, tool in pairs(self.tools) do
    tool.layout = self

    if tool.init then
      tool:init()
    end
  end
end

function layout:update(dt)
  for _, tool in pairs(self.tools) do
    if tool.update then
      tool:update(dt)
    end
  end
end

function layout:draw()
  for _, tool in pairs(self.tools) do
    if tool.draw then
      tool:draw()
    end
  end
end

function layout:addObject(kind)
  local asset = self.assets[kind]
  local object = setmetatable({}, { __index = asset }) -- TODO don't create a new metatable for every instance
  for property, info in pairs(asset.properties) do
    object[property] = copy(info.default)
  end
  return object
end

return layout
