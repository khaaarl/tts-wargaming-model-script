local scriptingFunctions
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
    {x = 25, z = 25},
    {x = 28, z = 28},
    {x = 30, z = 30},
    {x = 32, z = 32},
    {x = 40, z = 40},
    {x = 50, z = 50},
    {x = 55, z = 55},
    {x = 60, z = 60},
    {x = 65, z = 65},
    {x = 80, z = 80},
    {x = 90, z = 90},
    {x = 100, z = 100},
    {x = 130, z = 130},
    {x = 160, z = 160},
    {x = 25, z = 75},
    {x = 75, z = 25},
    {x = 35.5, z = 60},
    {x = 60, z = 35.5},
    {x = 42, z = 64},
    {x = 64, z = 42},
    {x = 42, z = 75},
    {x = 75, z = 42},
    {x = 40, z = 95},
    {x = 95, z = 40},
    {x = 52, z = 90},
    {x = 90, z = 52},
    {x = 70, z = 105},
    {x = 105, z = 70},
    {x = 92, z = 120},
    {x = 120, z = 92},
    {x = 95, z = 150},
    {x = 150, z = 95},
    {x = 109, z = 170},
    {x = 170, z = 109},
    {x = 46, z = 193},
    {x = 193, z = 46}
}


--[[ UTILITIES ]]--

-- Return the first index with the given value (or nil if not found).
function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function none() end


--[[ EVENT HANDLERS ]]--

function onScriptingButtonDown(index, playerColor)
    local player = Player[playerColor]
    local hoveredObject = player.getHoverObject()

    if hoveredObject ~= self then return end
    
    scriptingFunctions[index](playerColor, hoveredObject, player)
end

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
        stabilize()
        updateButtons()
    end, 1)
end

function onPickUp(player_color)
  destabilize()
end

function onDrop(player_color)
  stabilize()
  updateButtons()
end

--[[ Button Counter Stuff ]]--

function desiredButtonOffset()
    local _,_, yposStr = self.getDescription():find("BUTTON_OFFSET *= *([0-9]+[.]?[0-9]*)")
    return tonumber(yposStr or "2.0")
end

function updateButtons()
    local desc = self.getDescription()
    local newCounterState = {}
    for s in desc:gmatch("COUNTER: *[^\n]+") do
        local name = string.match(s, "COUNTER: *([^,\n]+)")
        local color = string.match(s, "COUNTER: *[^,\n]+, *(%x%x%x%x%x%x%x?%x?)") or "ffffff"
        local min = string.match(s, "COUNTER: *[^,\n]+, *%x+, *(-?%d+)") or 0
        local max = string.match(s, "COUNTER: *[^,\n]+, *%x+, *-?%d+, *(-?%d+)") or 1000
        local current = min
        for _, c in ipairs(counterState) do
            if c.name == name then
                current = c.current
            end
        end
        table.insert(newCounterState, 1, {name=name, color=color, min=min, max=max, current=current})
    end
    counterState = newCounterState

    initializeButtons()
end

function addSubCounter(ix, alt_click)
    local c = counterState[ix]
    if not c then return end
    local mod = alt_click and -1 or 1
    c.current = math.min(math.max(c.current + mod, c.min), c.max)
    updateButtons()
end
function addSubCounter1(_obj, _color, alt_click)
    addSubCounter(1, alt_click)
end
function addSubCounter2(_obj, _color, alt_click)
    addSubCounter(2, alt_click)
end
function addSubCounter3(_obj, _color, alt_click)
    addSubCounter(3, alt_click)
end
function addSubCounter4(_obj, _color, alt_click)
    addSubCounter(4, alt_click)
end
function addSubCounter5(_obj, _color, alt_click)
    addSubCounter(5, alt_click)
end


function initializeButtons()
    -- Backwards iteration over possibly-nil getButtons to avoid bizarre lockup.
    local numButtons = #(self.getButtons() or {})
    while numButtons > 0 do
        self.removeButton(numButtons - 1)
        numButtons = numButtons - 1
    end
    local params = {
        function_owner=self,
        height=500,
        width=500,
        font_size=250,
        scale={x=1, y=1, z=1},
        color = {0,0,0,0}
    }
    local ypos = desiredButtonOffset()
    for ix, c in ipairs(counterState) do
        if ix > 5 then break end -- Can't count that high :(
        params.label = c.name
        params.click_function = "addSubCounter" .. tostring(ix)
        local font_color = {
            tonumber(c.color:sub(1,2),16)/255,
            tonumber(c.color:sub(3,4),16)/255,
            tonumber(c.color:sub(5,6),16)/255,
            255
        }
        params.position = {0, ypos, 0}
        params.font_color = font_color
        params.rotation={270,270,90}
        self.createButton(params)
        params.position = {0, ypos, 0}
        params.font_color = {0,0,0,0}
        params.rotation={90,270,90}
        self.createButton(params)
        ypos = ypos + 0.5
        params.label = tostring(c.current)
        params.position = {0, ypos, 0}
        params.font_color = font_color
        params.rotation={270,270,90}
        self.createButton(params)
        params.position = {0, ypos, 0}
        params.font_color = {0,0,0,0}
        params.rotation={90,270,90}
        self.createButton(params)
        ypos = ypos + 0.5
    end
end

--[[ MEASURING CIRCLE FUNCTIONS ]]--

function toggleRectangularMeasuring(playerColor, target)
    isRectangularMeasuring = not isRectangularMeasuring
    changeMeasurementCircle(0, target)
end

function assignBase(inc, target)
    local savedBase = deepcopy(chosenBase)

    if savedBase == nil then
        changeMeasurementCircle(0, target, determineBaseInInches(target))
    else
        local newIdx = savedBase.baseIdx + inc

        if newIdx < 1 then newIdx = #VALID_BASE_SIZES_IN_MM end
        if newIdx > #VALID_BASE_SIZES_IN_MM then newIdx = 1 end

        local newBase = {
            baseIdx = newIdx,
            base = {
                x = (VALID_BASE_SIZES_IN_MM[newIdx].x * MM_TO_INCH)/2,
                z = (VALID_BASE_SIZES_IN_MM[newIdx].z * MM_TO_INCH)/2
            }
        }

        chosenBase = newBase

        changeMeasurementCircle(0, target, newBase.base)
    end
end


function determineBaseInInches(model)
    local savedBase = deepcopy(chosenBase)

    if savedBase ~= nil then
        return savedBase.base
    else
        local newBase =  VALID_BASE_SIZES_IN_MM[1]
        local modelSize = model.getBoundsNormalized().size
        local modelSizeX = modelSize.x
        local modelSizeZ = modelSize.z
        local closestSum = 10000000000
        local chosenBaseIdx = 1

        for k, base in pairs(VALID_BASE_SIZES_IN_MM) do
            local baseInchX = (MM_TO_INCH - 0.001) * base.x
            local baseInchZ = (MM_TO_INCH - 0.001) * base.z
            if modelSizeX > baseInchX and modelSizeZ > baseInchZ then
                local distSum = (modelSizeX - baseInchX) + (modelSizeZ - baseInchZ)
                if distSum < closestSum then
                    closestSum = distSum
                    newBase = base
                    chosenBaseIdx = k
                end
            end
        end

        if newBase == nil then
            newBase = { x=modelSizeX/2, z=modelSizeZ/2}
        else
            newBase = {
                x = (newBase.x * MM_TO_INCH)/2,
                z = (newBase.z * MM_TO_INCH)/2
            }
        end

        chosenBase = { baseIdx=chosenBaseIdx, base=newBase }

        return newBase
    end
end


function changeMeasurementCircle(change, target, presetBase)
    local measuringRings = deepcopy(ymMeasuringCircles)
    local currentColor = currentHighlightColor
    local currentColorRadius

    if measuringRings == nil then
        measuringRings = {}
        currentColorRadius = 0
    else
        for idx=#measuringRings,1,-1 do
            if (measuringRings[idx].name == currentColor) or (measuringRings[idx].name == nil and currentColor == nil) then
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
            color = currentColor == nil and {1,0,1} or Color.fromString(currentColor),
            radius = newRadius,
            thickness = 0.1 * 1/(target.getScale().x),
            rotation  = {270,0,0}--isRectangular and {0,0,0} or {270,0,0}
        }
        local base = {
            name="base",
            color = currentColor == nil and {1,0,1} or Color.fromString(currentColor),
            thickness = 0.1 * 1/(target.getScale().x),
            rotation  = {270,0,0}--isRectangular and {0,0,0} or {270,0,0}
        }
        local measuringPoints,basePoints

        if isRectangularMeasuring then
            local modelBounds = target.getBoundsNormalized()

            if newRadius > 0 then
                measuringPoints = getRectangleVectorPoints(newRadius, modelBounds.size.x/2, modelBounds.size.z/2, target)
                basePoints = getRectangleVectorPoints(0, modelBounds.size.x/2, modelBounds.size.z/2, target)
            end
        else
            local baseRadiuses = (presetBase == nil) and determineBaseInInches(target) or presetBase

            if newRadius > 0 then
                measuringPoints = getCircleVectorPoints(newRadius, baseRadiuses.x, baseRadiuses.z, target)
                basePoints = getCircleVectorPoints(0, baseRadiuses.x, baseRadiuses.z, target)
            end
        end

        measuring.points = measuringPoints
        base.points = basePoints

        table.insert(measuringRings, measuring)
        table.insert(measuringRings, base)

        if change ~= 0 then
            broadcastToAll("Measuring "..tostring(newRadius).."\"")
        end
    end

    target.setVectorLines(measuringRings)

    ymMeasuringCircles = measuringRings
end


function getCircleVectorPoints(radius, baseX, baseZ, obj)
    local result = {}
    local scaleFactor = 1/obj.getScale().x
    local rotationDegrees =  obj.getRotation().y
    local steps = 64
    local degrees,sin,cos,toRads = 360/steps, math.sin, math.cos, math.rad

    for i = 0,steps do
        table.insert(result,{
            x = cos(toRads(degrees*i))*((radius+baseX)*scaleFactor),
            z = MEASURING_RING_Y_OFFSET,
            y = sin(toRads(degrees*i))*((radius+baseZ)*scaleFactor)
        })
    end

    return result
end


function getRectangleVectorPoints(radius, sizeX, sizeZ, obj)
    local result = {}
    local scaleFactor = 1/obj.getScale().x

    sizeX = sizeX*scaleFactor
    sizeZ = sizeZ*scaleFactor
    radius = radius*scaleFactor

    local steps = 65
    local degrees,sin,cos,toRads = 360/(steps-1), math.sin, math.cos, math.rad
    local xOffset,zOffset = sizeX,sizeZ
    -- compensate for ignoring vertical line
    table.insert(result,{
        x = (cos(toRads(degrees*0))*radius)+sizeX-0.001,
        y = (sin(toRads(degrees*0))*radius)+sizeZ,
        z = MEASURING_RING_Y_OFFSET
    })

    for i = 1,steps-1 do
        if i == 16 then
            table.insert(result,{ x= sizeX, y=(radius+sizeZ), z=MEASURING_RING_Y_OFFSET })
            table.insert(result,{ x=-sizeX, y=(radius+sizeZ), z=MEASURING_RING_Y_OFFSET })
            xOffset = -sizeX
        elseif i == 33 then
            table.insert(result,{ x=-radius-sizeX,       y= sizeZ, z=MEASURING_RING_Y_OFFSET })
            table.insert(result,{ x=-radius-sizeX-0.001, y=-sizeZ, z=MEASURING_RING_Y_OFFSET })
            table.insert(result,{ x=-radius-sizeX,       y=-sizeZ, z=MEASURING_RING_Y_OFFSET })
            zOffset = -sizeZ
        elseif i == 49 then
            table.insert(result,{ x=-sizeX, y=-radius-sizeZ, z=MEASURING_RING_Y_OFFSET })
            table.insert(result,{ x= sizeX, y=-radius-sizeZ, z=MEASURING_RING_Y_OFFSET })
            xOffset = sizeX
        elseif i == 65 then
            table.insert(result,{ x=radius+sizeX,       y=-sizeZ, z=MEASURING_RING_Y_OFFSET })
            table.insert(result,{ x=radius+sizeX-0.001, y= sizeZ, z=MEASURING_RING_Y_OFFSET })
        else
            table.insert(result,{
                x = (cos(toRads(degrees*i))*radius)+xOffset,
                y = (sin(toRads(degrees*i))*radius)+zOffset,
                z = MEASURING_RING_Y_OFFSET
            })
        end
    end
    -- compensate for ignoring vertical line
    table.insert(result,{
        x = (cos(toRads(degrees*0))*radius)+sizeX-0.001,
        y = (sin(toRads(degrees*0))*radius)+sizeZ,
        z = MEASURING_RING_Y_OFFSET
    })

    return result
end


function changeWoundCountString(mod, s)
    local _,_, current, total = s:find("([0-9]+)/([0-9]+)")
    if current == nil then return nil end
    current = math.max(tonumber(current) + mod, 0)
    total = tonumber(total)
    return string.gsub(s, "([0-9]+)/([0-9]+)", current.."/"..total, 1)
end


function changeModelWoundCount(mod, target)
    local name = target.getName()
    local newName = changeWoundCountString(mod, name)
    if newName == nil then return end

    target.setName(newName)

    -- If we have a fancy name and are in age of sigmar, update all the matching names
    local fancyName = string.match(name, "([0-9]+/[0-9]+ *[[][^\n]+)")
    if not fancyName then return end
    local description = target.getDescription()
    if not string.find(description, "Mo?v?e? +He?a?l?t?h? +[CB][oa]?n?[ti]?[rs]?[oh]?l? +Sa?v?e?") then return end
    for _, obj in pairs(getObjects()) do
        if string.match(obj.getName(), "([0-9]+/[0-9]+ *[[][^\n]+)") == fancyName then
            obj.setName(changeWoundCountString(mod, obj.getName()))
        end
    end
end

-- Changes color of aura. Does not support multiple auras at the moment.
function changeColor(playerColor, target)
    local currentColor = currentHighlightColor
    local colorWheel = {"pink", "purple", "blue", "teal", "green", "yellow", "orange", "red", "brown", "white"}
    local nextColor = "white"
    if currentColor ~= nil then
        nextColor = colorWheel[(indexOf(colorWheel, currentColor) % #colorWheel)+1]
    end

    local measuringRings = deepcopy(ymMeasuringCircles)
    if measuringRings ~= nil then
        for idx=#measuringRings,1,-1 do
            if (measuringRings[idx].name == currentColor) or (measuringRings[idx].name == nil and currentColor == nil) then
                measuringRings[idx].name = nextColor
            end
        end
        ymMeasuringCircles = measuringRings
    end
    currentHighlightColor = nextColor
    changeMeasurementCircle(0, target)
end


-- this needs to be defined after all scripting functions
scriptingFunctions = {
	none,
	--[[2]]  function (playerColor, target) changeModelWoundCount(-1, target) end,
	--[[3]]  function (playerColor, target) changeModelWoundCount(1, target) end,
	--[[4]]  function (playerColor, target) changeMeasurementCircle(1, target) end,
	--[[5]]  function (playerColor, target) changeMeasurementCircle(-1, target) end,
	--[[6]]  function (playerColor, target) assignBase(-1, target) end,
	--[[7]]  function (playerColor, target) assignBase(1, target) end,
	--[[8]]  toggleRectangularMeasuring,
	--[[9]]  changeColor,
	none,
	none
}

--[[ STABILIZATION ]]--

function stabilize()
  if not string.find(self.getDescription(), "STABILIZEME") then return end
  self.getComponent("Rigidbody").set("freezeRotation", true)
end

function destabilize()
  self.getComponent("Rigidbody").set("freezeRotation", false)
end
