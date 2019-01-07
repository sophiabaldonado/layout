local Marker = {}

function Marker:init()

end

function Marker:update(dt)

end

function Marker:draw()
  lovr.graphics.sphere(self.x, self.y, self.z, self.scale, self.angle, self.ax, self.ay, self.az)
end

return Marker
