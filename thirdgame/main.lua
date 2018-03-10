require "lib/cpml"


local width, height = love.graphics.getDimensions()

local radius = 5
local count = 10
local numChains = 7


function mkChain()
  local bodies   = {}
  local shapes   = {}
  local fixtures = {}
  local joints   = {}

  local xs = {}
  local ys = {}

  for i = 1, count do
    xs[i] = width/2 + count * (i-1) * 2

    ys[i] = height/2 + count * (i-1) * 2

    bodies[i]  = love.physics.newBody(world, xs[i], ys[i], "dynamic")

    shapes[i]  = love.physics.newCircleShape(1)

    fixtures[i] = love.physics.newFixture(bodies[i], shapes[i])

    if i ~= 1 then
      joints[i] = love.physics.newRopeJoint(bodies[i], bodies[i-1], xs[i], ys[i], xs[i-1], ys[i-1], 20, false)
    end
  end

  return bodies
end

function love.update(dt)
  mouseBody:setPosition(love.mouse.getX(), love.mouse.getY())

  for chainIndex = 1, numChains do
    --mouseJoints[chainIndex]:setTarget(love.mouse.getPosition())

    local positions = {}
    for i = 1, count do
      positions[(i - 1) * 2 + 1] = chains[chainIndex][i]:getX()
      positions[(i - 1) * 2 + 2] = chains[chainIndex][i]:getY()
    end

    curves[chainIndex] = love.math.newBezierCurve(unpack(positions))

    for i = 1, count do
      local body = chains[chainIndex][i]
      body:applyLinearImpulse(math.sin(chainIndex + (body:getX() / 100)) / 500,
                              math.cos(chainIndex + (body:getY() / 100)) / 500)
      body:applyLinearImpulse(math.random(-1, 1) / 100,
                              math.random(-1, 1) / 100)
    end
  end

  world:update(dt)
end

function love.draw()
  love.graphics.circle('fill', love.mouse.getX(), love.mouse.getY(), radius * 2)

  for chainIndex = 1, numChains do
    local points = curves[chainIndex]:render()
    numPoints = #points / 2

    --love.graphics.line(points)

    for i = 1, (numPoints - 1) do
      local x = points[(i - 1) * 2 + 1]
      local y = points[(i - 1) * 2 + 2]

      local xOther = points[i * 2 + 1]
      local yOther = points[i * 2 + 2]

      love.graphics.setLineWidth(defaultLineWidth + ((numPoints - i) / 20))
      love.graphics.line(x, y, xOther, yOther)
    end
  end
end

function love.load()
  chains      = {}
  mouseJoints = {}
  curves      = {}

  world = love.physics.newWorld(0, 0)

  mouseBody = love.physics.newBody(world, width/2, height/2, "dynamic")

  for chainIndex = 1, numChains do
    chains[chainIndex] = mkChain()
    mouseJoints[chainIndex] =
      love.physics.newDistanceJoint(mouseBody,
                                    chains[chainIndex][1],
                                    width  / 2,
                                    height / 2,
                                    width  / 2,
                                    height / 2,
                                    false)
    --mouseJoints[i] = love.physics.newMouseJoint(chains[i][1], width/2, height/2)
    for i = 1, count do
      body = chains[chainIndex][i]
      body:applyLinearImpulse(math.sin(chainIndex + (body:getX() / 10)),
                              math.cos(chainIndex + (body:getY() / 10)))
    end
  end

  defaultLineWidth = love.graphics.getLineWidth()

  love.mouse.setVisible(false)
end

