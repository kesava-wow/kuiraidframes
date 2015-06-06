
local folder,ns=...
local ouf = oUF or oUFKuiEmbed
local kui = LibStub('Kui-1.0')

KuiRaidFrames = CreateFrame('Frame',nil,UIParent)
local addon = KuiRaidFrames
local config = {}

local sizes = {
    default = { 55,35 },
    target = { 35,35 }
}

local INIT_MTT = 1

-- #############################################################################
-- ouf tags ####################################################################
ouf.Tags.Methods['kuiraid:name'] = function(u,r)
    return kui.utf8sub(UnitName(u or r), 0, 6)
end
ouf.Tags.Events['kuiraid:name'] = 'UNIT_NAME_UPDATE'

ouf.Tags.Methods['kuiraid:status'] = function(u,r)
    local offline = not UnitIsConnected(u) and 'offline'
    if offline then return offline end

    local dead = (UnitIsDead(u) and 'dead') or (UnitIsGhost(u) and 'ghost')
    if dead then return dead end

    if not UnitIsFriend('player',u) then
		local m = UnitHealthMax(u)
        local c = UnitHealth(u)
        if c == m or c == 0 or m == 0 then return end
        return string.format('%.1f', UnitHealth(u) / m * 100)..'%'
    end

    local hp = ouf.Tags.Methods['missinghp'](u)
    hp = hp and '-'..kui.num(hp)

    return hp
end
ouf.Tags.Events['kuiraid:status'] = 'UNIT_MAXHEALTH UNIT_HEALTH_FREQUENT UNIT_CONNECTION'
-- #############################################################################
-- helper functions ############################################################
function addon.CreateFontString(parent, flags)
    flags = flags or {}

    flags[1] = flags[1] or config.font
    flags[2] = flags[2] or config.font_size
    flags[3] = flags[3] or config.font_flags

    local fs = parent:CreateFontString(nil,'OVERLAY')
    fs:SetFont(unpack(flags))
    fs:SetWordWrap(false)

    if config.font_shadow then
        fs:SetShadowOffset(1,-1)
        fs:SetShadowColor(0,0,0,.5)
    end

    fs.SetFlag = function(self,flag,val)
        local flags = { self:GetFont() }
        flags[flag] = val
        self:SetFont(unpack(flags))
    end

    return fs
end
function addon.CreateStatusBar(parent, parent_frame, invert)
    parent_frame = parent_frame or parent

    local sb = CreateFrame('StatusBar', nil, parent_frame)
    sb:SetStatusBarTexture(config.texture)
    sb:SetPoint('TOPLEFT', 1, -1)
    sb:SetPoint('BOTTOMRIGHT', -1, 1)

    if invert then
        sb:GetStatusBarTexture():SetDrawLayer('BACKGROUND',1)

        sb.invert_fill = sb:CreateTexture(nil, 'BACKGROUND', nil, 0)
        sb.invert_fill:SetTexture(config.texture)
        sb.invert_fill:SetAllPoints(sb)

        sb.orig_SetStatusBarColor = sb.SetStatusBarColor
        sb.SetStatusBarColor = function(self,r,g,b,a)
            self:orig_SetStatusBarColor(0,0,0,.8)
            self.invert_fill:SetVertexColor(r,g,b,a)
        end
    end

    return sb
end
-- #############################################################################
-- dropdown menu ###############################################################
local frame_menu = CreateFrame('Frame', folder..'UnitMenu', UIParent, 'UIDropDownMenuTemplate')
local function frame_menu_func(frame)
    frame_menu:SetParent(frame)
    return ToggleDropDownMenu(1,nil,frame_menu,'cursor',-3,0)
end
local function frame_menu_init(frame)
    local menu,name,id
    local unit = frame:GetParent().unit

    if not unit then return end

    if UnitIsUnit(unit,'player') then
        menu='frame'
    elseif UnitIsUnit(unit,'vehicle') then
        menu='VEHICLE'
    elseif UnitIsUnit(unit,'pet') then
        menu='PET'
    elseif UnitIsPlayer(unit) then
        id = UnitInRaid(unit)

        if id then
            menu = 'RAID_PLAYER'
        elseif UnitInParty(unit) then
            menu = 'PARTY'
        else
            menu = 'PLAYER'
        end
    else
        menu = 'TARGET'
    end

    if menu then
        UnitPopup_ShowMenu(frame, menu, unit, name, id)
    end
end

UIDropDownMenu_Initialize(frame_menu, frame_menu_init, 'MENU')
-- #############################################################################
-- scripts #####################################################################
local function UpdateHighlight(self,event,...)
    if  event == 'OnEnter' or
        UnitIsUnit('target',self.unit)
    then
        local r,g,b
        if self.Health.invert_fill then
            r,g,b = self.Health.invert_fill:GetVertexColor()
        else
            r,g,b = self.Health:GetStatusBarColor()
        end

        self.overlay:SetBackdropBorderColor(r,g,b,.5)
    else
        self.overlay:SetBackdropBorderColor(0,0,0,0)
    end
end
local function UnitFrameOnEnter(self,...)
    UpdateHighlight(self,'OnEnter')
    UnitFrame_OnEnter(self,...)
end
local function UnitFrameOnLeave(self,...)
    UpdateHighlight(self)
    UnitFrame_OnLeave(self,...)
end
-- #############################################################################
-- spawn functions #############################################################
function addon:SpawnHeader(name, init_func_spec, size)
    local init_func
    size = size or sizes.default

    if init_func_spec == INIT_MTT then
        init_func = [[
            self:SetWidth(%d)
            self:SetHeight(%d)
            self:SetAttribute('unitsuffix', 'target')
        ]]
    else
        init_func = [[
            self:SetWidth(%d)
            self:SetHeight(%d)
        ]]
    end

    local header = ouf:SpawnHeader(name, nil, 'raid,party',
        'showPlayer', true,
        'showParty', true,
        'showRaid', true,
        'groupBy', 'ASSIGNEDROLE',
        'groupingOrder', 'TANK,HEALER,DAMAGER,NONE',
        'sortMethod', 'INDEX',
        'sortDir', 'ASC',
        'oUF-initialConfigFunction', (init_func):format(size[1], size[2]),
        'point', 'TOP',
        'xOffset', config.x_offset,
        'yOffset', config.y_offset,
        'columnAnchorPoint', 'LEFT',
        'unitsPerColumn', 5,
        'columnSpacing', config.spacing,
        'maxColumns', 8
    )

    return header
end

function addon:SpawnTanks()
    local header = self:SpawnHeader('oUF_Kui_Raid_Tanks')

    header:SetAttribute('roleFilter', 'MAINTANK,MAINASSIST,TANK')
    header:SetAttribute('maxColumns', 1)

    header:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', config.x_position, config.y_position)
end

function addon:SpawnTankTargets()
    local header = self:SpawnHeader('oUF_Kui_Raid_Tank_Targets', INIT_MTT, sizes.target)

    header:SetAttribute('roleFilter', 'MAINTANK,MAINASSIST,TANK')
    header:SetAttribute('maxColumns', 1)

    header:SetPoint('TOPRIGHT', oUF_Kui_Raid_Tanks, 'TOPLEFT', -config.spacing, 0)
end

function addon:SpawnOthers()
    local header = self:SpawnHeader('oUF_Kui_Raid_Others')

    if config.seperate_tanks then
        header:SetAttribute('roleFilter', 'HEALER,DAMAGER,NONE')
        header:SetPoint('TOPLEFT', oUF_Kui_Raid_Tanks, 'TOPRIGHT', config.spacing, 0)
    else
        header:SetAttribute('roleFilter', 'MAINTANK,MAINASSIST,HEALER,DAMAGER,NONE')
        header:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', config.x_position, config.y_position)
    end
end
-- #############################################################################
-- layout function #############################################################
local function RaidLayout(self, unit)
    self.menu = frame_menu_init
    self:RegisterForClicks('AnyUp')

    self:SetScript('OnEnter', UnitFrameOnEnter)
    self:SetScript('OnLeave', UnitFrameOnLeave)

    self:SetBackdrop({ bgFile = kui.m.t.solid })
    self:SetBackdropColor(0,0,0,.9)

    self.Threat = CreateFrame('Frame', nil, self)
    self.Threat:SetBackdrop({
        edgeFile = kui.m.t.solid,
        edgeSize = 1
    })
    self.Threat:SetPoint('TOPLEFT', -1, 1)
    self.Threat:SetPoint('BOTTOMRIGHT', 1, -1)
    self.Threat:Hide()

    self.Threat.Override = function(self,event,unit)
        if unit ~= self.unit then return end
        local status = UnitThreatSituation(unit)
        local threat = self.Threat

        local r,g,b
        if status and status > 0 then
            r,g,b = GetThreatStatusColor(status)
            threat:SetBackdropBorderColor(r,g,b,.5)
            threat:Show()
        else
            threat:Hide()
        end
    end

    self.Health = addon.CreateStatusBar(self,nil,true)
    self.Health.frequentUpdates = true
    self.Health.colorDisconnected = true
    self.Health.colorReaction = true
    self.Health.colorTapping = true
    self.Health.colorClass = true
    self.Health.Smooth = true

    self.KuiAbsorb = {
        texture = 'Interface\\AddOns\\Kui_RaidFrames\\media\\stippled-bar',
        drawLayer = { 'BACKGROUND', 4 },
        colour = { .3, .7, 1 },
        alpha = .5
    }

    self.KuiAuras = {}

    self.Range = {
        insideAlpha = 1,
        outsideAlpha = .5,
        Override = function(self,state)
            if state == 'inside' then
                self.Health:SetAlpha(self.Range.insideAlpha)
                self.name:SetTextColor(1,1,1,1)
                self.status:SetTextColor(.8,.8,.8,1)
            else
                self.Health:SetAlpha(self.Range.outsideAlpha)
                self.name:SetTextColor(.5,.5,.5,.7)
                self.status:SetTextColor(.5,.5,.5,.7)
            end
        end
    }

    do
        local width = 55 - 2

        local myBar = CreateFrame('StatusBar', nil, self.Health)
        myBar:SetStatusBarTexture(config.texture)
        myBar:GetStatusBarTexture():SetDrawLayer('BACKGROUND',2)
        myBar:SetPoint('TOP')
        myBar:SetPoint('BOTTOM')
        myBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
        myBar:SetStatusBarColor(0,1,.5,.5)
        myBar:SetWidth(width)

        local otherBar = CreateFrame('StatusBar', nil, self.Health)
        otherBar:SetStatusBarTexture(config.texture)
        otherBar:GetStatusBarTexture():SetDrawLayer('BACKGROUND',3)
        otherBar:SetPoint('TOP')
        otherBar:SetPoint('BOTTOM')
        otherBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
        otherBar:SetStatusBarColor(0,1,0,.5)
        otherBar:SetWidth(width)

        local healAbsorbBar = CreateFrame('StatusBar', nil, self.Health)
        healAbsorbBar:SetStatusBarTexture(config.texture)
        healAbsorbBar:GetStatusBarTexture():SetDrawLayer('BACKGROUND',5)
        healAbsorbBar:SetPoint('TOP')
        healAbsorbBar:SetPoint('BOTTOM')
        healAbsorbBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
        healAbsorbBar:SetStatusBarColor(0,0,0,.5)
        healAbsorbBar:SetWidth(width)

        self.HealPrediction = {
            myBar = myBar,
            otherBar = otherBar,
            healAbsorbBar = healAbsorbBar,
            maxOverflow = 1.05,
            frequentUpdates = true
        }
    end

    -- text/high frame overlay (and highlight border)
    self.overlay = CreateFrame('Frame',nil,self.Health)
    self.overlay:SetAllPoints(self.Health)

    self.overlay:SetBackdrop({
        bgFile = kui.m.t.empty,
        edgeFile = kui.m.t.solid,
        edgeSize = 1
    })
    self.overlay:SetBackdropBorderColor(0,0,0,0)

    self.name = addon.CreateFontString(self.overlay)
    self.name:SetPoint('CENTER')
    self:Tag(self.name, '[kuiraid:name]')

    self.status = addon.CreateFontString(self.overlay)
    self.status:SetFlag(2,config.font_size-1)
    self.status:SetAlpha(.8)
    self:Tag(self.status, '[kuiraid:status]')

    self.status.orig_UpdateTag = self.status.UpdateTag
    self.status.UpdateTag = function(self)
        self.orig_UpdateTag(self)

        if self:GetText() then
            self.parent.name:SetPoint('CENTER', 0, 6)
            self:SetPoint('CENTER', 0, -6)
        else
            self.parent.name:SetPoint('CENTER')
        end
    end

    self:RegisterEvent('PLAYER_TARGET_CHANGED', UpdateHighlight)
    self:RegisterEvent('GROUP_ROSTER_UPDATE', UpdateHighlight)
end
-- #############################################################################
-- default config ##############################################################
local default_config = {
    texture     = kui.m.t.bar,
    font        = kui.m.f.francois,
    font_size   = 10,
    font_flags  = 'THINOUTLINE',
    font_shadow = false,

    x_position = 1100,
    y_position = -250,

    x_offset = 1,
    y_offset = -1,
    spacing = 1,

    seperate_tanks = true,
}
-- #############################################################################
-- events ######################################################################
function addon:ADDON_LOADED(loaded_addon)
    if loaded_addon ~= folder then return end

    if not KuiRaidFramesSavedVariables then
        KuiRaidFramesSavedVariables = {}
    end

    local csv = KuiRaidFramesSavedVariables
    local local_config = {}

    for k,v in pairs(default_config) do
        -- apply default config
        local_config[k] = v
    end

    for k,v in pairs(csv) do
        -- apply saved variables
        local_config[k] = v

        if default_config[k] and v == default_config[k] then
            -- unset varibles which equal the default setting
            csv[k] = nil
        end
    end

    config = local_config
end
addon:SetScript('OnEvent', function(self,event,...)
    self[event](self,...)
end)
addon:RegisterEvent('ADDON_LOADED')
-- #############################################################################
-- register with ouf ###########################################################
ouf:RegisterStyle('KuiRaid', RaidLayout)
ouf:Factory(function(self)
    self:SetActiveStyle('KuiRaid')

    if config.seperate_tanks then
        addon:SpawnTanks()
        addon:SpawnTankTargets()
    end

    addon:SpawnOthers()
--    addon:SpawnPets()
end)
