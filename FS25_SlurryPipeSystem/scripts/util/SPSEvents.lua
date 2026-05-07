-- FS25_SlurryPipeSystem 
-- Author: Oscar Mods 
-- Version: 1.0.0.0

-- SPSEvents.lua
-- FS25_SlurryPipeSystem


-- Safe client send helper. During savegame shutdown/leave-game, g_client or
-- its server connection can already be nil while late SPS cleanup code still
-- asks an event to send. In that state there is nobody left to send to, so
-- silently skip instead of crashing on g_client:getServerConnection().
local function spsSendEventToServer(event)
    if g_client ~= nil and g_client.getServerConnection ~= nil then
        local connection = g_client:getServerConnection()
        if connection ~= nil then
            connection:sendEvent(event)
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- SlurryFlowStateEvent
-- ---------------------------------------------------------------------------
SlurryFlowStateEvent = {}
local SlurryFlowStateEvent_mt = Class(SlurryFlowStateEvent, Event)
InitEventClass(SlurryFlowStateEvent, "SlurryFlowStateEvent")

function SlurryFlowStateEvent.emptyNew()
    local self = Event.new(SlurryFlowStateEvent_mt)
    return self
end

function SlurryFlowStateEvent.new(vehicle, isFlowOpen)
    local self = SlurryFlowStateEvent.emptyNew()
    self.vehicle    = vehicle
    self.isFlowOpen = isFlowOpen
    return self
end

function SlurryFlowStateEvent:readStream(streamId, connection)
    self.vehicle    = NetworkUtil.readNodeObject(streamId)
    self.isFlowOpen = streamReadBool(streamId)
    self:run(connection)
end

function SlurryFlowStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isFlowOpen)
end

function SlurryFlowStateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        if g_slurryPipeManager ~= nil then
            local state = g_slurryPipeManager:getVehicleState(self.vehicle)
            if state ~= nil then
                state.valveOpen = self.isFlowOpen
                g_slurryPipeManager:updateActionEventTexts(self.vehicle)
            end
        end
    end
end

function SlurryFlowStateEvent.sendEvent(vehicle, isFlowOpen, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SlurryFlowStateEvent.new(vehicle, isFlowOpen), nil, nil, vehicle)
            return
        end
        spsSendEventToServer(SlurryFlowStateEvent.new(vehicle, isFlowOpen))
    end
end

-- ---------------------------------------------------------------------------
-- SlurryFlowDirectionEvent
-- ---------------------------------------------------------------------------
SlurryFlowDirectionEvent = {}
local SlurryFlowDirectionEvent_mt = Class(SlurryFlowDirectionEvent, Event)
InitEventClass(SlurryFlowDirectionEvent, "SlurryFlowDirectionEvent")

function SlurryFlowDirectionEvent.emptyNew()
    local self = Event.new(SlurryFlowDirectionEvent_mt)
    return self
end

function SlurryFlowDirectionEvent.new(vehicle, direction)
    local self = SlurryFlowDirectionEvent.emptyNew()
    self.vehicle   = vehicle
    self.direction = direction
    return self
end

function SlurryFlowDirectionEvent:readStream(streamId, connection)
    self.vehicle   = NetworkUtil.readNodeObject(streamId)
    self.direction = streamReadUIntN(streamId, 1)
    self:run(connection)
end

function SlurryFlowDirectionEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.direction, 1)
end

function SlurryFlowDirectionEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        if g_slurryPipeManager ~= nil then
            local state = g_slurryPipeManager:getVehicleState(self.vehicle)
            if state ~= nil then
                state.direction = self.direction
                g_slurryPipeManager:updateActionEventTexts(self.vehicle)
            end
        end
    end
end

function SlurryFlowDirectionEvent.sendEvent(vehicle, direction, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SlurryFlowDirectionEvent.new(vehicle, direction), nil, nil, vehicle)
            return
        end
        spsSendEventToServer(SlurryFlowDirectionEvent.new(vehicle, direction))
    end
end

-- ---------------------------------------------------------------------------
-- SlurryPipeConnectEvent
-- Syncs pipe connection to all clients so they create the visual.
-- targetType: 0 = vehicle, 1 = placeable
-- ---------------------------------------------------------------------------
SlurryPipeConnectEvent = {}
local SlurryPipeConnectEvent_mt = Class(SlurryPipeConnectEvent, Event)
InitEventClass(SlurryPipeConnectEvent, "SlurryPipeConnectEvent")

SlurryPipeConnectEvent.TARGET_TYPE_VEHICLE   = 0
SlurryPipeConnectEvent.TARGET_TYPE_PLACEABLE = 1

function SlurryPipeConnectEvent.emptyNew()
    local self = Event.new(SlurryPipeConnectEvent_mt)
    return self
end

function SlurryPipeConnectEvent.new(vehicleA, targetObject, targetType, couplingIdA, couplingIdB)
    local self = SlurryPipeConnectEvent.emptyNew()
    self.vehicleA     = vehicleA
    self.targetObject = targetObject
    self.targetType   = targetType
    self.couplingIdA  = couplingIdA
    self.couplingIdB  = couplingIdB
    return self
end

function SlurryPipeConnectEvent:readStream(streamId, connection)
    self.vehicleA     = NetworkUtil.readNodeObject(streamId)
    self.targetObject = NetworkUtil.readNodeObject(streamId)
    self.targetType   = streamReadUIntN(streamId, 1)
    self.couplingIdA  = streamReadUIntN(streamId, 4)
    self.couplingIdB  = streamReadUIntN(streamId, 4)
    self:run(connection)
end

function SlurryPipeConnectEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicleA)
    NetworkUtil.writeNodeObject(streamId, self.targetObject)
    streamWriteUIntN(streamId, self.targetType, 1)
    streamWriteUIntN(streamId, self.couplingIdA, 4)
    streamWriteUIntN(streamId, self.couplingIdB, 4)
end

function SlurryPipeConnectEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicleA)
    end
    if g_slurryPipeManager ~= nil then
        g_slurryPipeManager:applyConnect(self.vehicleA, self.targetObject, self.targetType, self.couplingIdA, self.couplingIdB)
    end
end

function SlurryPipeConnectEvent.sendEvent(vehicleA, targetObject, targetType, couplingIdA, couplingIdB, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SlurryPipeConnectEvent.new(vehicleA, targetObject, targetType, couplingIdA, couplingIdB), nil, nil, vehicleA)
            return
        end
        spsSendEventToServer(SlurryPipeConnectEvent.new(vehicleA, targetObject, targetType, couplingIdA, couplingIdB))
    end
end

-- ---------------------------------------------------------------------------
-- SlurryPipeDisconnectEvent
-- ---------------------------------------------------------------------------
SlurryPipeDisconnectEvent = {}
local SlurryPipeDisconnectEvent_mt = Class(SlurryPipeDisconnectEvent, Event)
InitEventClass(SlurryPipeDisconnectEvent, "SlurryPipeDisconnectEvent")

function SlurryPipeDisconnectEvent.emptyNew()
    local self = Event.new(SlurryPipeDisconnectEvent_mt)
    return self
end

function SlurryPipeDisconnectEvent.new(vehicleA, couplingIdA)
    local self = SlurryPipeDisconnectEvent.emptyNew()
    self.vehicleA    = vehicleA
    self.couplingIdA = couplingIdA
    return self
end

function SlurryPipeDisconnectEvent:readStream(streamId, connection)
    self.vehicleA    = NetworkUtil.readNodeObject(streamId)
    self.couplingIdA = streamReadUIntN(streamId, 4)
    self:run(connection)
end

function SlurryPipeDisconnectEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicleA)
    streamWriteUIntN(streamId, self.couplingIdA, 4)
end

function SlurryPipeDisconnectEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicleA)
    end
    if g_slurryPipeManager ~= nil then
        g_slurryPipeManager:applyDisconnect(self.vehicleA, self.couplingIdA)
    end
end

function SlurryPipeDisconnectEvent.sendEvent(vehicleA, couplingIdA, noEventSend)
    if noEventSend == true then return end

    if g_server ~= nil then
        g_server:broadcastEvent(SlurryPipeDisconnectEvent.new(vehicleA, couplingIdA), nil, nil, vehicleA)
        return
    end

    -- During quit/delete the client connection can already be nil.
    if g_client ~= nil and g_client.getServerConnection ~= nil then
        local connection = g_client:getServerConnection()
        if connection ~= nil then
            connection:sendEvent(SlurryPipeDisconnectEvent.new(vehicleA, couplingIdA))
        end
    end
end

-- ---------------------------------------------------------------------------
-- SlurryValveStateEvent
-- Syncs manual coupling valve open/close to all clients.
-- ---------------------------------------------------------------------------
SlurryValveStateEvent = {}
local SlurryValveStateEvent_mt = Class(SlurryValveStateEvent, Event)
InitEventClass(SlurryValveStateEvent, "SlurryValveStateEvent")

function SlurryValveStateEvent.emptyNew()
    local self = Event.new(SlurryValveStateEvent_mt)
    return self
end

-- Accepts either:
--   (vehicleA, couplingObjOrId, isOpen)        — preferred, object form
--   (vehicleA, couplingId, isOpen)             — legacy id form (still works)
-- When given a coupling object, the event also transmits the placeable owner
-- reference (if any) so the receiving machine can scope its lookup to that
-- placeable's storeCouplings — avoiding id collisions across multiple
-- placeables that share coupling ids.
function SlurryValveStateEvent.new(vehicleA, couplingArg, isOpen)
    local self = SlurryValveStateEvent.emptyNew()
    self.vehicleA   = vehicleA
    self.isOpen     = isOpen
    if type(couplingArg) == "table" then
        self.couplingId        = couplingArg.id
        self.placeableOwner    = couplingArg.placeable   -- nil for vehicle/chain couplings
    else
        self.couplingId        = couplingArg
        self.placeableOwner    = nil
    end
    return self
end

function SlurryValveStateEvent:readStream(streamId, connection)
    self.vehicleA       = NetworkUtil.readNodeObject(streamId)
    self.couplingId     = streamReadIntN(streamId, 5)   -- signed: chain start = -2
    self.isOpen         = streamReadBool(streamId)
    local hasOwner      = streamReadBool(streamId)
    if hasOwner then
        self.placeableOwner = NetworkUtil.readNodeObject(streamId)
    else
        self.placeableOwner = nil
    end
    self:run(connection)
end

function SlurryValveStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicleA)
    streamWriteIntN(streamId, self.couplingId or 0, 5)
    streamWriteBool(streamId, self.isOpen)
    streamWriteBool(streamId, self.placeableOwner ~= nil)
    if self.placeableOwner ~= nil then
        NetworkUtil.writeNodeObject(streamId, self.placeableOwner)
    end
end

function SlurryValveStateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicleA)
    end
    if g_slurryPipeManager ~= nil then
        -- If a placeable owner was transmitted, narrow the lookup to that
        -- specific placeable's couplings before falling back to global search.
        local couplingObj = nil
        if self.placeableOwner ~= nil then
            for _, pEntry in ipairs(g_slurryPipeManager.registeredPlaceables) do
                if pEntry.placeable == self.placeableOwner and pEntry.storeCouplings ~= nil then
                    for _, sc in ipairs(pEntry.storeCouplings) do
                        if sc.id == self.couplingId then couplingObj = sc break end
                    end
                    break
                end
            end
        end
        g_slurryPipeManager:applyValveState(self.vehicleA, self.couplingId, self.isOpen, couplingObj)
    end
end

function SlurryValveStateEvent.sendEvent(vehicleA, couplingArg, isOpen, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SlurryValveStateEvent.new(vehicleA, couplingArg, isOpen), nil, nil, vehicleA)
            return
        end
        spsSendEventToServer(SlurryValveStateEvent.new(vehicleA, couplingArg, isOpen))
    end
end
-- ---------------------------------------------------------------------------
-- SPSCouplingDeployEvent
-- Syncs deployable coupling deploy/undeploy to all clients.
-- ---------------------------------------------------------------------------
SPSCouplingDeployEvent = {}
local SPSCouplingDeployEvent_mt = Class(SPSCouplingDeployEvent, Event)
InitEventClass(SPSCouplingDeployEvent, "SPSCouplingDeployEvent")

function SPSCouplingDeployEvent.emptyNew()
    local self = Event.new(SPSCouplingDeployEvent_mt)
    return self
end

function SPSCouplingDeployEvent.new(placeable, couplingId, isDeployed)
    local self = SPSCouplingDeployEvent.emptyNew()
    self.placeable  = placeable
    self.couplingId = couplingId
    self.isDeployed = isDeployed
    return self
end

function SPSCouplingDeployEvent:readStream(streamId, connection)
    self.placeable  = NetworkUtil.readNodeObject(streamId)
    self.couplingId = streamReadUIntN(streamId, 4)
    self.isDeployed = streamReadBool(streamId)
    self:run(connection)
end

function SPSCouplingDeployEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.placeable)
    streamWriteUIntN(streamId, self.couplingId, 4)
    streamWriteBool(streamId, self.isDeployed)
end

function SPSCouplingDeployEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.placeable)
    end
    if g_slurryPipeManager ~= nil then
        g_slurryPipeManager:applyCouplingDeployState(self.placeable, self.couplingId, self.isDeployed)
    end
end

function SPSCouplingDeployEvent.sendEvent(placeable, couplingId, isDeployed, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SPSCouplingDeployEvent.new(placeable, couplingId, isDeployed), nil, nil, placeable)
            return
        end
        spsSendEventToServer(SPSCouplingDeployEvent.new(placeable, couplingId, isDeployed))
    end
end

-- ---------------------------------------------------------------------------
-- SPSSelfPumpStateEvent
-- Syncs selfPowered vehicle pump on/off state to all clients.
-- ---------------------------------------------------------------------------
SPSSelfPumpStateEvent = {}
local SPSSelfPumpStateEvent_mt = Class(SPSSelfPumpStateEvent, Event)
InitEventClass(SPSSelfPumpStateEvent, "SPSSelfPumpStateEvent")

function SPSSelfPumpStateEvent.emptyNew()
    local self = Event.new(SPSSelfPumpStateEvent_mt)
    return self
end

function SPSSelfPumpStateEvent.new(vehicle, pumpRunning)
    local self = SPSSelfPumpStateEvent.emptyNew()
    self.vehicle     = vehicle
    self.pumpRunning = pumpRunning
    return self
end

function SPSSelfPumpStateEvent:readStream(streamId, connection)
    self.vehicle     = NetworkUtil.readNodeObject(streamId)
    self.pumpRunning = streamReadBool(streamId)
    self:run(connection)
end

function SPSSelfPumpStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.pumpRunning)
end

function SPSSelfPumpStateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        if g_slurryPipeManager ~= nil then
            local state = g_slurryPipeManager:getVehicleState(self.vehicle)
            if state ~= nil then
                state.pumpRunning = self.pumpRunning
                g_slurryPipeManager:updateActionEventTexts(self.vehicle)
            end
        end
    end
end

function SPSSelfPumpStateEvent.sendEvent(vehicle, pumpRunning, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SPSSelfPumpStateEvent.new(vehicle, pumpRunning), nil, nil, vehicle)
            return
        end
        spsSendEventToServer(SPSSelfPumpStateEvent.new(vehicle, pumpRunning))
    end
end
-- ---------------------------------------------------------------------------
-- SPSSpreaderValveEvent
-- Syncs spreader valve open/close state to all clients.
-- ---------------------------------------------------------------------------
SPSSpreaderValveEvent = {}
local SPSSpreaderValveEvent_mt = Class(SPSSpreaderValveEvent, Event)
InitEventClass(SPSSpreaderValveEvent, "SPSSpreaderValveEvent")

function SPSSpreaderValveEvent.emptyNew()
    local self = Event.new(SPSSpreaderValveEvent_mt)
    return self
end

function SPSSpreaderValveEvent.new(vehicle, isOpen)
    local self = SPSSpreaderValveEvent.emptyNew()
    self.vehicle = vehicle
    self.isOpen  = isOpen
    return self
end

function SPSSpreaderValveEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isOpen  = streamReadBool(streamId)
    self:run(connection)
end

function SPSSpreaderValveEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isOpen)
end

function SPSSpreaderValveEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        if g_slurryPipeManager ~= nil then
            local state = g_slurryPipeManager:getVehicleState(self.vehicle)
            if state ~= nil then
                state.spreaderValveOpen = self.isOpen
                g_slurryPipeManager:updateActionEventTexts(self.vehicle)
            end
        end
    end
end

function SPSSpreaderValveEvent.sendEvent(vehicle, isOpen, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SPSSpreaderValveEvent.new(vehicle, isOpen), nil, nil, vehicle)
            return
        end
        spsSendEventToServer(SPSSpreaderValveEvent.new(vehicle, isOpen))
    end
end