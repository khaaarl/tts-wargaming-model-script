local matSurfaceGUIDs = { '4ee1f2', '2f74dd', '430b18' }
local matSurfaceBlockerGUIDs = { '9cf194', 'deaf49' }
local counterState = {}
local measuringCircles = {}
local currentHighlightColor = nil
local previousHighlightColor = nil
local chosenBase = nil
local ymMeasuringCircles = nil
local isRectangularMeasuring = false
local MM_TO_INCH = 0.0393701
local MEASURING_RING_Y_OFFSET = 0.17
local VALID_BASE_SIZES_IN_MM = {
  { x = 25, z = 25 }, { x = 28, z = 28 }, { x = 30, z = 30 }, { x = 32, z = 32 },
  { x = 40, z = 40 }, { x = 50, z = 50 }, { x = 55, z = 55 }, { x = 60, z = 60 },
  { x = 65,  z = 65 }, { x = 80, z = 80 }, { x = 90, z = 90 }, { x = 100, z = 100 },
  { x = 130, z = 130 }, { x = 160, z = 160 }, { x = 25, z = 75 }, { x = 75, z = 25 },
  { x = 35.5, z = 60 }, { x = 60, z = 35.5 }, { x = 42, z = 64 }, { x = 64, z = 42 },
  { x = 42,   z = 75 }, { x = 75, z = 42 }, { x = 40, z = 95 }, { x = 95, z = 40 },
  { x = 52, z = 90 }, { x = 90, z = 52 }, { x = 70, z = 105 }, { x = 105, z = 70 },
  { x = 92, z = 120 }, { x = 120, z = 92 }, { x = 95, z = 150 }, { x = 150, z = 95 },
  { x = 109, z = 170 }, { x = 170, z = 109 }, { x = 46, z = 193 }, { x = 193, z = 46 }
}

--[[ UTILITIES ]] --

-- Return the first index with the given value (or nil if not found).
function IndexOf(array, value)
  for i, v in ipairs(array) do if v == value then return i end end
  return nil
end

function DeepCopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
    end
    setmetatable(copy, DeepCopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function None() end

function SplitLines(s)
  s = string.gsub(s, "\r\n", "\n")
  local lines = {}
  local delimiter = "\n"
  local from = 1
  local delim_from, delim_to = string.find(s, delimiter, from)
  while delim_from do
    table.insert(lines, string.sub(s, from, delim_from - 1))
    from = delim_to + 1
    delim_from, delim_to = string.find(s, delimiter, from)
  end
  table.insert(lines, string.sub(s, from))
  return lines
end

--[[ EVENT HANDLERS ]] --

---@diagnostic disable-next-line: lowercase-global
function onScriptingButtonDown(index, playerColor)
  local player = Player[playerColor]
  local hoveredObject = player.getHoverObject()

  if hoveredObject ~= self then return end

  if index == 2 then
    ChangeModelWoundCount(-1, hoveredObject)
  elseif index == 3 then
    ChangeModelWoundCount(1, hoveredObject)
  elseif index == 4 then
    ChangeMeasurementCircle(1, hoveredObject)
  elseif index == 5 then
    ChangeMeasurementCircle(-1, hoveredObject)
  elseif index == 6 then
    AssignBase(-1, hoveredObject)
  elseif index == 7 then
    AssignBase(1, hoveredObject)
  elseif index == 8 then
    ToggleRectangularMeasuring(-1, hoveredObject)
  elseif index == 9 then
    ChangeColor(-1, hoveredObject)
  end
end

---@diagnostic disable-next-line: lowercase-global
function onSave()
  local state = {
    currentHighlightColor = currentHighlightColor,
    chosenBase = chosenBase,
    ymMeasuringCircles = ymMeasuringCircles,
    isRectangularMeasuring = isRectangularMeasuring,
    counterState = counterState
  }
  return JSON.encode(state)
end

---@diagnostic disable-next-line: lowercase-global
function onLoad(stateJSON)
  if stateJSON and stateJSON ~= "" then
    local state = JSON.decode(stateJSON)
    currentHighlightColor = state.currentHighlightColor
    chosenBase = state.chosenBase
    ymMeasuringCircles = state.ymMeasuringCircles
    counterState = state.counterState or {}
    isRectangularMeasuring = state.isRectangularMeasuring
  end
  Wait.frames(function()
    Stabilize()
    UpdateButtons()
    EnqueueRecount()
  end, 1)
end

---@diagnostic disable-next-line: lowercase-global
function onPickUp(player_color)
  Destabilize()
  EnqueueRecount()
end

---@diagnostic disable-next-line: lowercase-global
function onDrop(player_color)
  Stabilize()
  UpdateButtons()
  EnqueueRecount()
end

---@diagnostic disable-next-line: lowercase-global
function onRotate(spin, flip, player_color, old_spin, old_flip)
  UpdateButtons()
  EnqueueRecount()
end

--[[ Button Counter Stuff ]] --

function DesiredButtonOffset()
  local desc = self.getDescription() .. "\n" .. self.getGMNotes()
  local _, _, yposStr = desc:find("BUTTON_OFFSET *= *([0-9]+[.]?[0-9]*)")
  return tonumber(yposStr or "2.0")
end

function UpdateButtons()
  local desc = self.getDescription() .. "\n" .. self.getGMNotes()
  local newCounterState = {}
  for s in desc:gmatch("COUNTER: *[^\n]+") do
    local name = string.match(s, "COUNTER: *([^,\n]+)")
    local color =
        string.match(s, "COUNTER: *[^,\n]+, *(%x%x%x%x%x%x%x?%x?)") or
        "ffffff"
    local min = string.match(s, "COUNTER: *[^,\n]+, *%x+, *(-?%d+)") or 0
    local max =
        string.match(s, "COUNTER: *[^,\n]+, *%x+, *-?%d+, *(-?%d+)") or 1000
    local current = min
    for _, c in ipairs(counterState) do
      if c.name == name then current = c.current end
    end
    table.insert(newCounterState, 1, {
      name = name,
      color = color,
      min = min,
      max = max,
      current = current
    })
  end
  counterState = newCounterState

  InitializeButtons()
end

function AddSubCounter(ix, alt_click)
  local c = counterState[ix]
  if not c then return end
  local mod = alt_click and -1 or 1
  c.current = math.min(math.max(c.current + mod, c.min), c.max)
  UpdateButtons()
end

function AddSubCounter1(_obj, _color, alt_click) AddSubCounter(1, alt_click) end

function AddSubCounter2(_obj, _color, alt_click) AddSubCounter(2, alt_click) end

function AddSubCounter3(_obj, _color, alt_click) AddSubCounter(3, alt_click) end

function AddSubCounter4(_obj, _color, alt_click) AddSubCounter(4, alt_click) end

function AddSubCounter5(_obj, _color, alt_click) AddSubCounter(5, alt_click) end

function InitializeButtons()
  -- Backwards iteration over possibly-nil getButtons to avoid bizarre lockup.
  local numButtons = #(self.getButtons() or {})
  while numButtons > 0 do
    self.removeButton(numButtons - 1)
    numButtons = numButtons - 1
  end
  local params = {
    function_owner = self,
    height = 500,
    width = 500,
    font_size = 250,
    scale = { x = 1, y = 1, z = 1 },
    color = { 0, 0, 0, 0 }
  }
  local ypos = DesiredButtonOffset()
  for ix, c in ipairs(counterState) do
    if ix > 5 then break end -- Can't count that high :(
    params.label = c.name
    params.click_function = "AddSubCounter" .. tostring(ix)
    local font_color = {
      tonumber(c.color:sub(1, 2), 16) / 255,
      tonumber(c.color:sub(3, 4), 16) / 255,
      tonumber(c.color:sub(5, 6), 16) / 255, 255
    }
    params.position = { 0, ypos, 0 }
    params.font_color = font_color
    params.rotation = { 270, 270, 90 }
    self.createButton(params)
    params.position = { 0, ypos, 0 }
    params.font_color = { 0, 0, 0, 0 }
    params.rotation = { 90, 270, 90 }
    self.createButton(params)
    ypos = ypos + 0.5
    params.label = tostring(c.current)
    params.position = { 0, ypos, 0 }
    params.font_color = font_color
    params.rotation = { 270, 270, 90 }
    self.createButton(params)
    params.position = { 0, ypos, 0 }
    params.font_color = { 0, 0, 0, 0 }
    params.rotation = { 90, 270, 90 }
    self.createButton(params)
    ypos = ypos + 0.5
  end
end

--[[ MEASURING CIRCLE FUNCTIONS ]] --

function ToggleRectangularMeasuring(playerColor, target)
  isRectangularMeasuring = not isRectangularMeasuring
  ChangeMeasurementCircle(0, target)
end

function AssignBase(inc, target)
  local savedBase = DeepCopy(chosenBase)

  if savedBase == nil then
    ChangeMeasurementCircle(0, target, DetermineBaseInInches(target))
  else
    local newIdx = savedBase.baseIdx + inc

    if newIdx < 1 then newIdx = #VALID_BASE_SIZES_IN_MM end
    if newIdx > #VALID_BASE_SIZES_IN_MM then newIdx = 1 end

    local newBase = {
      baseIdx = newIdx,
      base = {
        x = (VALID_BASE_SIZES_IN_MM[newIdx].x * MM_TO_INCH) / 2,
        z = (VALID_BASE_SIZES_IN_MM[newIdx].z * MM_TO_INCH) / 2
      }
    }

    chosenBase = newBase

    ChangeMeasurementCircle(0, target, newBase.base)
  end
end

function DetermineBaseInInches(model)
  local savedBase = DeepCopy(chosenBase)

  if savedBase ~= nil then
    return savedBase.base
  else
    local newBase = VALID_BASE_SIZES_IN_MM[1]
    local modelSize = model.getBoundsNormalized().size
    local modelSizeX = modelSize.x
    local modelSizeZ = modelSize.z
    local closestSum = 10000000000
    local chosenBaseIdx = 1

    for k, base in pairs(VALID_BASE_SIZES_IN_MM) do
      local baseInchX = (MM_TO_INCH - 0.001) * base.x
      local baseInchZ = (MM_TO_INCH - 0.001) * base.z
      if modelSizeX > baseInchX and modelSizeZ > baseInchZ then
        local distSum = (modelSizeX - baseInchX) +
            (modelSizeZ - baseInchZ)
        if distSum < closestSum then
          closestSum = distSum
          newBase = base
          chosenBaseIdx = k
        end
      end
    end

    if newBase == nil then
      newBase = { x = modelSizeX / 2, z = modelSizeZ / 2 }
    else
      newBase = {
        x = (newBase.x * MM_TO_INCH) / 2,
        z = (newBase.z * MM_TO_INCH) / 2
      }
    end

    chosenBase = { baseIdx = chosenBaseIdx, base = newBase }

    return newBase
  end
end

function ChangeMeasurementCircle(change, target, presetBase)
  local measuringRings = DeepCopy(ymMeasuringCircles)
  local currentColor = currentHighlightColor
  local currentColorRadius

  if measuringRings == nil then
    measuringRings = {}
    currentColorRadius = 0
  else
    for idx = #measuringRings, 1, -1 do
      if (measuringRings[idx].name == currentColor) or
          (measuringRings[idx].name == nil and currentColor == nil) then
        currentColorRadius = measuringRings[idx].radius
        table.remove(measuringRings, idx)
      elseif measuringRings[idx].name == "base" then
        table.remove(measuringRings, idx)
      end
    end

    if currentColorRadius == nil then currentColorRadius = 0 end
  end

  local newRadius = math.max(currentColorRadius + change, 0)

  if newRadius ~= 0 then
    local measuring = {
      name = currentColor,
      color = currentColor == nil and { 1, 0, 1 } or
          Color.fromString(currentColor),
      radius = newRadius,
      thickness = 0.1 * 1 / (target.getScale().x),
      rotation = { 270, 0, 0 } -- isRectangular and {0,0,0} or {270,0,0}
    }
    local base = {
      name = "base",
      color = currentColor == nil and { 1, 0, 1 } or
          Color.fromString(currentColor),
      thickness = 0.1 * 1 / (target.getScale().x),
      rotation = { 270, 0, 0 } -- isRectangular and {0,0,0} or {270,0,0}
    }
    local measuringPoints, basePoints

    if isRectangularMeasuring then
      local modelBounds = target.getBoundsNormalized()

      if newRadius > 0 then
        measuringPoints = GetRectangleVectorPoints(newRadius,
          modelBounds.size.x /
          2,
          modelBounds.size.z /
          2, target)
        basePoints = GetRectangleVectorPoints(0, modelBounds.size.x / 2,
          modelBounds.size.z / 2,
          target)
      end
    else
      local baseRadiuses = (presetBase == nil) and
          DetermineBaseInInches(target) or presetBase

      if newRadius > 0 then
        measuringPoints = GetCircleVectorPoints(newRadius,
          baseRadiuses.x,
          baseRadiuses.z, target)
        basePoints = GetCircleVectorPoints(0, baseRadiuses.x,
          baseRadiuses.z, target)
      end
    end

    measuring.points = measuringPoints
    base.points = basePoints

    table.insert(measuringRings, measuring)
    table.insert(measuringRings, base)

    if change ~= 0 then
      broadcastToAll("Measuring " .. tostring(newRadius) .. "\"")
    end
  end

  target.setVectorLines(measuringRings)

  ymMeasuringCircles = measuringRings
end

function GetCircleVectorPoints(radius, baseX, baseZ, obj)
  local result = {}
  local scaleFactor = 1 / obj.getScale().x
  local rotationDegrees = obj.getRotation().y
  local steps = 64
  local degrees, sin, cos, toRads = 360 / steps, math.sin, math.cos, math.rad

  for i = 0, steps do
    table.insert(result, {
      x = cos(toRads(degrees * i)) * ((radius + baseX) * scaleFactor),
      z = MEASURING_RING_Y_OFFSET,
      y = sin(toRads(degrees * i)) * ((radius + baseZ) * scaleFactor)
    })
  end

  return result
end

function GetRectangleVectorPoints(radius, sizeX, sizeZ, obj)
  local result = {}
  local scaleFactor = 1 / obj.getScale().x

  sizeX = sizeX * scaleFactor
  sizeZ = sizeZ * scaleFactor
  radius = radius * scaleFactor

  local steps = 65
  local degrees, sin, cos, toRads = 360 / (steps - 1), math.sin, math.cos,
      math.rad
  local xOffset, zOffset = sizeX, sizeZ
  -- compensate for ignoring vertical line
  table.insert(result, {
    x = (cos(toRads(degrees * 0)) * radius) + sizeX - 0.001,
    y = (sin(toRads(degrees * 0)) * radius) + sizeZ,
    z = MEASURING_RING_Y_OFFSET
  })

  for i = 1, steps - 1 do
    if i == 16 then
      table.insert(result, {
        x = sizeX,
        y = (radius + sizeZ),
        z = MEASURING_RING_Y_OFFSET
      })
      table.insert(result, {
        x = -sizeX,
        y = (radius + sizeZ),
        z = MEASURING_RING_Y_OFFSET
      })
      xOffset = -sizeX
    elseif i == 33 then
      table.insert(result, {
        x = -radius - sizeX,
        y = sizeZ,
        z = MEASURING_RING_Y_OFFSET
      })
      table.insert(result, {
        x = -radius - sizeX - 0.001,
        y = -sizeZ,
        z = MEASURING_RING_Y_OFFSET
      })
      table.insert(result, {
        x = -radius - sizeX,
        y = -sizeZ,
        z = MEASURING_RING_Y_OFFSET
      })
      zOffset = -sizeZ
    elseif i == 49 then
      table.insert(result, {
        x = -sizeX,
        y = -radius - sizeZ,
        z = MEASURING_RING_Y_OFFSET
      })
      table.insert(result, {
        x = sizeX,
        y = -radius - sizeZ,
        z = MEASURING_RING_Y_OFFSET
      })
      xOffset = sizeX
    elseif i == 65 then
      table.insert(result, {
        x = radius + sizeX,
        y = -sizeZ,
        z = MEASURING_RING_Y_OFFSET
      })
      table.insert(result, {
        x = radius + sizeX - 0.001,
        y = sizeZ,
        z = MEASURING_RING_Y_OFFSET
      })
    else
      table.insert(result, {
        x = (cos(toRads(degrees * i)) * radius) + xOffset,
        y = (sin(toRads(degrees * i)) * radius) + zOffset,
        z = MEASURING_RING_Y_OFFSET
      })
    end
  end
  -- compensate for ignoring vertical line
  table.insert(result, {
    x = (cos(toRads(degrees * 0)) * radius) + sizeX - 0.001,
    y = (sin(toRads(degrees * 0)) * radius) + sizeZ,
    z = MEASURING_RING_Y_OFFSET
  })

  return result
end

function ChangeWoundCountString(mod, s)
  local _, _, current, total = s:find("([0-9]+)/([0-9]+)")
  if current == nil then return nil end
  current = math.max(tonumber(current) + mod, 0)
  total = tonumber(total)
  return string.gsub(s, "([0-9]+)/([0-9]+)", current .. "/" .. total, 1)
end

function ChangeModelWoundCount(mod, target)
  if IsAoS(target) then
    -- If we are in age of sigmar, update all the matching names
    for _, obj in ipairs(GetUnitObjects(target)) do
      local newName = ChangeWoundCountString(mod, obj.getName())
      if newName then
        obj.setName(newName)
      end
    end
  else
    local newName = ChangeWoundCountString(mod, target.getName())
    if newName then
      target.setName(newName)
    end
  end
end

function IsAoS(target)
  target = target or self
  if string.find(target.getDescription() or "",
        "Mo?v?e? +He?a?l?t?h? +[CB][oa]?n?[ti]?[rs]?[oh]?l? +Sa?v?e?") then
    return true
  end
  return false
end

function GetUnitIdAndFancyName(target)
  target = target or self
  local unitId = string.match(target.getGMNotes() or "", 'UNIT_ID="[^"]+"')
  local name = target.getName() or ""
  local fancyName = string.match(
    name, "^[^\n]*[0-9]+/[0-9]+([^\n]* +[[][^\n]+)")
  if not fancyName then
    fancyName = string.match(name, "^([^\n]*[[][^\n]+)")
  end
  return unitId, fancyName
end

function GetUnitObjects(target)
  target = target or self
  local unitId, fancyName = GetUnitIdAndFancyName(target)
  if not fancyName and not unitId then return { target } end
  local objects = {}
  for _, obj in pairs(getObjects()) do
    local otherUnitId, otherFancyName = GetUnitIdAndFancyName(obj)
    if unitId == otherUnitId and fancyName == otherFancyName then
      table.insert(objects, obj)
    end
  end
  return objects
end

-- Changes color of aura. Does not support multiple auras at the moment.
function ChangeColor(playerColor, target)
  local currentColor = currentHighlightColor
  local colorWheel = {
    "pink", "purple", "blue", "teal", "green", "yellow", "orange", "red",
    "brown", "white"
  }
  local nextColor = "white"
  if currentColor ~= nil then
    nextColor =
        colorWheel[(IndexOf(colorWheel, currentColor) % #colorWheel) + 1]
  end

  local measuringRings = DeepCopy(ymMeasuringCircles)
  if measuringRings ~= nil then
    for idx = #measuringRings, 1, -1 do
      if (measuringRings[idx].name == currentColor) or
          (measuringRings[idx].name == nil and currentColor == nil) then
        measuringRings[idx].name = nextColor
      end
    end
    ymMeasuringCircles = measuringRings
  end
  currentHighlightColor = nextColor
  ChangeMeasurementCircle(0, target)
end

--[[ STABILIZATION ]] --

function Stabilize()
  local desc = self.getDescription() .. "\n" .. self.getGMNotes()
  if not string.find(desc, "STABILIZEME") then return end
  self.getComponent("Rigidbody").set("freezeRotation", true)
end

function Destabilize()
  self.getComponent("Rigidbody").set("freezeRotation", false)
end

--[[ COUNTING MODELS ]] --

function EnqueueRecount()
  Wait.frames(function()
    local myObjName = self.getName()
    if not string.find(myObjName, "\n") then return end
    local unitId, fancyName = GetUnitIdAndFancyName()
    if not fancyName and not unitId then return end
    local recountId = unitId or fancyName
    local recounts = Global.getTable("__WargamingModelNeedsRecount__") or {}
    recounts[recountId] = os.clock() + .5
    Global.setTable("__WargamingModelNeedsRecount__", recounts)
    local runRecount = nil
    runRecount = function()
      assert(runRecount)
      local recounts = Global.getTable("__WargamingModelNeedsRecount__") or {}
      if not recounts[recountId] then return end
      -- If another change has occurred relatively recently, we should wait a
      -- bit before updating.
      local now = os.clock()
      if (tonumber(recounts[recountId]) or 0) > tonumber(now) then
        Wait.frames(runRecount, 10)
        return
      end
      recounts[recountId] = false
      Global.setTable("__WargamingModelNeedsRecount__", recounts)
      local madeChanges = DoRecountNow(self)
      if madeChanges then
        EnqueueRecount()
      end
    end
    Wait.frames(runRecount, 30)
  end, 1)
end

function DoRecountNow(target)
  local madeChanges = false
  local matchingObjects = GetUnitObjects(target)
  local matBounds = {} -- list of {x0, z0, x1, z1}
  for _, guid in ipairs(matSurfaceGUIDs) do
    local matObj = getObjectFromGUID(guid)
    if matObj then
      local bounds = matObj.getBounds()
      local mB = {
        bounds.center.x - bounds.size.x / 2,
        bounds.center.x + bounds.size.x / 2,
        bounds.center.z - bounds.size.z / 2,
        bounds.center.z + bounds.size.z / 2
      }
      if bounds.size.x > 9 and bounds.size.z > 9 then
        table.insert(matBounds, mB)
      end
    end
  end
  local excludeMatBounds = {} -- list of {x0, z0, x1, z1}
  for _, guid in ipairs(matSurfaceBlockerGUIDs) do
    local matObj = getObjectFromGUID(guid)
    if matObj then
      local bounds = matObj.getBounds()
      local mB = {
        bounds.center.x - bounds.size.x / 2,
        bounds.center.x + bounds.size.x / 2,
        bounds.center.z - bounds.size.z / 2,
        bounds.center.z + bounds.size.z / 2
      }
      if bounds.size.x > 9 and bounds.size.z > 9 then
        table.insert(excludeMatBounds, mB)
      end
    end
  end
  local numAliveModels = 0
  for _, obj in ipairs(matchingObjects) do
    local isAlive = true
    local rot = obj.getRotation()
    if math.abs(180 - rot.x) < 90 or math.abs(180 - rot.z) < 90 then
      isAlive = false
    end
    local bounds = obj.getBounds()
    if isAlive and #excludeMatBounds > 0 then
      for _, mB in ipairs(excludeMatBounds) do
        if ((bounds.center.x > mB[1] and bounds.center.x < mB[2]) and
              (bounds.center.z > mB[3] and bounds.center.z < mB[4])) then
          isAlive = false
        end
      end
    end
    if isAlive and #matBounds > 0 then
      local inMat = false
      for _, mB in ipairs(matBounds) do
        if ((bounds.center.x > mB[1] and bounds.center.x < mB[2]) and
              (bounds.center.z > mB[3] and bounds.center.z < mB[4])) then
          inMat = true
        end
      end
      if not inMat then isAlive = false end
    end
    if isAlive then
      numAliveModels = numAliveModels + 1
    end
  end
  for _, obj in ipairs(matchingObjects) do
    local lines = SplitLines(obj.getName())
    lines[2] = lines[2] or ""
    local hadCount = string.find(lines[2], "^[0-9]+x ")
    lines[2] = string.gsub(lines[2], "^[0-9]+x ", "")
    if #matchingObjects > 1 then
      lines[2] = tostring(numAliveModels) .. "x " .. lines[2]
    end
    if #matchingObjects > 1 or hadCount then
      local newName = table.concat(lines, "\n")
      if newName ~= obj.getName() then
        obj.setName(newName)
        madeChanges = true
      end
    end
  end
  return madeChanges
end
