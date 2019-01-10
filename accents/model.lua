local Model = {}

function Model:filter(object)
  return object.asset.model
end

function Model:draw(object)
  local center, size = self.layout.util.getModelBox(object.asset.model, object.scale)
  lovr.graphics.push()
  lovr.graphics.translate(object.position + center)
  lovr.graphics.rotate(object.rotation)
  lovr.graphics.translate(-object.position - center)
  object.asset.model:draw(object.position, object.scale)
  lovr.graphics.pop()
end

return Model
