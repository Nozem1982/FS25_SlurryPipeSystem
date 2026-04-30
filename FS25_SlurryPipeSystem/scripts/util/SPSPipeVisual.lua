-- FS25_SlurryPipeSystem 
-- Author: Oscar Mods 
-- Version: 1.0.0.0

-- SPSPipeVisual.lua
-- FS25_SlurryPipeSystem

SPSPipeVisual = {}
SPSPipeVisual.__index = SPSPipeVisual

SPSPipeVisual.NUM_BONES      = 17
SPSPipeVisual.TENSION_FACTOR = 0.4
SPSPipeVisual.SAG_FACTOR     = 0.04

function SPSPipeVisual.new(modDirectory)
    local self = setmetatable({}, SPSPipeVisual)
    self.modDirectory = modDirectory
    self._isLoaded    = false
    return self
end

function SPSPipeVisual:load()
    local pipePath = self.modDirectory .. "i3d/pipes/slurryPipe.i3d"
    if fileExists(pipePath) then
        self._isLoaded = true
    else
        print("[SPS SPPV] SPSPipeVisual: slurryPipe.i3d not found at " .. pipePath)
    end
end

function SPSPipeVisual:delete()
    self._isLoaded = false
end

function SPSPipeVisual:isReady()
    return self._isLoaded
end

-- ---------------------------------------------------------------------------
-- createPipe
-- nodeA and nodeB are world nodes — their position and rotation drive the bezier.
-- startConnectorType: "male" (default) or "female" — controls which start
-- connector shape is shown (the end attached to nodeA / couplingA).
-- endConnectorType:   "male" or "female" (default) — controls which end
-- connector shape is shown (the end attached to nodeB / couplingB).
-- ---------------------------------------------------------------------------
function SPSPipeVisual:createPipe(nodeA, nodeB, startConnectorType, endConnectorType)
    if not self._isLoaded then return nil end

    local pipePath = self.modDirectory .. "i3d/pipes/slurryPipe.i3d"
    local i3dRoot = loadI3DFile(pipePath)
    if i3dRoot == nil or i3dRoot == 0 then
        print("[SPS SPPV] SPSPipeVisual:createPipe - loadI3DFile failed")
        return nil
    end
    link(getRootNode(), i3dRoot)

    local pipeRoot = getChildAt(i3dRoot, 0)

    -- slurryPipeConnectors: pipeRoot child 1
    -- children: 0=female01, 1=male01, 2=componentJoint1, 3=componentJoint2, 4=bezierStart
    local connectorStart = getChildAt(pipeRoot, 1)

    local bones = {}
    -- Bone1: connectorStart child 2 (componentJoint1) child 0
    -- Bone2: connectorStart child 3 (componentJoint2) child 0
    bones[1] = getChildAt(getChildAt(connectorStart, 2), 0)
    bones[2] = getChildAt(getChildAt(connectorStart, 3), 0)

    -- Bones 3-15: pipeRoot children 2-14, each child 0
    for i = 3, 15 do
        local cj = getChildAt(pipeRoot, i - 1)
        bones[i] = getChildAt(cj, 0)
        if bones[i] == nil or bones[i] == 0 then
            print("[SPS SPPV] SPSPipeVisual:createPipe - bone " .. i .. " not found")
            delete(i3dRoot)
            return nil
        end
    end

    -- endConnectors: pipeRoot child 15
    -- children: 0=female02, 1=male02, 2=componentJoint16, 3=componentJoint17, ...
    local connectorEnd = getChildAt(pipeRoot, 15)

    -- Bone16: endConnectors child 2 (componentJoint16) child 0
    -- Bone17: endConnectors child 3 (componentJoint17) child 0
    bones[16] = getChildAt(getChildAt(connectorEnd, 2), 0)
    bones[17] = getChildAt(getChildAt(connectorEnd, 3), 0)

    if bones[1]  == nil or bones[1]  == 0
    or bones[17] == nil or bones[17] == 0 then
        print("[SPS SPPV] SPSPipeVisual:createPipe - Bone1 or Bone17 not found")
        delete(i3dRoot)
        return nil
    end

    -- Start connector: show female01 (child 0) or male01 (child 1) based on type
    local femaleStart = getChildAt(connectorStart, 0)
    local maleStart   = getChildAt(connectorStart, 1)
    if startConnectorType == "female" then
        if femaleStart ~= nil and femaleStart ~= 0 then setVisibility(femaleStart, true) end
        if maleStart   ~= nil and maleStart   ~= 0 then setVisibility(maleStart, false) end
    else
        -- default: male
        if femaleStart ~= nil and femaleStart ~= 0 then setVisibility(femaleStart, false) end
        if maleStart   ~= nil and maleStart   ~= 0 then setVisibility(maleStart, true) end
    end

    -- End connector: show female02 (child 0) or male02 (child 1) based on type.
    -- Default: female (matches stores and chain receivers which are typically female).
    local femaleEnd = getChildAt(connectorEnd, 0)
    local maleEnd   = getChildAt(connectorEnd, 1)
    if endConnectorType == "male" then
        if femaleEnd ~= nil and femaleEnd ~= 0 then setVisibility(femaleEnd, false) end
        if maleEnd   ~= nil and maleEnd   ~= 0 then setVisibility(maleEnd, true) end
    else
        -- default: female
        if femaleEnd ~= nil and femaleEnd ~= 0 then setVisibility(femaleEnd, true) end
        if maleEnd   ~= nil and maleEnd   ~= 0 then setVisibility(maleEnd, false) end
    end

    local inst = {
        i3dRoot        = i3dRoot,
        pipeRoot       = pipeRoot,
        connectorStart = connectorStart,
        connectorEnd   = connectorEnd,
        bones          = bones,
        nodeA          = nodeA,
        nodeB          = nodeB,
    }

    self:updatePipe(inst)
    return inst
end

-- ---------------------------------------------------------------------------
-- updatePipe
-- Called every tick. Snaps connectorStart to nodeA, connectorEnd to nodeB,
-- then positions all 17 bones along the bezier curve.
-- ---------------------------------------------------------------------------
function SPSPipeVisual:updatePipe(inst)
    if inst == nil then return end

    local nodeA = inst.nodeA
    local nodeB = inst.nodeB
    if nodeA == nil or nodeB == nil then return end

    local ax, ay, az    = getWorldTranslation(nodeA)
    local bx, by, bz    = getWorldTranslation(nodeB)
    local arx, ary, arz = getWorldRotation(nodeA)
    local brx, bry, brz = getWorldRotation(nodeB)

    -- Guard: if node was deleted its values will be nil
    if ax == nil or bx == nil or arx == nil or brx == nil then return end

    setWorldTranslation(inst.connectorStart, ax, ay, az)
    setWorldRotation(inst.connectorStart, arx, ary, arz)

    setWorldTranslation(inst.connectorEnd, bx, by, bz)
    if inst.connectorEndFlipped then
        setWorldRotation(inst.connectorEnd, brx, bry + math.pi, brz)
    else
        setWorldRotation(inst.connectorEnd, brx, bry, brz)
    end

    local dx   = bx - ax
    local dy   = by - ay
    local dz   = bz - az
    local span = math.sqrt(dx*dx + dy*dy + dz*dz)
    if span < 0.001 then return end

    local adx, ady, adz = localDirectionToWorld(nodeA, 0, 0, -1)
    local bdx, bdy, bdz = localDirectionToWorld(nodeB, 0, 0, -1)

    local tension = span * SPSPipeVisual.TENSION_FACTOR
    local sag     = span * SPSPipeVisual.SAG_FACTOR

    local p0x, p0y, p0z = ax, ay, az
    local p3x, p3y, p3z = bx, by, bz
    local p1x = p0x + adx * tension
    local p1y = p0y + ady * tension - sag
    local p1z = p0z + adz * tension
    local p2x = p3x + bdx * tension
    local p2y = p3y + bdy * tension - sag
    local p2z = p3z + bdz * tension

    setWorldTranslation(inst.pipeRoot, (ax+bx)*0.5, (ay+by)*0.5, (az+bz)*0.5)

    local NUM = SPSPipeVisual.NUM_BONES

    for i = 1, NUM do
        local t   = (i - 1) / (NUM - 1)
        local mt  = 1 - t
        local mt2 = mt * mt
        local mt3 = mt2 * mt
        local t2  = t * t
        local t3  = t2 * t

        local px = mt3*p0x + 3*mt2*t*p1x + 3*mt*t2*p2x + t3*p3x
        local py = mt3*p0y + 3*mt2*t*p1y + 3*mt*t2*p2y + t3*p3y
        local pz = mt3*p0z + 3*mt2*t*p1z + 3*mt*t2*p2z + t3*p3z

        local tdx = 3*mt2*(p1x-p0x) + 6*mt*t*(p2x-p1x) + 3*t2*(p3x-p2x)
        local tdy = 3*mt2*(p1y-p0y) + 6*mt*t*(p2y-p1y) + 3*t2*(p3y-p2y)
        local tdz = 3*mt2*(p1z-p0z) + 6*mt*t*(p2z-p1z) + 3*t2*(p3z-p2z)

        local tlen = math.sqrt(tdx*tdx + tdy*tdy + tdz*tdz)
        if tlen > 0.0001 then
            tdx = tdx / tlen
            tdy = tdy / tlen
            tdz = tdz / tlen
        end

        local ry = math.atan2(tdx, tdz)
        local rx = -math.atan2(tdy, math.sqrt(tdx*tdx + tdz*tdz))

        setWorldTranslation(inst.bones[i], px, py, pz)
        setWorldRotation(inst.bones[i], rx, ry, 0)
    end
end

-- ---------------------------------------------------------------------------
-- applyColor
-- Sets the colorScale shader parameter on the hose mesh of a pipe inst.
-- ---------------------------------------------------------------------------
function SPSPipeVisual:applyColor(inst, r, g, b)
    if inst == nil or inst.pipeRoot == nil then
        print("[SPS SPPV] SPSPipeVisual:applyColor — inst or pipeRoot nil, skipping")
        return
    end
    local hoseNode = getChildAt(inst.pipeRoot, 0)
    if hoseNode ~= nil and hoseNode ~= 0 then
        setShaderParameter(hoseNode, "colorScale", r, g, b, 0, false)
    else
        print("[SPS SPPV] SPSPipeVisual:applyColor — hoseNode nil, colour not applied")
    end
end

-- ---------------------------------------------------------------------------
-- destroyPipe
-- ---------------------------------------------------------------------------
function SPSPipeVisual:destroyPipe(inst)
    if inst == nil then return end
    if inst.i3dRoot ~= nil and inst.i3dRoot ~= 0 then
        delete(inst.i3dRoot)
        inst.i3dRoot = nil
    end
end