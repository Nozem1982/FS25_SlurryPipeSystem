-- FS25_SlurryPipeSystem 
-- Author: Oscar Mods 
-- Version: 1.0.0.0

-- ManureBarrelOverride.lua
-- FS25_SlurryPipeSystem
--
-- Overrides applied to manureBarrel and manureTrailer vehicle types.

SlurryPipeSystemOverride = {}

-- ---------------------------------------------------------------------------
-- isPTOConnected / isHydraulicsConnected
-- Uses MA's own vehicle methods when present.
-- Both return true when the vehicle has no such connection type,
-- so vanilla (no MA loaded) always passes through unchanged.
-- ---------------------------------------------------------------------------
function SlurryPipeSystemOverride.isPTOConnected(vehicle)
    if vehicle.isPtoAttached ~= nil then
        return vehicle:isPtoAttached()
    end
    return true
end

function SlurryPipeSystemOverride.isHydraulicsConnected(vehicle)
    if vehicle.isHoseAttached ~= nil then
        return vehicle:isHoseAttached()
    end
    return true
end

-- Applied to non-tanker implements (sprayer, fertilizingCultivator etc.) that are
-- attached to an SPS registered vehicle. Blocks their own discharge unless the
-- SPS spreader valve is open AND pump is running.
-- Applied to all vehicle types with WorkArea spec.
-- When attached to an SPS registered tanker, spreading is only allowed when
-- the tanker pump is running AND the spreader valve is open.
function SlurryPipeSystemOverride.getIsWorkAreaActiveAttached(self, superFunc, workArea)
    if g_slurryPipeManager ~= nil and self.getAttacherVehicle ~= nil then
        local attacher = self:getAttacherVehicle()
        if attacher ~= nil and g_slurryPipeManager:isRegistered(attacher) then
            local state = g_slurryPipeManager:getVehicleState(attacher)
            if state ~= nil then
                local allowed = state.pumpRunning and state.spreaderValveOpen == true
                if self._spsWorkAreaActive ~= allowed then
                    print("[SPS WORKAREA ATTACHED] getIsWorkAreaActiveAttached -> " .. tostring(allowed) .. " pumpRunning=" .. tostring(state.pumpRunning) .. " spreaderValveOpen=" .. tostring(state.spreaderValveOpen) .. " vehicle=" .. tostring(self.configFileName))
                    self._spsWorkAreaActive = allowed
                end
                if not allowed then
                    return false
                end
            end
        end
    end
    return superFunc(self, workArea)
end

-- Same override for manureBarrel/manureTrailer types that have their own built-in
-- sprayer (e.g. Cobra) — checks the vehicle's own SPS state.
function SlurryPipeSystemOverride.getIsWorkAreaActiveSelf(self, superFunc, workArea)
    if g_slurryPipeManager ~= nil and g_slurryPipeManager:isRegistered(self) then
        local state = g_slurryPipeManager:getVehicleState(self)
        if state ~= nil then
            local allowed = state.pumpRunning and state.spreaderValveOpen == true
            if self._spsWorkAreaActive ~= allowed then
                print("[SPS WORKAREA SELF] getIsWorkAreaActiveSelf -> " .. tostring(allowed) .. " pumpRunning=" .. tostring(state.pumpRunning) .. " spreaderValveOpen=" .. tostring(state.spreaderValveOpen) .. " vehicle=" .. tostring(self.configFileName))
                self._spsWorkAreaActive = allowed
            end
            if not allowed then
                return false
            end
        end
    end
    return superFunc(self, workArea)
end

function SlurryPipeSystemOverride.getIsDischargeNodeActiveAttached(self, superFunc, dischargeNode)
    if g_slurryPipeManager ~= nil and self.getAttacherVehicle ~= nil then
        local attacher = self:getAttacherVehicle()
        if attacher ~= nil and g_slurryPipeManager:isRegistered(attacher) then
            local state = g_slurryPipeManager:getVehicleState(attacher)
            if state ~= nil then
                local active = state.pumpRunning and state.spreaderValveOpen == true
                if self._spsAttachedDischargeActive ~= active then
                    print("[SPS ATTACHED DISCHARGE] getIsDischargeNodeActiveAttached -> " .. tostring(active) .. " pumpRunning=" .. tostring(state.pumpRunning) .. " spreaderValveOpen=" .. tostring(state.spreaderValveOpen) .. " vehicle=" .. tostring(self.configFileName))
                    self._spsAttachedDischargeActive = active
                end
                if not active then
                    return false
                end
            end
        end
    end
    return superFunc(self, dischargeNode)
end

function SlurryPipeSystemOverride.getCanToggleDischargeToGround(self, superFunc)
    if g_slurryPipeManager ~= nil and g_slurryPipeManager:isRegistered(self) then
        return false
    end
    return superFunc(self)
end

function SlurryPipeSystemOverride.getCanToggleDischargeToObject(self, superFunc)
    if g_slurryPipeManager ~= nil and g_slurryPipeManager:isRegistered(self) then
        return false
    end
    return superFunc(self)
end


function SlurryPipeSystemOverride.getAllowLoadTriggerActivation(self, superFunc, rootVehicle)
    if g_slurryPipeManager ~= nil and g_slurryPipeManager:isRegistered(self) then
        return false
    end
    return superFunc(self, rootVehicle)
end

function SlurryPipeSystemOverride.getDrawFirstFillText(self, superFunc)
    if g_slurryPipeManager ~= nil and g_slurryPipeManager:isRegistered(self) then
        return false
    end
    return superFunc(self)
end

function SlurryPipeSystemOverride.getCanToggleTurnedOn(self, superFunc)
    if g_slurryPipeManager ~= nil then
        -- Block I key on the SPS tanker itself
        if g_slurryPipeManager:isRegistered(self) then
            return false
        end
        -- Block I key on attached spreader implements when tanker pump is running
        if self.getAttacherVehicle ~= nil then
            local attacher = self:getAttacherVehicle()
            if attacher ~= nil and g_slurryPipeManager:isRegistered(attacher) then
                return false
            end
        end
    end
    return superFunc(self)
end

function SlurryPipeSystemOverride.getIsDischargeNodeActive(self, superFunc, dischargeNode)
    if g_slurryPipeManager == nil or not g_slurryPipeManager:isRegistered(self) then
        return superFunc(self, dischargeNode)
    end
    local state = g_slurryPipeManager:getVehicleState(self)
    if state == nil then return false end
    local pumpOn
    if g_slurryPipeManager:isVehicleSelfPowered(self) or g_slurryPipeManager:vehicleHasSpreader(self) then
        pumpOn = state.pumpRunning == true
    else
        pumpOn = self.getIsTurnedOn ~= nil and self:getIsTurnedOn() or false
    end
    local active = pumpOn and state.spreaderValveOpen == true
    if self._spsDischargeActive ~= active then
        print("[SPS DISCHARGE] getIsDischargeNodeActive -> " .. tostring(active) .. " pumpOn=" .. tostring(pumpOn) .. " spreaderValveOpen=" .. tostring(state.spreaderValveOpen))
        self._spsDischargeActive = active
    end
    return active
end

function SlurryPipeSystemOverride.setIsTurnedOn(self, superFunc, isTurnedOn, noEventSend)
    if g_slurryPipeManager ~= nil and g_slurryPipeManager:isRegistered(self) then
        if g_slurryPipeManager:vehicleHasSpreader(self) then
            local state = g_slurryPipeManager:getVehicleState(self)
            if state ~= nil then
                -- SPS always sets state.pumpRunning before calling setIsTurnedOn.
                -- If the requested value doesn't match pumpRunning, this is an
                -- external call (spreader lower/raise, fold cascade) — block it.
                if isTurnedOn ~= state.pumpRunning then
                    -- Resync HUD to reflect true pump state
                    g_slurryPipeManager:updateActionEventTexts(self)
                    print("[SPS PUMP] setIsTurnedOn(" .. tostring(isTurnedOn) .. ") blocked — pumpRunning=" .. tostring(state.pumpRunning))
                    return
                end
            end
        end
    end
    superFunc(self, isTurnedOn, noEventSend)
end

function SlurryPipeSystemOverride.getCanBeTurnedOn(self, superFunc)
    if g_slurryPipeManager ~= nil then
        if g_slurryPipeManager:isRegistered(self) then
            -- selfPowered vehicles have their own power supply — always allow
            if g_slurryPipeManager:isVehicleSelfPowered(self) then
                return true
            end
            -- Motor must be running
            local root = self:getRootVehicle()
            if root ~= nil and root.getIsMotorStarted ~= nil then
                if not root:getIsMotorStarted() then
                    return false
                end
            end
            -- PTO must be connected (MA: isPtoAttached, vanilla: always true)
            if not SlurryPipeSystemOverride.isPTOConnected(self) then
                return false
            end
            return true
        end
        -- Non-registered vehicle (spreader implement): if attached to SPS vehicle
        -- with pump running, return true to prevent turnOffIfNotAllowed cascade
        if self.getAttacherVehicle ~= nil then
            local attacher = self:getAttacherVehicle()
            if attacher ~= nil and g_slurryPipeManager:isRegistered(attacher) then
                local state = g_slurryPipeManager:getVehicleState(attacher)
                if state ~= nil and state.pumpRunning then
                    return true
                end
            end
        end
    end
    return superFunc(self)
end