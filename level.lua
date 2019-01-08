local level = {}
level.__index = level

function level:new(data)
  local level = setmetatable(data or {}, level)
  level.objects = level.objects or {}
  return level
end

return level
