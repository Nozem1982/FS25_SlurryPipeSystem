-- FS25_SlurryPipeSystem
-- Author: Oscar Mods
-- Version: 1.0.0.0

-- SPSCrustVegetation.lua
-- Manages procedural vegetation on slurry fill planes.
-- Each i3d contains exactly one stage of one plant — no shape hiding needed.
-- Stage is declared per plant in fillPoints.xml.
-- All pools share a global exclusion zone so no two instances overlap.

SPSCrustVegetation = {}

SPSCrustVegetation.THRESH = { [1] = 0.4, [2] = 0.6, [3] = 0.8 }

-- ---------------------------------------------------------------------------
-- readConfig
-- ---------------------------------------------------------------------------
function SPSCrustVegetation.readConfig(xmlFile)
    if not xmlFile:hasProperty("slurryPipeSystem.crust") then return nil end
    local density = xmlFile:getFloat("slurryPipeSystem.crust#density", 0.3)
    local plants  = {}
    local idx = 0
    while true do
        local pKey = string.format("slurryPipeSystem.crust.plant(%d)", idx)
        if not xmlFile:hasProperty(pKey) then break end
        local i3dRelPath = xmlFile:getString(pKey .. "#i3d")
        local stage      = xmlFile:getInt(pKey .. "#stage", 1)
        local weight     = xmlFile:getInt(pKey .. "#weight", 1)
        if i3dRelPath ~= nil then
            table.insert(plants, { i3dRelPath = i3dRelPath, stage = stage, weight = weight })
        end
        idx = idx + 1
    end
    if #plants == 0 then return nil end
    return { density = density, plants = plants }
end

-- ---------------------------------------------------------------------------
-- initForPlaceable
-- ---------------------------------------------------------------------------
function SPSCrustVegetation.initForPlaceable(pEntry, modDirectory)
    local cfg         = pEntry.crustConfig
    local sourceEntry = pEntry.sourceEntry
    print("[SPS CrustVeg] initForPlaceable: " .. tostring(pEntry.placeable ~= nil and pEntry.placeable.configFileName or "nil")
        .. " cfg=" .. tostring(cfg ~= nil)
        .. " sourceEntry=" .. tostring(sourceEntry ~= nil)
        .. " fillPlaneNode=" .. tostring(sourceEntry ~= nil and sourceEntry.fillPlaneNode ~= nil or false)
        .. " planeBounds=" .. tostring(sourceEntry ~= nil and sourceEntry.planeBounds ~= nil or false))
    if cfg == nil then return end
    if sourceEntry == nil or sourceEntry.fillPlaneNode == nil then return end
    if sourceEntry.planeBounds == nil then return end

    local fillPlaneNode = sourceEntry.fillPlaneNode
    local bounds        = sourceEntry.planeBounds

    local area
    if bounds.shape == "round" then
        area = math.pi * bounds.radius * bounds.radius
    else
        area = (bounds.maxX - bounds.minX) * (bounds.maxZ - bounds.minZ)
    end

    local totalCount = math.max(3, math.floor(area * cfg.density))
    local poolSize   = math.floor(totalCount / 3)
    local minDist    = math.max(0.5, 1.2 / math.sqrt(cfg.density + 0.001))

    -- Build per-stage weighted lists
    local byStage = { [1] = {}, [2] = {}, [3] = {} }
    for _, plant in ipairs(cfg.plants) do
        local s = plant.stage
        if byStage[s] ~= nil then
            for _ = 1, plant.weight do
                table.insert(byStage[s], plant)
            end
        end
    end

    pEntry.crustInstances = { [1] = {}, [2] = {}, [3] = {} }

    -- Global exclusion zone shared across all three stage pools
    local allPlaced = {}
    local cx, cy, cz = getWorldTranslation(bounds.centreNode)

    local function pickPosition()
        for _ = 1, 30 do
            local wx, wz
            if bounds.shape == "round" then
                local angle  = math.random() * 2 * math.pi
                local radius = math.sqrt(math.random()) * bounds.radius
                wx = cx + radius * math.cos(angle)
                wz = cz + radius * math.sin(angle)
            else
                local lx = bounds.minX + math.random() * (bounds.maxX - bounds.minX)
                local lz = bounds.minZ + math.random() * (bounds.maxZ - bounds.minZ)
                wx, _, wz = localToWorld(bounds.centreNode, lx, 0, lz)
            end
            local ok = true
            for _, p in ipairs(allPlaced) do
                local dx, dz = wx - p[1], wz - p[2]
                if dx * dx + dz * dz < minDist * minDist then ok = false break end
            end
            if ok then return wx, wz end
        end
        return nil, nil
    end

    local function placeInstance(wx, wz, plant)
        local fullPath = modDirectory .. plant.i3dRelPath
        local i3dRoot  = loadI3DFile(fullPath, false, false)
        if i3dRoot == nil or i3dRoot == 0 then
            print("[SPS CrustVeg] failed to load " .. tostring(fullPath))
            return nil
        end
        -- The root node is the first child of i3dRoot
        local plantRoot = getChildAt(i3dRoot, 0)
        if plantRoot == nil or plantRoot == 0 then
            print("[SPS CrustVeg] no root node in " .. tostring(fullPath))
            delete(i3dRoot)
            return nil
        end
        local lx, _, lz = worldToLocal(fillPlaneNode, wx, 0, wz)
        link(fillPlaneNode, plantRoot)
        setTranslation(plantRoot, lx, 0, lz)
        setRotation(plantRoot, 0, math.random() * 2 * math.pi, 0)
        local s = 0.8 + math.random() * 0.4
        setScale(plantRoot, s, s, s)
        setVisibility(plantRoot, false)
        delete(i3dRoot)
        return { rootNode = plantRoot }
    end

    for stage = 1, 3 do
        local pool = byStage[stage]
        if #pool > 0 then
            for _ = 1, poolSize do
                local wx, wz = pickPosition()
                if wx ~= nil then
                    local plant = pool[math.random(1, #pool)]
                    local inst  = placeInstance(wx, wz, plant)
                    if inst ~= nil then
                        table.insert(allPlaced, { wx, wz })
                        table.insert(pEntry.crustInstances[stage], inst)
                    end
                end
            end
        end
    end

    local total = #pEntry.crustInstances[1] + #pEntry.crustInstances[2] + #pEntry.crustInstances[3]
    SlurryDebug.log("[SPS CrustVeg] placed " .. total .. " instances on " .. tostring(pEntry.placeable.configFileName))

    SPSCrustVegetation.updateVisibility(pEntry)
end

-- ---------------------------------------------------------------------------
-- updateVisibility
-- ---------------------------------------------------------------------------
function SPSCrustVegetation.updateVisibility(pEntry)
    if pEntry.crustInstances == nil then return end
    local t = (pEntry.sourceEntry ~= nil and pEntry.sourceEntry.thickness) or 0
    for stage = 1, 3 do
        local visible = t >= SPSCrustVegetation.THRESH[stage]
        for _, inst in ipairs(pEntry.crustInstances[stage]) do
            setVisibility(inst.rootNode, visible)
        end
    end
end

-- ---------------------------------------------------------------------------
-- deleteForPlaceable
-- ---------------------------------------------------------------------------
function SPSCrustVegetation.deleteForPlaceable(pEntry)
    if pEntry.crustInstances == nil then return end
    for stage = 1, 3 do
        for _, inst in ipairs(pEntry.crustInstances[stage]) do
            if inst.rootNode ~= nil and inst.rootNode ~= 0 then
                delete(inst.rootNode)
            end
        end
    end
    pEntry.crustInstances = nil
end