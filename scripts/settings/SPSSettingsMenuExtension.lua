-- FS25_SlurryPipeSystem 
-- Author: Oscar Mods 
-- Version: 1.0.0.0

-- SPSSettingsMenuExtension.lua
-- FS25_SlurryPipeSystem

SPSSettingsMenuExtension = {}

-- ---------------------------------------------------------------------------
-- onFrameOpen — called once to build UI elements, guarded by initDone flag
-- ---------------------------------------------------------------------------
function SPSSettingsMenuExtension:onFrameOpen()
    if self.sps_initDone then
        return
    end

    -- Build colour name list from manager
    local colorTexts = {}
    if g_slurryPipeManager ~= nil and g_slurryPipeManager.pipeColors ~= nil then
        for _, entry in ipairs(g_slurryPipeManager.pipeColors) do
            table.insert(colorTexts, entry.name)
        end
    end

    if #colorTexts == 0 then
        print("[SPS] SPSSettingsMenuExtension: no colours loaded — deferring")
        return
    end

    -- Section header
    local headerEl = TextElement.new()
    headerEl.name = "sectionHeader"
    headerEl:loadProfile(g_gui:getProfile("fs25_settingsSectionHeader"), true)
    headerEl:setText(g_i18n:getText("sps_settingsHeader"))
    self.gameSettingsLayout:addElement(headerEl)
    headerEl:onGuiSetupFinished()

    -- Slurry Pipe colour row
    self.sps_slurryPipeColorElement = SPSSettingsMenuExtension:_addMultiTextOption(
        self,
        "onSPSSlurryPipeColorChanged",
        colorTexts,
        g_i18n:getText("sps_settingsSlurryPipe"),
        g_i18n:getText("sps_settingsSlurryPipeTooltip")
    )

    self.gameSettingsLayout:invalidateLayout()
    self:updateAlternatingElements(self.gameSettingsLayout)

    self.sps_initDone = true
    SPSSettingsMenuExtension:_updateState(self)
end

-- ---------------------------------------------------------------------------
-- updateGameSettings — called whenever the settings page refreshes
-- ---------------------------------------------------------------------------
function SPSSettingsMenuExtension:updateGameSettings()
    SPSSettingsMenuExtension:_updateState(self)
end

-- ---------------------------------------------------------------------------
-- _updateState — syncs UI element state to manager state
-- ---------------------------------------------------------------------------
function SPSSettingsMenuExtension:_updateState(page)
    if not page.sps_initDone then return end
    if g_slurryPipeManager == nil then return end
    if page.sps_slurryPipeColorElement == nil then return end
    page.sps_slurryPipeColorElement:setState(g_slurryPipeManager.currentPipeColorIndex, false)
end

-- ---------------------------------------------------------------------------
-- Callback — player changed the slurry pipe colour
-- ---------------------------------------------------------------------------
function SPSSettingsMenuExtension:onSPSSlurryPipeColorChanged(state)
    if g_slurryPipeManager == nil then
        print("[SPS] SPSSettingsMenuExtension: manager nil, ignoring")
        return
    end
    g_slurryPipeManager:setCurrentPipeColor(state)
end

-- ---------------------------------------------------------------------------
-- _addMultiTextOption — creates and attaches a MultiTextOptionElement row
-- Mirrors the ELS helper pattern exactly.
-- ---------------------------------------------------------------------------
function SPSSettingsMenuExtension:_addMultiTextOption(frame, callbackName, texts, title, tooltip)
    local container = BitmapElement.new()
    container:loadProfile(g_gui:getProfile("fs25_multiTextOptionContainer"), true)

    local option = MultiTextOptionElement.new()
    option:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOption"), true)
    option.target = SPSSettingsMenuExtension
    option:setCallback("onClickCallback", callbackName)
    option:setTexts(texts)

    local titleEl = TextElement.new()
    titleEl:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOptionTitle"), true)
    titleEl:setText(title)

    local tooltipEl = TextElement.new()
    tooltipEl.name = "ignore"
    tooltipEl:loadProfile(g_gui:getProfile("fs25_multiTextOptionTooltip"), true)
    tooltipEl:setText(tooltip)

    option:addElement(tooltipEl)
    container:addElement(option)
    container:addElement(titleEl)

    option:onGuiSetupFinished()
    titleEl:onGuiSetupFinished()
    tooltipEl:onGuiSetupFinished()

    frame.gameSettingsLayout:addElement(container)
    container:onGuiSetupFinished()

    return option
end

-- ---------------------------------------------------------------------------
-- Hook into InGameMenuSettingsFrame
-- ---------------------------------------------------------------------------
local function init()
    InGameMenuSettingsFrame.onFrameOpen    = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen,    SPSSettingsMenuExtension.onFrameOpen)
    InGameMenuSettingsFrame.updateGameSettings = Utils.appendedFunction(InGameMenuSettingsFrame.updateGameSettings, SPSSettingsMenuExtension.updateGameSettings)
end

init()