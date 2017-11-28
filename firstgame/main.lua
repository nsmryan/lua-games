Timer  = require "hump.timer"
Rot    = require "rotLove.src.rot"
vector = require "hump.vector"
lume   = require "lume.lume"

function love.load()
  height = 640
  width = 820

  maxVel = 40
  maxRot = 0.005
  maxDots = 10000
  startingDots = 10
  maxCollected = 100
  freezeRadius = 100

  timeMult = 1.0

  currentVel = maxVel

  cursorMult = 10

  time = 0

  canvas = love.graphics.newCanvas(width, height)

  white = Rot.Color.fromString("white")
  black = Rot.Color.fromString("black")

  clearColor = black
  polyColor  = white

  love.mouse.setVisible(false)

  cursorTimer = Timer.new()
  cursorEffectTime = 0.15
  cursorSizeIncrements = 5
  cursorSizeMax = 12
  cursorSize = cursorSizeMax
  cursorSizeHandle = nil

  supressCollectionTimer = Timer.new()
  isCollecting = true

  vortex = { active = false, pos = vector(0, 0) }

  freeze = { active = false, pos = vector(0, 0) }
  freezeTimer = Timer.new()

  numCollected = maxCollected

  vortexTimer = Timer.new()

  velocityTimer = Timer.new()

  dotTimer = Timer.new()
  dotTimer:every(1.0, splitDots)

  dots = {}
  numDots = 0
  for ix = 1,startingDots do
    dotX = love.math.random(0, width)
    dotY = love.math.random(0, height)
    dots[{dotX, dotY}] = {["vel"] = randomNormalized()}
    numDots = numDots + 1
  end

end

function randomNormalized()
  randX = love.math.random(-1, 1)
  randY = love.math.random(-1, 1)

  randVect = vector(randX, randX)

  if randVect:len() == 0 then
    randVect.x = 1
  end

  return randVect:normalized()
end

function splitDots()
  local newDots = {}

  for pos,dot in pairs(dots) do
    newDots[pos] = dot
    if numDots < maxDots then
      newDots[{pos[1] + 1, pos[2]}] = { ["vel"] = vector(dot.vel.x, dot.vel.y)}
      numDots = numDots + 1
    end
  end

  dots = newDots
end

function toLine(ps)
  local result = {}

  for ix=1,ps.numItems do
    result[2*ix - 1]   = ps[ix][1]
    result[2*ix] = ps[ix][2]
  end

  return result
end

function cursorSizeFunc(wait)
  for sizeIx = 1,cursorSizeIncrements do
    cursorSize = 1 + cursorSizeMax * ((cursorSizeIncrements - sizeIx) / cursorSizeIncrements)
    wait(cursorEffectTime / cursorSizeIncrements)
  end
end

function stopVortex()
  vortex.active = false
end

function deactivateFreeze()
  freeze.active = false
end

function love.mousepressed(x, y, button, isTouch)
  if button == 1 then
    if cursorSizeHandle ~= nil then
      cursorTimer:cancel(cursorSizeHandle)
    end
    cursorSizeHandle = cursorTimer:script(cursorSizeFunc)

  elseif button == 2 then
    if numCollected >= maxCollected then
      vortex.pos = vector(x, y)
      vortex.active = true
      numCollected = 0
      vortexTimer:clear()
      vortexTimer:after(2, stopVortex)
    end
  end
end

function love.mousereleased(x, y, button, isTouch)
  local newDots = {}
  mX, mY = love.mouse.getPosition()

  if button == 1 then
    cursorSize = cursorSizeMax

    cursorTimer:clear()

    if numCollected >= maxCollected then
      for pos, dot in pairs(dots) do
        distFromCursor = (vector(pos[1], pos[2]) - vector(mX, mY)):len()
        if distFromCursor > cursorSize * cursorMult then
          newDots[pos] = dot
        end
      end

      dots = newDots
      numCollected = 0
    end
  end
end

function love.keypressed(key, scanCode, isRepeat)
  mX, mY = love.mouse.getPosition()

  if key == "space" and not isRepeat then
    splitDots()
  elseif key == "r" and not isRepeat then
    isCollecting = false
    supressCollectionTimer:after(1, function() isCollecting = true end)

    for ix = 1, numCollected do
      randX = mX + love.math.random(-cursorSize, cursorSize)
      randY = mY + love.math.random(-cursorSize, cursorSize)
      dots[{randX, randY}] = { vel = randomNormalized() }
    end
    numDots = numDots + numCollected

    numCollected = 0
  elseif key == "v" and not isRepeat then
    velocityTimer:script(velocityTween)
  end
end

function velocityTween(wait)
  for iter = 1, 30 do
    timeMult = timeMult * 0.9
    wait(0.05)
  end
  wait(0.5)
  timeMult = 1.0
end

function love.update(dt)
  local newDots = {}
  local rot
  local dot
  local newPos
  local numItems = 0

  velocityTimer:update(dt)
  dt = dt * timeMult

  time = time + dt

  mX, mY = love.mouse.getPosition()

  vortex.pos = vector(mX, mY)

  if love.keyboard.isDown("f") then
    freeze.active = true
    freezeTimer:after(5, deactivateFreeze)
    freeze.pos = vector(mX, mY)
  end

  cursorTimer:update(dt)
  dotTimer:update(dt)
  vortexTimer:update(dt)
  freezeTimer:update(dt)
  supressCollectionTimer:update(dt)

  for pos, dot in pairs(dots) do
    rot = love.math.random(-maxRot, maxRot)
    dot.vel:rotateInplace(rot)
  end

  numDots = 0
  for pos, dot in pairs(dots) do
    -- check within cursor
    distFromCursor = (vector(pos[1], pos[2]) - vector(mX, mY)):len()
    if isCollecting and distFromCursor < cursorSize then
      numCollected = numCollected + 1
    else -- not within cursor, or not collecting
      oldPosVect = vector(pos[1], pos[2])

      if freeze.active and (oldPosVect - freeze.pos):len() < freezeRadius then
        newPos = pos
      else
        newPos = {pos[1] + dot.vel.x*dt * currentVel, pos[2] + dot.vel.y*dt * currentVel}
      end

      posVect = vector(newPos[1], newPos[2])

      -- check if vortex is active
      if vortex.active then
        distToVortex = (vortex.pos - posVect):len()
        vortexStrength = 15000.0 / (distToVortex ^ 2)

        -- only apply if vortex has certain strength
        if vortexStrength > 0.01 then
          newPos = { lume.lerp(newPos[1], vortex.pos.x, dt*vortexStrength) , lume.lerp(newPos[2], vortex.pos.y, dt*vortexStrength) }

          -- if close to vortex, set movement direction
          if distToVortex < 20 and distToVortex > 0 and dot.vel:len() > 0 then
            newAngle = posVect.angleTo(vortex.pos)
            dot.vel = vector.fromPolar(newAngle, dot.vel:len())
          end
        end
      end

      -- update dot only if within screen boundary
      if newPos[1] > 0 and newPos[2] > 0 and newPos[1] < width and newPos[2] < height then
        newDots[newPos] = dot
        numDots = numDots + 1
      end
    end
  end
  dots = newDots

end

function love.draw()
  mX, mY = love.mouse.getPosition()

  love.graphics.setCanvas(canvas)
  love.graphics.clear(clearColor)

  -- draw dots
  love.graphics.setColor(white)
  for pos, dot in pairs(dots) do
    love.graphics.points(pos[1], pos[2])
  end

  love.graphics.setCanvas()

  love.graphics.clear(clearColor)
  love.graphics.draw(canvas)
  love.graphics.setColor(white)
  love.graphics.circle("fill", mX, mY, cursorSize, 100)
  love.graphics.setColor(black)
  love.graphics.circle("fill", mX, mY, math.max(0, (cursorSize-1) - cursorSize * (numCollected/maxCollected)), 100)

  if numCollected >= maxCollected then
    for ix = 1, 1 + 7 * math.abs(math.sin(3*time)) do
      love.graphics.setColor(255, 255, 255, 255/ix)
      love.graphics.circle("fill", mX, mY, cursorSize + ix, 100)
    end
  end
end
