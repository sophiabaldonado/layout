local grid = {}
grid.__index = grid

local epsilon = 1 / 1e6

local function round(x, n)
  n = n or 1
  return x >= 0 and math.floor(x / n + .5) * n or math.ceil(x / n - .5) * n
end

function grid.new(width, depth, size, pattern, fill)
  local self = setmetatable({}, grid)
  self.width = width or 10
  self.depth = depth or 10
  self.size = size or 1
  self.pattern = pattern or { 1 }
  self.fill = fill or nil
  return self
end

function grid:draw(...)
  local r, g, b, a = lovr.graphics.getColor()
  local w, d, s = round(self.width / 2, self.size), round(self.depth / 2, self.size), self.size

  lovr.graphics.push()
  lovr.graphics.transform(...)

  if self.fill then
    lovr.graphics.setColor(self.fill)
    lovr.graphics.push()
    lovr.graphics.scale(w * 2, d * 2)
    lovr.graphics.plane('fill', 0, -epsilon, 0, 1, math.pi / 2, 1, 0, 0)
    lovr.graphics.pop()
  end

  for x = -w, w + epsilon, s do
    local i = 1 + round(x / s) % #self.pattern
    lovr.graphics.setColor(r, g, b, a * self.pattern[i])
    lovr.graphics.line(x, 0, -d, x, 0, d)
  end

  for z = -d, d + epsilon, s do
    local i = 1 + round(z / s) % #self.pattern
    lovr.graphics.setColor(r, g, b, a * self.pattern[i])
    lovr.graphics.line(-w, 0, z, w, 0, z)
  end

  lovr.graphics.pop()
  lovr.graphics.setColor(r, g, b, a)
end

return grid
