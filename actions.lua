local function nextObjectId(state)
  return #state.objects > 0 and (state.objects[#state.objects].id + 1) or 1
end

local function cloneDeep(x)
  if type(x) == 'table' then
    local t = {}
    for k, v in pairs(x) do t[k] = cloneDeep(v) end
    return t
  else
    return x
  end
end

return {
  add = function(state, action, history)
    state = cloneDeep(state)

    state.objects[#state.objects + 1] = {
      id = nextObjectId(state),
      asset = action.asset,
      x = action.x, y = action.y, z = action.z, scale = action.scale,
      angle = action.angle, ax = action.ax, ay = action.ay, az = action.az
    }

    return state
  end,

  remove = function(state, action, history)
    for i, object in ipairs(state.objects) do
      if object.id == action.id then
        state = cloneDeep(state)
        table.remove(state.objects, i)
        break
      end
    end

    return state
  end,

  transform = function(state, action, history)
    for i, object in ipairs(state.objects) do
      if object.id == action.id then
        state = cloneDeep(state)
        object = state.objects[i]
        object.x = action.x
        object.y = action.y
        object.z = action.z
        object.scale = action.scale
        object.angle = action.angle
        object.ax = action.ax
        object.ay = action.ay
        object.az = action.az
        state.objects[i] = object
        break
      end
    end

    return state
  end
}
