local util = {}

function util.each(t, f, iterator)
  iterator = iterator or pairs
  for k, v in iterator(t) do
    f(v, k)
  end
end

function util.copy(x)
  local t = type(x)
  if t ~= 'table' then return x end
  local y = {}
  for k, v in next, x, nil do y[k] = util.copy(v) end
  setmetatable(y, getmetatable(x))
  return y
end

function util.lerp(x, y, z)
  return x + (y - x) * z
end

function util.interpolate(t1, t2, z)
  local interp = util.copy(t1)
  for k, v in pairs(interp) do
    if t2[k] then
      if type(v) == 'table' then interp[k] = util.interpolate(t1[k], t2[k], z)
      elseif type(v) == 'number' then
        if k == 'angle' then interp[k] = util.anglerp(t1[k], t2[k], z)
        else interp[k] = util.lerp(t1[k], t2[k], z) end
      end
    end
  end
  return interp
end

function util.angle(x1, y1, x2, y2)
  return math.atan2(y2 - y1, x2 - x1)
end

function util.distance(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

return util
