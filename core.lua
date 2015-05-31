
local folder,ns=...
local ouf = oUF or oUFKuiEmbed
local kui = LibStub('Kui-1.0')

KuiRaidFrames = {}
local addon = KuiRaidFrames

local texture = 'Interface\\AddOns\\Kui_Media\\t\\bar'
local width,height = 55,35

local INIT_MTT = 1

-- #############################################################################
-- ouf tags ####################################################################
ouf.Tags.Methods['kuiraid:name'] = function(u,r)
    return kui.utf8sub(UnitName(u or r), 0, 6)
end
ouf.Tags.Events['kuiraid:name'] = 'UNIT_NAME_UPDATE'

ouf.Tags.Methods['kuiraid:status'] = function(u,r)
    return (
        ouf.Tags.Methods['offline'](u) or
        ouf.Tags.Methods['dead'](u) or
        ouf.Tags.Methods['missinghp'](u)
    )
end
ouf.Tags.Events['kuiraid:status'] = 'UNIT_MAXHEALTH UNIT_HEALTH_FREQUENT UNIT_CONNECTION'
-- #############################################################################
-- helper functions ############################################################
function addon.CreateFontString(parent, flags)
    flags = flags or {}

    flags[1] = flags[1] or 'Interface\\AddOns\\Kui_Media\\f\\francois.ttf'
    flags[2] = flags[2] or 12
    flags[3] = flags[3] or 'thinoutline'

    local fs = parent:CreateFontString(nil,'OVERLAY')
    fs:SetFont(unpack(flags))
    fs:SetWordWrap(false)
    fs:SetShadowOffset(1,-1)
    fs:SetShadowColor(0,0,0,.5)

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
    sb:SetStatusBarTexture(texture)
    sb:SetPoint('TOPLEFT', 1, -1)
    sb:SetPoint('BOTTOMRIGHT', -1, 1)

    if invert then
        sb:GetStatusBarTexture():SetDrawLayer('BACKGROUND',1)

        sb.invert_fill = sb:CreateTexture(nil, 'BACKGROUND', nil, 0)
        sb.invert_fill:SetTexture(texture)
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
-- spawn functions #############################################################
function addon:SpawnHeader(name, init_func_spec)
    local init_func

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

    return ouf:SpawnHeader(name, nil, 'solo,raid,party',
        'showSolo', true,
        'showPlayer', true,
        'showParty', true,
        'showRaid', true,
        'groupBy', 'ASSIGNEDROLE',
        'groupingOrder', 'TANK,HEALER,DAMAGER,NONE',
        'sortMethod', 'INDEX',
        'sortDir', 'ASC',
        'oUF-initialConfigFunction', (init_func):format(width,height),
        'point', 'TOP',
        'yOffset', -1,
        'xOffset', 1,
        'columnAnchorPoint', 'LEFT',
        'unitsPerColumn', 5,
        'columnSpacing', 1,
        'maxColumns', 8
    )
end

function addon:SpawnTanks()
    local header = self:SpawnHeader('oUF_Kui_Raid_Tanks')

    header:SetAttribute('roleFilter', 'MAINTANK,MAINASSIST,TANK')
    header:SetAttribute('maxColumns', 1)

    header:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', 797, 221)
end

function addon:SpawnTankTargets()
    local header = self:SpawnHeader('oUF_Kui_Raid_Tank_Targets', INIT_MTT)

    header:SetAttribute('roleFilter', 'MAINTANK,MAINASSIST,TANK')
    header:SetAttribute('maxColumns', 1)

    header:SetPoint('TOPRIGHT', oUF_Kui_Raid_Tanks, 'TOPLEFT', -1, 0)
end

function addon:SpawnOthers()
    local header = self:SpawnHeader('oUF_Kui_Raid_Others')

    header:SetAttribute('roleFilter', 'HEALER,DAMAGER,NONE')

    header:SetPoint('TOPLEFT', oUF_Kui_Raid_Tanks, 'TOPRIGHT', 1, 0)
end
-- #############################################################################
-- layout function #############################################################
local function RaidLayout(self, unit)
    self.menu = frame_menu_init
    self:RegisterForClicks('AnyUp')

    self:SetBackdrop({ bgFile = kui.m.t.solid })
    self:SetBackdropColor(0,0,0,.9)

    self.Health = addon.CreateStatusBar(self,nil,true)
    self.Health.frequentUpdates = true
    self.Health.colorDisconnected = true
    self.Health.colorReaction = true
    self.Health.colorTapping = true
    self.Health.colorClass = true
    self.Health.Smooth = true

    self.KuiAbsorb = {
        texture = texture,
        drawLayer = { 'BACKGROUND', 4 },
        colour = { .3, .7, 1 },
        alpha = .3
    }

    self.Range = {
        insideAlpha = 1,
        outsideAlpha = .5,
        Override = function(self,state)
            if state == 'outside' then
                self:SetAlpha(self.Range.outsideAlpha)
                self.name:SetTextColor(.5,.5,.5,.7)
                self.status:SetTextColor(.5,.5,.5,.7)
            else
                self:SetAlpha(self.Range.insideAlpha)
                self.name:SetTextColor(1,1,1,1)
                self.status:SetTextColor(1,1,1,.8)
            end
        end
    }

    do
        local width = 55 - 2

        local myBar = CreateFrame('StatusBar', nil, self.Health)
        myBar:SetStatusBarTexture(texture)
        myBar:GetStatusBarTexture():SetDrawLayer('BACKGROUND',2)
        myBar:SetPoint('TOP')
        myBar:SetPoint('BOTTOM')
        myBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
        myBar:SetStatusBarColor(0,1,.5,.5)
        myBar:SetWidth(width)

        local otherBar = CreateFrame('StatusBar', nil, self.Health)
        otherBar:SetStatusBarTexture(texture)
        otherBar:GetStatusBarTexture():SetDrawLayer('BACKGROUND',3)
        otherBar:SetPoint('TOP')
        otherBar:SetPoint('BOTTOM')
        otherBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
        otherBar:SetStatusBarColor(0,1,0,.5)
        otherBar:SetWidth(width)

        local healAbsorbBar = CreateFrame('StatusBar', nil, self.Health)
        healAbsorbBar:SetStatusBarTexture(texture)
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

    -- text/high frame overlay
    self.overlay = CreateFrame('Frame',nil,self.Health)
    self.overlay:SetAllPoints(self.Health)

    self.name = addon.CreateFontString(self.overlay)
    self.name:SetPoint('CENTER')
    self.name:SetFlag(2,9)
    self:Tag(self.name, '[kuiraid:name]')

    self.status = addon.CreateFontString(self.overlay)
    self.status:SetFlag(2,9)
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
end
-- #############################################################################
-- register with ouf ###########################################################
ouf:RegisterStyle('KuiRaid', RaidLayout)
ouf:Factory(function(self)
    self:SetActiveStyle('KuiRaid')
    addon:SpawnTanks()
    addon:SpawnTankTargets()
    addon:SpawnOthers()
--    addon:SpawnPets()
end)
