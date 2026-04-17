-- FS25_SlurryPipeSystem 
-- Author: Oscar Mods 
-- Version: 1.0.0.0

-- SPSPipeChain.lua
-- FS25_SlurryPipeSystem

SPSPipeChain = {}
SPSPipeChain.__index = SPSPipeChain

SPSPipeChain.PIPE_LENGTH   = 4.0
SPSPipeChain.PLAYER_OFFSET = 0.75

function SPSPipeChain.new(anchorCoupling, modDirectory)
    local self            = setmetatable({}, SPSPipeChain)
    self.anchorCoupling   = anchorCoupling
    self.modDirectory     = modDirectory
    self.segments         = {}
    self.liveSegment      = nil
    self.dockingStation   = nil
    return self
end

function SPSPipeChain:delete()
    self:_removeDockingStation()
    if self.liveSegment ~= nil then
        self:_destroySegmentNodes(self.liveSegment)
        self.liveSegment = nil
    end
    for i = #self.segments, 1, -1 do
        self:_destroySegmentNodes(self.segments[i])
    end
    self.segments = {}
end

-- ---------------------------------------------------------------------------
-- Start laying a new live pipe.
-- First pipe uses caller sx/sy/sz/sry (anchorCoupling position).
-- Chained pipes derive position and rotation from previous segment geometry.
-- ---------------------------------------------------------------------------
function SPSPipeChain:startLaying(sx, sy, sz, sry)
    if self.liveSegment ~= nil then return end

    if #self.segments > 0 then
        local prevSeg     = self.segments[#self.segments]
        local prx, _, prz = getWorldTranslation(prevSeg.pipeRoot)
        sx, sy, sz        = getWorldTranslation(prevSeg.endConnectors)
        local ddx  = sx - prx
        local ddz  = sz - prz
        local dlen = math.sqrt(ddx * ddx + ddz * ddz)
        if dlen > 0.01 then
            sry = math.atan2(-ddx / dlen, -ddz / dlen)
        end
    end

    local seg = self:_loadPipe(sx, sy, sz, sry or 0)
    if seg == nil then return end
    self.liveSegment = seg
    print("[SPS] SPSPipeChain: started laying")
end

-- ---------------------------------------------------------------------------
-- Lock the current live pipe in place
-- ---------------------------------------------------------------------------
function SPSPipeChain:lockLivePipe()
    if self.liveSegment == nil then return end
    local seg = self.liveSegment
    self.liveSegment = nil

    -- The previous last segment is no longer the end — remove its end activatable
    if #self.segments > 0 then
        local prevLast = self.segments[#self.segments]
        if prevLast.endActivatable ~= nil then
            prevLast.endActivatable:delete()
            prevLast.endActivatable = nil
        end
    end

    table.insert(self.segments, seg)

    if g_slurryPipeManager ~= nil then
        table.insert(g_slurryPipeManager.chainTerminusEntries, seg.chainCoupling)
    end

    -- Segment 1 only: register detNode04 as a chain start detection coupling
    -- so vehicles can arc-detect the start end and connect a bez pipe to it.
    if #self.segments == 1 and g_slurryPipeManager ~= nil then
        local detNode04 = seg.detNode04
        if detNode04 ~= nil and detNode04 ~= 0 then
            local startCoupling = {
                id                       = -2,
                mountNode                = detNode04,
                arcNode                  = nil,
                isConnected              = false,
                valveOpen                = false,
                connectedTarget          = nil,
                connectedPartnerCoupling = nil,
                pipeId                   = nil,
                isChainTerminus          = true,
                chain                    = self,
                segmentIndex             = 0,
                sourceEntry              = self.anchorCoupling.sourceEntry,
                placeable                = self.anchorCoupling.placeable,
                isChainStart             = true,
            }
            seg.chainStartCoupling = startCoupling
            table.insert(g_slurryPipeManager.chainTerminusEntries, startCoupling)
            print("[SPS] lockLivePipe: chain start detection coupling registered on detNode04")

            -- Vehicle anchor: auto-connect bez pipe between vehicle coupler and chain start.
            -- The anchor coupling is a vehicle coupling if it has no placeable.
            -- This bez is removable/reconnectable independently of the chain segments.
            if self.anchorCoupling.placeable == nil and not self.anchorCoupling.isConnected then
                local vehicle, _ = g_slurryPipeManager:_findCouplingOwner(self.anchorCoupling)
                if vehicle ~= nil then
                    local ownerA = vehicle
                    g_slurryPipeManager:applyConnectCouplings(
                        self.anchorCoupling, startCoupling, ownerA, nil)
                    SlurryPipeConnectEvent.sendEvent(
                        vehicle, nil,
                        SlurryPipeConnectEvent.TARGET_TYPE_PLACEABLE,
                        self.anchorCoupling.id, startCoupling.id)
                    print("[SPS] lockLivePipe: auto-connected bez from vehicle coupler to chain start")
                end
            end
        end
    end

    -- Primary activatable at pipeRoot (start of segment): offers "remove from here"
    local activatable = SPSChainActivatable.new(self, #self.segments)
    g_currentMission.activatableObjectsSystem:addActivatable(activatable)
    seg.activatable = activatable

    -- End activatable at detNode01 (end of segment): offers "lay more" / docking station
    local endActivatable = SPSChainActivatable.new(self, #self.segments)
    endActivatable.isEndActivatable = true
    g_currentMission.activatableObjectsSystem:addActivatable(endActivatable)
    seg.endActivatable = endActivatable

    print("[SPS] SPSPipeChain: locked segment " .. #self.segments .. " — primary@pipeRoot end@endConnectors")
end

-- ---------------------------------------------------------------------------
-- Cancel (remove) the current live pipe without locking
-- ---------------------------------------------------------------------------
function SPSPipeChain:cancelLivePipe()
    if self.liveSegment == nil then return end
    self:_destroySegmentNodes(self.liveSegment)
    self.liveSegment = nil
    print("[SPS] SPSPipeChain: cancelled live pipe")
end

-- ---------------------------------------------------------------------------
-- Remove locked segments from fromIndex to end
-- ---------------------------------------------------------------------------
function SPSPipeChain:removeFromIndex(fromIndex)
    if fromIndex < 1 then fromIndex = 1 end
    if self.dockingStation ~= nil then self:_removeDockingStation() end
    for i = #self.segments, fromIndex, -1 do
        self:_destroySegmentNodes(self.segments[i])
        table.remove(self.segments, i)
    end
    print("[SPS] SPSPipeChain:removeFromIndex(" .. fromIndex .. ") — segments remaining: " .. #self.segments)

    -- The new last segment lost its endActivatable when the next segment was locked.
    -- Recreate it so the player can continue laying or add a docking station.
    if #self.segments > 0 then
        local newLast = self.segments[#self.segments]
        if newLast.endActivatable == nil then
            local endAct = SPSChainActivatable.new(self, #self.segments)
            endAct.isEndActivatable = true
            g_currentMission.activatableObjectsSystem:addActivatable(endAct)
            newLast.endActivatable = endAct
        end
    end
end

-- ---------------------------------------------------------------------------
-- Load a pipe i3d, link to world root, position at startX/Y/Z with startRY
-- ---------------------------------------------------------------------------
function SPSPipeChain:_loadPipe(startX, startY, startZ, startRY, colorR, colorG, colorB)
    local pipePath = self.modDirectory .. "i3d/pipes/slurryPipe.i3d"
    local i3dRoot  = loadI3DFile(pipePath)
    if i3dRoot == nil or i3dRoot == 0 then
        print("[SPS] SPSPipeChain: failed to load slurryPipe.i3d")
        return nil
    end

    local pipeRoot      = getChildAt(i3dRoot, 0)
    local endConnectors = getChildAt(pipeRoot, 15)
    local detNode01     = getChildAt(endConnectors, 5)
    local endFloorLevel = getChildAt(endConnectors, 6)
    -- endConnectors: child 0=female02, child 1=male02
    local femaleConn    = getChildAt(endConnectors, 0)
    local maleConn      = getChildAt(endConnectors, 1)
    local detNode04     = getChildAt(pipeRoot, 16)  -- chain start detection node (detectionNode04)

    -- Collect all 17 bones for bezier driving.
    -- Bone1, Bone2: inside slurryPipeConnectors (pipeRoot child 1), children 2 and 3
    -- Bone3-Bone15: pipeRoot children 2-14, each child 0
    -- Bone16, Bone17: inside endConnectors (pipeRoot child 15), children 2 and 3
    local connectorStartNode = getChildAt(pipeRoot, 1)
    local allBones = {}
    allBones[1]  = getChildAt(getChildAt(connectorStartNode, 2), 0)  -- Bone1
    allBones[2]  = getChildAt(getChildAt(connectorStartNode, 3), 0)  -- Bone2
    for i = 3, 15 do
        local cj = getChildAt(pipeRoot, i - 1)
        allBones[i] = getChildAt(cj, 0)
    end
    allBones[16] = getChildAt(getChildAt(endConnectors, 2), 0)  -- Bone16
    allBones[17] = getChildAt(getChildAt(endConnectors, 3), 0)  -- Bone17

    link(getRootNode(), pipeRoot)
    setWorldTranslation(pipeRoot, startX, startY, startZ)
    setWorldRotation(pipeRoot, 0, startRY, 0)
    delete(i3dRoot)

    -- Chain segment: start = male connector, end = female connector (always)
    local connStart    = getChildAt(pipeRoot, 1)   -- slurryPipeConnectors
    local femaleStart  = getChildAt(connStart, 0)  -- female01
    local maleStart    = getChildAt(connStart, 1)  -- male01
    if femaleStart ~= nil and femaleStart ~= 0 then setVisibility(femaleStart, false) end
    if maleStart   ~= nil and maleStart   ~= 0 then setVisibility(maleStart,   true)  end
    if femaleConn  ~= nil and femaleConn  ~= 0 then setVisibility(femaleConn,  true)  end
    if maleConn    ~= nil and maleConn    ~= 0 then setVisibility(maleConn,    false) end

    -- Apply pipe colour to hose mesh (pipeRoot child 0)
    local cr = colorR or (g_slurryPipeManager and g_slurryPipeManager.currentPipeColor.r or 0)
    local cg = colorG or (g_slurryPipeManager and g_slurryPipeManager.currentPipeColor.g or 0.05)
    local cb = colorB or (g_slurryPipeManager and g_slurryPipeManager.currentPipeColor.b or 0)
    local hoseNode = getChildAt(pipeRoot, 0)
    if hoseNode ~= nil and hoseNode ~= 0 then
        setShaderParameter(hoseNode, "colorScale", cr, cg, cb, 0, false)
    else
        print("[SPS PC] _loadPipe WARNING hoseNode is nil — colour not applied")
    end

    local chainCoupling = {
        id                       = #self.segments + 1,
        mountNode                = detNode01,
        arcNode                  = nil,
        isConnected              = false,
        valveOpen                = false,
        connectedTarget          = nil,
        connectedPartnerCoupling = nil,
        pipeId                   = nil,
        isChainTerminus          = true,
        chain                    = self,
        segmentIndex             = #self.segments + 1,
        sourceEntry              = self.anchorCoupling.sourceEntry,
        placeable                = self.anchorCoupling.placeable,
    }

    return {
        pipeRoot      = pipeRoot,
        endConnectors = endConnectors,
        detNode01     = detNode01,
        detNode04     = detNode04,
        endFloorLevel = endFloorLevel,
        allBones      = allBones,
        chainCoupling = chainCoupling,
        activatable   = nil,
        startX        = startX,
        startY        = startY,
        startZ        = startZ,
        startRY       = startRY,
        colorR        = cr,
        colorG        = cg,
        colorB        = cb,
    }
end

-- ---------------------------------------------------------------------------
-- Update — called each tick from manager
-- ---------------------------------------------------------------------------
function SPSPipeChain:update(dt)
    if self.liveSegment == nil then return end
    if g_localPlayer == nil then return end

    local seg = self.liveSegment

    local px, _, pz = getWorldTranslation(g_localPlayer.rootNode)
    local sx, sy, sz = seg.startX, seg.startY, seg.startZ
    local dx = px - sx
    local dz = pz - sz
    local dist = math.sqrt(dx * dx + dz * dz)

    local dirX, dirZ
    if dist > SPSPipeChain.PLAYER_OFFSET then
        dirX = dx / dist
        dirZ = dz / dist
    else
        local ry = seg.startRY or 0
        dirX = -math.sin(ry)
        dirZ = -math.cos(ry)
    end

    local ex = sx + dirX * SPSPipeChain.PIPE_LENGTH
    local ez = sz + dirZ * SPSPipeChain.PIPE_LENGTH
    local terrain = g_currentMission ~= nil and g_currentMission.terrainRootNode or nil
    local ey = sy
    if terrain ~= nil then
        ey = getTerrainHeightAtWorldPos(terrain, ex, 0, ez)
    end
    local _, floorOffset, _ = getTranslation(seg.endFloorLevel)

    setWorldTranslation(seg.endConnectors, ex, ey - floorOffset, ez)
    setWorldRotation(seg.endConnectors, 0, math.atan2(dirX, dirZ) + math.pi, 0)

    self:_updateBezierBones(seg)
end

-- ---------------------------------------------------------------------------
-- Bezier: P0 = pipeRoot, P3 = endConnectors
-- ---------------------------------------------------------------------------
function SPSPipeChain:_updateBezierBones(seg)
    local p0x, p0y, p0z = getWorldTranslation(seg.pipeRoot)
    local p3x, p3y, p3z = getWorldTranslation(seg.endConnectors)

    local span = math.sqrt((p3x-p0x)^2 + (p3y-p0y)^2 + (p3z-p0z)^2)
    if span < 0.01 then return end

    local t1x, t1y, t1z = localDirectionToWorld(seg.pipeRoot, 0, 0, -1)

    local ecFwdX, ecFwdY, ecFwdZ = localDirectionToWorld(seg.endConnectors, 0, 0, -1)
    local backX, backY, backZ = -ecFwdX, -ecFwdY, -ecFwdZ

    local tension = math.max(span, 2.0) * 0.5

    local p1x = p0x + t1x * tension
    local p1y = p0y + t1y * tension
    local p1z = p0z + t1z * tension
    local p2x = p3x + backX * tension
    local p2y = p3y + backY * tension
    local p2z = p3z + backZ * tension

    local NUM = 17
    for i = 1, NUM do
        local bone = seg.allBones[i]
        if bone ~= nil and bone ~= 0 then
            local t   = (i - 1) / (NUM - 1)
            local mt  = 1 - t
            local mt2 = mt * mt
            local mt3 = mt2 * mt
            local t2  = t * t
            local t3  = t2 * t

            local bx = mt3*p0x + 3*mt2*t*p1x + 3*mt*t2*p2x + t3*p3x
            local by = mt3*p0y + 3*mt2*t*p1y + 3*mt*t2*p2y + t3*p3y
            local bz = mt3*p0z + 3*mt2*t*p1z + 3*mt*t2*p2z + t3*p3z

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

            setWorldTranslation(bone, bx, by, bz)
            setWorldRotation(bone, rx, ry, 0)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Destroy all scene nodes for a segment
-- ---------------------------------------------------------------------------
function SPSPipeChain:_destroySegmentNodes(seg)
    if seg == nil then return end

    if g_slurryPipeManager ~= nil and seg.chainCoupling ~= nil then
        local entries = g_slurryPipeManager.chainTerminusEntries
        for i, e in ipairs(entries) do
            if e == seg.chainCoupling then table.remove(entries, i) break end
        end
        if seg.chainCoupling.isConnected then
            g_slurryPipeManager:applyDisconnect(nil, seg.chainCoupling.id, seg.chainCoupling)
        end
    end

    -- Clean up chain start detection coupling if present (segment 1 only)
    if g_slurryPipeManager ~= nil and seg.chainStartCoupling ~= nil then
        local entries = g_slurryPipeManager.chainTerminusEntries
        for i, e in ipairs(entries) do
            if e == seg.chainStartCoupling then table.remove(entries, i) break end
        end
        if seg.chainStartCoupling.isConnected then
            g_slurryPipeManager:applyDisconnect(nil, seg.chainStartCoupling.id, seg.chainStartCoupling)
        end
        seg.chainStartCoupling = nil
    end

    if seg.activatable ~= nil then
        seg.activatable:delete()
        seg.activatable = nil
    end

    if seg.endActivatable ~= nil then
        seg.endActivatable:delete()
        seg.endActivatable = nil
    end

    if seg.pipeRoot ~= nil and seg.pipeRoot ~= 0 then
        delete(seg.pipeRoot)
        seg.pipeRoot      = nil
        seg.endConnectors = nil
        seg.detNode01     = nil
        seg.endFloorLevel = nil
    end
end

-- ---------------------------------------------------------------------------
-- Docking station
-- ---------------------------------------------------------------------------
function SPSPipeChain:addDockingStation()
    if #self.segments == 0 then return end
    if self.dockingStation ~= nil then return end

    local lastSeg = self.segments[#self.segments]

    local dsPath  = self.modDirectory .. "i3d/dockingStation/dockingStation.i3d"
    local i3dRoot = loadI3DFile(dsPath)
    if i3dRoot == nil or i3dRoot == 0 then
        print("[SPS] SPSPipeChain: failed to load dockingStation.i3d")
        return
    end

    local dsNode        = getChildAt(i3dRoot, 0)
    local visShape      = getChildAt(dsNode, 0)
    local lowerNode     = getChildAt(visShape, 0)
    local upperNode     = getChildAt(visShape, 1)
    local dockingTarget = getChildAt(dsNode, 2)

    local ex, ey, ez = getWorldTranslation(lastSeg.endConnectors)
    local rx, ry, rz = getWorldRotation(lastSeg.endConnectors)
    local terrain  = g_currentMission ~= nil and g_currentMission.terrainRootNode or nil
    local terrainY = (terrain ~= nil) and getTerrainHeightAtWorldPos(terrain, ex, 0, ez) or ey

    link(getRootNode(), dsNode)
    setWorldTranslation(dsNode, ex, terrainY, ez)
    setWorldRotation(dsNode, rx, ry, rz)
    delete(i3dRoot)

    -- Save endConnectors position before moving it, so it can be restored if DS is removed
    local origEx, origEy, origEz       = getWorldTranslation(lastSeg.endConnectors)
    local origErx, origEry, origErz    = getWorldRotation(lastSeg.endConnectors)

    -- Move lastSeg endConnectors to dockingTarget world position so the segment
    -- pipe naturally ends at the DS inlet. Keep original rotation for the bezier
    -- arrival tangent.
    local dtx, dty, dtz = getWorldTranslation(dockingTarget)
    setWorldTranslation(lastSeg.endConnectors, dtx, dty, dtz)
    self:_updateBezierBones(lastSeg)

    local rbpEntry = {
        vehicle   = nil,
        lowerNode = lowerNode,
        upperNode = upperNode,
        valveType = SPS_VALVE_TYPE_NONE,
        valveOpen = true,
        isChain   = true,
        chain     = self,
    }
    if g_slurryPipeManager ~= nil then
        table.insert(g_slurryPipeManager.rubberBootPortEntries, rbpEntry)
    end

    self._dsSaveX  = ex      ; self._dsSaveY  = terrainY ; self._dsSaveZ  = ez
    self._dsSaveRX = rx      ; self._dsSaveRY = ry        ; self._dsSaveRZ = rz

    self.dockingStation = {
        dsNode        = dsNode,
        dockingTarget = dockingTarget,
        rbpEntry      = rbpEntry,
        lastSeg       = lastSeg,
        origEndX      = origEx,  origEndY  = origEy,  origEndZ  = origEz,
        origEndRX     = origErx, origEndRY = origEry, origEndRZ = origErz,
    }

    if self.anchorCoupling ~= nil then
        self.anchorCoupling.valveOpen = true
    end

    print("[SPS] SPSPipeChain: docking station added")
end

function SPSPipeChain:removeDockingStation()
    self:_removeDockingStation()
end

function SPSPipeChain:_removeDockingStation()
    if self.dockingStation == nil then return end

    if g_slurryPipeManager ~= nil then
        local entries = g_slurryPipeManager.rubberBootPortEntries
        for i, e in ipairs(entries) do
            if e == self.dockingStation.rbpEntry then table.remove(entries, i) break end
        end
    end

    -- Restore last segment's endConnectors to its pre-DS position
    local ds = self.dockingStation
    if ds.lastSeg ~= nil and ds.lastSeg.endConnectors ~= nil and ds.origEndX ~= nil then
        setWorldTranslation(ds.lastSeg.endConnectors, ds.origEndX,  ds.origEndY,  ds.origEndZ)
        setWorldRotation(ds.lastSeg.endConnectors,    ds.origEndRX, ds.origEndRY, ds.origEndRZ)
        self:_updateBezierBones(ds.lastSeg)
    end

    if ds.dsNode ~= nil and ds.dsNode ~= 0 then
        delete(ds.dsNode)
    end

    self.dockingStation = nil
    self._dsSaveX = nil ; self._dsSaveY = nil ; self._dsSaveZ = nil
    self._dsSaveRX = nil ; self._dsSaveRY = nil ; self._dsSaveRZ = nil

    if self.anchorCoupling ~= nil then
        self.anchorCoupling.valveOpen = false
    end
    print("[SPS] SPSPipeChain: docking station removed")
end

-- ---------------------------------------------------------------------------
-- Save / Restore
-- ---------------------------------------------------------------------------
function SPSPipeChain:getSaveData()
    local data = {
        anchorX           = 0,
        anchorY           = 0,
        anchorZ           = 0,
        hasDockingStation = self.dockingStation ~= nil,
        dsSaveX           = self._dsSaveX  or 0,
        dsSaveY           = self._dsSaveY  or 0,
        dsSaveZ           = self._dsSaveZ  or 0,
        dsSaveRX          = self._dsSaveRX or 0,
        dsSaveRY          = self._dsSaveRY or 0,
        dsSaveRZ          = self._dsSaveRZ or 0,
        segments          = {},
    }
    if self.anchorCoupling.mountNode ~= nil then
        data.anchorX, data.anchorY, data.anchorZ =
            getWorldTranslation(self.anchorCoupling.mountNode)
    end
    -- Save pipeRoot of first segment so vehicle chains restore from the correct start position
    if #self.segments > 0 and self.segments[1].pipeRoot ~= nil then
        data.chainStartX, data.chainStartY, data.chainStartZ =
            getWorldTranslation(self.segments[1].pipeRoot)
        local _, chainStartRY, _ = getWorldRotation(self.segments[1].pipeRoot)
        data.chainStartRY = chainStartRY
    end
    for i, seg in ipairs(self.segments) do
        -- If DS is present, save the original (pre-DS-move) endConnectors position
        -- so that on restore the segment is rebuilt correctly before DS reattaches
        local wx, wy, wz, rx, ry, rz
        if self.dockingStation ~= nil and i == #self.segments
        and self.dockingStation.origEndX ~= nil then
            wx = self.dockingStation.origEndX ; wy = self.dockingStation.origEndY
            wz = self.dockingStation.origEndZ
            rx = self.dockingStation.origEndRX ; ry = self.dockingStation.origEndRY
            rz = self.dockingStation.origEndRZ
        else
            if seg.endConnectors ~= nil and seg.endConnectors ~= 0 then
                wx, wy, wz = getWorldTranslation(seg.endConnectors)
                rx, ry, rz = getWorldRotation(seg.endConnectors)
            end
        end
        if wx ~= nil then
            table.insert(data.segments, { x=wx, y=wy, z=wz, rx=rx, ry=ry, rz=rz,
                colorR=seg.colorR, colorG=seg.colorG, colorB=seg.colorB })
        end
    end
    return data
end

function SPSPipeChain:restoreFromSaveData(data)
    local nextX, nextY, nextZ, nextRY
    if data.chainStartX ~= nil then
        nextX, nextY, nextZ = data.chainStartX, data.chainStartY, data.chainStartZ
        -- Derive pipeRoot facing from direction toward segment 1.
        -- Saved chainStartRY is the coupling facing direction — not the actual pipe
        -- extension direction — using it causes a backwards bezier arc on restore.
        if #data.segments > 0 then
            local seg1 = data.segments[1]
            local dx = seg1.x - data.chainStartX
            local dz = seg1.z - data.chainStartZ
            local len = math.sqrt(dx * dx + dz * dz)
            nextRY = len > 0.001 and math.atan2(-dx / len, -dz / len) or (data.chainStartRY or 0)
        else
            nextRY = data.chainStartRY or 0
        end
    else
        nextX, nextY, nextZ = getWorldTranslation(self.anchorCoupling.mountNode)
        local _, ry, _ = getWorldRotation(self.anchorCoupling.mountNode)
        nextRY = ry
    end

    for i, segData in ipairs(data.segments) do
        local seg = self:_loadPipe(nextX, nextY, nextZ, nextRY,
            segData.colorR, segData.colorG, segData.colorB)
        if seg == nil then break end
        -- Compute clean rotation for endConnectors matching how update() sets it during gameplay
        local p0x, p0y, p0z = getWorldTranslation(seg.pipeRoot)
        local dx = segData.x - p0x
        local dz = segData.z - p0z
        local len = math.sqrt(dx*dx + dz*dz)
        local cleanRY = len > 0.001 and (math.atan2(dx / len, dz / len) + math.pi) or 0
        setWorldTranslation(seg.endConnectors, segData.x, segData.y, segData.z)
        setWorldRotation(seg.endConnectors, 0, cleanRY, 0)
        self:_updateBezierBones(seg)
        table.insert(self.segments, seg)
        if g_slurryPipeManager ~= nil then
            table.insert(g_slurryPipeManager.chainTerminusEntries, seg.chainCoupling)
        end

        -- Segment 1 only: recreate chainStartCoupling at detNode04 so the saved
        -- bez connection can be restored by tryResolvePendingConnections.
        -- Do NOT auto-connect here — the saved connection handles that.
        if i == 1 and g_slurryPipeManager ~= nil then
            local detNode04 = seg.detNode04
            if detNode04 ~= nil and detNode04 ~= 0 then
                local startCoupling = {
                    id                       = -2,
                    mountNode                = detNode04,
                    arcNode                  = nil,
                    isConnected              = false,
                    valveOpen                = false,
                    connectedTarget          = nil,
                    connectedPartnerCoupling = nil,
                    pipeId                   = nil,
                    isChainTerminus          = true,
                    chain                    = self,
                    segmentIndex             = 0,
                    sourceEntry              = self.anchorCoupling.sourceEntry,
                    placeable                = self.anchorCoupling.placeable,
                    isChainStart             = true,
                }
                seg.chainStartCoupling = startCoupling
                table.insert(g_slurryPipeManager.chainTerminusEntries, startCoupling)
            end
        end

        -- Primary activatable at pipeRoot (remove from here)
        local activatable = SPSChainActivatable.new(self, #self.segments)
        g_currentMission.activatableObjectsSystem:addActivatable(activatable)
        seg.activatable = activatable
        -- End activatable at detNode01 (lay more / DS) — only for the last segment
        local endActivatable = SPSChainActivatable.new(self, #self.segments)
        endActivatable.isEndActivatable = true
        g_currentMission.activatableObjectsSystem:addActivatable(endActivatable)
        seg.endActivatable = endActivatable
        nextX, nextY, nextZ = segData.x, segData.y, segData.z
        local ndx = segData.x - p0x
        local ndz = segData.z - p0z
        local nlen = math.sqrt(ndx*ndx + ndz*ndz)
        nextRY = nlen > 0.001 and math.atan2(-ndx / nlen, -ndz / nlen) or nextRY

        if i < #data.segments then
            if seg.endActivatable ~= nil then
                seg.endActivatable:delete()
                seg.endActivatable = nil
            end
        end
    end
    if data.hasDockingStation then
        self:_restoreDockingStation(data)
    end
    print("[SPS] SPSPipeChain: restored " .. #self.segments .. " segments")
end

function SPSPipeChain:_restoreDockingStation(data)
    if #self.segments == 0 then return end
    local lastSeg = self.segments[#self.segments]

    local dsPath  = self.modDirectory .. "i3d/dockingStation/dockingStation.i3d"
    local i3dRoot = loadI3DFile(dsPath)
    if i3dRoot == nil or i3dRoot == 0 then return end

    local dsNode        = getChildAt(i3dRoot, 0)
    local visShape      = getChildAt(dsNode, 0)
    local lowerNode     = getChildAt(visShape, 0)
    local upperNode     = getChildAt(visShape, 1)
    local dockingTarget = getChildAt(dsNode, 2)

    link(getRootNode(), dsNode)
    setWorldTranslation(dsNode, data.dsSaveX, data.dsSaveY, data.dsSaveZ)
    setWorldRotation(dsNode, data.dsSaveRX, data.dsSaveRY, data.dsSaveRZ)
    delete(i3dRoot)

    -- Save original endConnectors pos then move to dockingTarget
    local origEx, origEy, origEz    = getWorldTranslation(lastSeg.endConnectors)
    local origErx, origEry, origErz = getWorldRotation(lastSeg.endConnectors)

    local dtx, dty, dtz = getWorldTranslation(dockingTarget)
    setWorldTranslation(lastSeg.endConnectors, dtx, dty, dtz)
    self:_updateBezierBones(lastSeg)

    local rbpEntry = {
        vehicle   = nil,
        lowerNode = lowerNode,
        upperNode = upperNode,
        valveType = SPS_VALVE_TYPE_NONE,
        valveOpen = true,
        isChain   = true,
        chain     = self,
    }
    if g_slurryPipeManager ~= nil then
        table.insert(g_slurryPipeManager.rubberBootPortEntries, rbpEntry)
    end

    self._dsSaveX  = data.dsSaveX  ; self._dsSaveY  = data.dsSaveY  ; self._dsSaveZ  = data.dsSaveZ
    self._dsSaveRX = data.dsSaveRX ; self._dsSaveRY = data.dsSaveRY ; self._dsSaveRZ = data.dsSaveRZ

    self.dockingStation = {
        dsNode        = dsNode,
        dockingTarget = dockingTarget,
        rbpEntry      = rbpEntry,
        lastSeg       = lastSeg,
        origEndX      = origEx,  origEndY  = origEy,  origEndZ  = origEz,
        origEndRX     = origErx, origEndRY = origEry, origEndRZ = origErz,
    }
    if self.anchorCoupling ~= nil then
        self.anchorCoupling.valveOpen = true
    end
end