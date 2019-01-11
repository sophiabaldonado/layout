local Border = {}

function Border:filter(object)
  return object.asset.model
end

function Border:draw(object)
  local center, size = self.layout.util.getModelBox(object.asset.model, object.scale)
  if object.locked then
    lovr.graphics.setColor(.988, .835, .333, .3)
  else
    lovr.graphics.setColor(1, 1, 1, object.hovered and 1 or .5)
  end
  lovr.graphics.box('line', object.position + center, size, object.rotation)
  lovr.graphics.setColor(1, 1, 1)
end

return Border
