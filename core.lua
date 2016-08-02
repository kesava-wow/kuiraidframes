
local folder,ns=...
local kui = LibStub('Kui-1.0')
local ouf = oUF or oUFKuiEmbed

KuiRaidFrames = CreateFrame('Frame',nil,UIParent)
local addon = KuiRaidFrames

local kuiconfig = LibStub('KuiConfig-1.0')
local default_config, config

local player_class, auras_priority_debuff

local spelllist = LibStub('KuiSpellList-1.0')
local whitelist = {}
function whitelist.WhitelistChanged()
    whitelist.list = spelllist.GetImportantSpells(player_class)
end

local sizes = {
    default = { 55,35 },
    target = { 40,35 }
}

local INIT_MTT = 1

-- #############################################################################
-- ouf tags ####################################################################
ouf.Tags.Methods['kuiraid:name'] = function(u,r)
    return strtrim(kui.utf8sub(UnitName(u or r), 0, 6))
end
ouf.Tags.Events['kuiraid:name'] = 'UNIT_NAME_UPDATE'

ouf.Tags.Methods['kuiraid:status'] = function(u,r)
    local offline = not UnitIsConnected(u) and 'offline'
    if offline then return offline end

    local dead = (UnitIsDead(u) and 'dead') or (UnitIsGhost(u) and 'ghost')
    if dead then return dead end

    local m = UnitHealthMax(u)
    local c = UnitHealth(u)

    if c == m or c == 0 or m == 0 then
        return
    elseif UnitIsFriend('player',u) then
        return '-'..kui.num(m-c)
    else
        return string.format('%.1f', c / m * 100)..'%'
    end
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
function addon.CreateStatusBar(parent,parent_frame,invert)
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
-- scripts/hooks ###############################################################
local function KuiTargetHighlightHook(self,show)
    if show then
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
local function RangeHook(self,state)
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
local function ThreatHook(self,event,unit)
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
local function StatusTextUpdateTag(self)
    -- move name when status text is shown/hidden
    self.orig_UpdateTag(self)

    if self:GetText() then
        self.parent.name:SetPoint('LEFT', 0, 6)
        self.parent.name:SetPoint('RIGHT')
        self:SetPoint('CENTER', 0, -6)
    else
        -- neutral position
        self.parent.name:SetPoint('LEFT')
        self.parent.name:SetPoint('RIGHT')
    end
end
local function UnitFrameOnEnter(self,...)
    UnitFrame_OnEnter(self,...)
end
local function UnitFrameOnLeave(self,...)
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

    local header_visibility = 'raid'

    if config.party then
        header_visibility = 'party,'..header_visibility
    end
    if config.debug then
        header_visibility = 'solo,'..header_visibility
    end

    local header = ouf:SpawnHeader(name, nil, header_visibility,
        'showPlayer', true,
        'showRaid', true,
        'groupBy', 'ASSIGNEDROLE',
        'groupingOrder', 'TANK,HEALER,DAMAGER,NONE',
        'sortMethod', 'INDEX',
        'sortDir', 'ASC',
        'oUF-initialConfigFunction', (init_func):format(size[1], size[2]),
        'point', config.growth_anchor,
        'xOffset', config.x_offset,
        'yOffset', config.y_offset,
        'columnAnchorPoint', config.column_anchor,
        'unitsPerColumn', 5,
        'columnSpacing', config.spacing,
        'maxColumns', 8
    )

    if config.party then
        header:SetAttribute('showParty', true)
    end
    if config.debug then
        header:SetAttribute('showSolo', true)
    end

    return header
end

function addon:SpawnTanks()
    local header = self:SpawnHeader('oUF_Kui_Raid_Tanks')

    header:SetAttribute('roleFilter', 'MAINTANK,MAINASSIST,TANK')
    header:SetAttribute('maxColumns', 1)

    -- TODO these points need to be changed depending on column_anchor and growth_anchor
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
        header:SetAttribute('roleFilter', 'MAINTANK,MAINASSIST,TANK,HEALER,DAMAGER,NONE')
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

    self.Threat.Override = ThreatHook

    self.Health = addon.CreateStatusBar(self,nil,true)
    self.Health.frequentUpdates = true
    self.Health.colorDisconnected = true
    self.Health.colorReaction = true
    self.Health.colorTapping = true
    self.Health.colorClass = true
    self.Health.Smooth = true

    self.KuiAbsorb = {
        texture = 'Interface\\AddOns\\Kui_RaidFrames\\media\\stippled-bar',
        tile = true,
        drawLayer = { 'BACKGROUND', 4 },
        colour = { .3, .7, 1 },
        alpha = .5
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
    self:Tag(self.name, '[kuiraid:name]')
    -- positioned by StatusTextUpdateTag

    self.status = addon.CreateFontString(self.overlay)
    self.status:SetFlag(2,config.font_size-1)
    self.status:SetAlpha(.8)
    self:Tag(self.status, '[kuiraid:status]')

    self.status.orig_UpdateTag = self.status.UpdateTag
    self.status.UpdateTag = StatusTextUpdateTag

    self.KuiTargetHighlight = {
        func = KuiTargetHighlightHook
    }

    self.Range = {
        insideAlpha = 1,
        outsideAlpha = .5,
        Override = RangeHook
    }

    if self:GetParent():GetName() ~= 'oUF_Kui_Raid_Tank_Targets' then
        -- friendly-only elements
        self.ResurrectIcon = self.overlay:CreateTexture(nil, 'OVERLAY')
        self.ResurrectIcon:SetPoint('TOPRIGHT', 5, 5)
        self.ResurrectIcon:SetSize(22,22)
        self.ResurrectIcon:Hide()

        self.ReadyCheck = self.overlay:CreateTexture(nil, 'OVERLAY')
        self.ReadyCheck:SetPoint('RIGHT', 5, 0)
        self.ReadyCheck:SetSize(16,16)
        self.ReadyCheck:Hide()

        -- aura frames
        local buffs = {
            filter = 'HELPFUL PLAYER',
            point = { 'TOPLEFT', 'LEFT', 'RIGHT' },
            max = 5,
        }
        buffs.callback = function(name,duration,expiration,spellid)
            if whitelist.list[spellid] and
               ((duration and duration <= 600) or not duration)
            then
                return true
            end
        end

        local debuffs = {
            filter = 'HARMFUL',
            point = { 'BOTTOMLEFT', 'BOTTOMLEFT', 'BOTTOMRIGHT' },
            size = 12,
            max = 3
        }
        debuffs.callback = function(name,duration,expiration,spellid,isBoss)
            return isBoss or (spellid == auras_priority_debuff)
        end
        debuffs.PreShowButton = function(self,button)
            if button.spellid == auras_priority_debuff then
                -- shrink priority debuffs
                button:SetSize(8,8)
            else
                -- enlarge boss debuffs
                button:SetSize(self.size, self.size)
            end
        end
        debuffs.sort = function(a,b)
            if not a.spellid and not b.spellid then
                return
            elseif a.spellid == auras_priority_debuff and b.spellid ~= auras_priority_debuff then
                return
            elseif b.spellid == auras_priority_debuff and a.spellid ~= auras_priority_debuff then
                return true
            else
                -- either both or neither are priority_debuff
                return (a.spellid or 0) < (b.spellid or 0)
            end
        end

        local dispel = {
            filter = 'HARMFUL RAID',
            point = { 'BOTTOMRIGHT', 'RIGHT', 'LEFT' },
            max = 3
        }

        self.KuiAuras = { buffs, debuffs, dispel }
    end
end
-- #############################################################################
-- default config ##############################################################
default_config = {
    texture     = kui.m.t.bar,
    font        = kui.m.f.francois,
    font_size   = 10,
    font_flags  = 'THINOUTLINE',
    font_shadow = true,

    -- my dps position: 741,-820
    x_position = 1100,
    y_position = -250,

    column_anchor = 'LEFT',
    growth_anchor = 'TOP',

    x_offset = 1,
    y_offset = -1,
    spacing = 1,

    seperate_tanks = true,

    party = true,
    debug = false,
}
-- #############################################################################
-- events ######################################################################
function addon:ADDON_LOADED(loaded_addon)
    if loaded_addon ~= folder then return end

    player_class = select(2,UnitClass('player'))

    -- initialise whitelist
    spelllist.RegisterChanged(whitelist, 'WhitelistChanged')
    whitelist.WhitelistChanged()

    -- find priority debuff for auras frame
    if player_class == 'PRIEST' then
        auras_priority_debuff = 6788 -- weakened soul
    elseif player_class == 'PALADIN' then
        auras_priority_debuff = 25771 -- forbearance
    end

    -- initialise config
    addon.config = kuiconfig:Initialise('KuiRaidFrames',default_config)
    config = addon.config:GetConfig()

    -- register with ouf
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
end
addon:SetScript('OnEvent', function(self,event,...)
    self[event](self,...)
end)
addon:RegisterEvent('ADDON_LOADED')
