--[[
-- Raid auras element for oUF.
-- Shows player-cast buffs in KuiSpellList whitelist.
-- Shows dispellable and boss-cast debuffs.
-- By Kesava @ curse.com.
-- All rights reserved.
--]]
local ouf = oUF or oUFKuiEmbed

local spelllist = LibStub('KuiSpellList-1.0')
local whitelist = {}

function whitelist.WhitelistChanged()
    whitelist.list = spelllist.GetImportantSpells(select(2, UnitClass('player')))
end

local button_UpdateCooldown = function(self,duration,expiration)
    if expiration > 0 then
        self.expiration = expiration
        self.cd:SetCooldown(expiration - duration, duration)
    else
        self.expiration = nil
    end
end
local button_SetTexture = function(self,texture)
    self.icon:SetTexture(texture)
end

--[[
local function IsPriorityDebuff(spellid)
    -- forbearance or weakened soul
    return (spellid == 25771 or spellid == 6788)
end
local function GetAuras(self,unit)
    if UnitCanAssist('player',unit) then
        -- show own cast buffs in whitelist
        for i=1,40 do
            local name,_,icon,count,_,duration,expiration,_,_,_,spellid,_,isBoss,isPlayer = UnitAura(unit, i, 'HELPFUL PLAYER')
            if not name then break end
            if  whitelist.list[spellid] and
                ((duration and duration <= 600) or not duration)
            then
                DisplayButton(self,name,icon,spellid,count,duration,expiration)
            end
        end

        -- show dispellable debuffs
        for i=1,40 do
            local name,_,icon,_,_,_,_,_,_,_,spellid,_,isBoss,isPlayer = UnitAura(unit, i, 'HARMFUL RAID')
            if not name then break end
            if isBoss then
                print('boss dispel: '..name)
            else
                print('dispel: '..name)
            end
        end

        -- show boss + priority debuffs
        for i=1,40 do
            local name,_,icon,_,_,_,_,_,_,_,spellid,_,isBoss,isPlayer = UnitAura(unit, i, 'HARMFUL')
            if not name then break end
            if isBoss or IsPriorityDebuff(spellid) then
                print('boss aura: '..name)
            end
        end
    end
end
]]

local function update(self,event,unit)
    if self.unit ~= unit then return end
    for name,frame in pairs(self.KuiAuras.frames) do
        frame.unit = unit
        frame:Update()
    end
end


local function AuraFrame_ArrangeButtons(self)
    -- sort by time remaining
    table.sort(self.buttons, function(a,b)
        if a.expiration and b.expiration then
            return a.expiration < b.expiration
        else
            return a.expiration and not b.expiration
        end
    end)

    local prev
    self.visible = 0

    -- set positions and show in-use buttons
    for _,button in ipairs(self.buttons) do
        if button.spellid then
            if self.visible < 5 then
                self.visible = self.visible + 1
                button:ClearAllPoints()

                if not prev then
                    button:SetPoint(self.point[1], self.x_offset, self.y_offset)
                else
                    button:SetPoint(self.point[2], prev, self.point[3], self.x_spacing, self.y_spacing)
                end

                prev = button
                button:Show()
            else
                -- hide overflow
                button:Hide()
            end
        end
    end
end

local function AuraFrame_GetButton(self)
    if self.spellids[spellid] then
        -- use current button for this spell id
        return self.spellids[spellid]
    end

    -- use unused button
    for _,button in pairs(self.buttons) do
        if not button:IsShown() and not button.spellid then
            return button
        end
    end

    -- create new button
    local button = CreateFrame('Frame',nil,self.frame.Health)
    button:SetSize(8,8)

    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetTexCoord(.1,.9,.1,.9)
    icon:SetAllPoints(button)

    local cd = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
    cd:SetAllPoints(button)
    cd:SetDrawEdge(false)
    cd:SetReverse(true)
    cd:SetHideCountdownNumbers(true)

    button.icon = icon
    button.cd = cd

    button.UpdateCooldown = button_UpdateCooldown
    button.SetTexture = button_SetTexture

    tinsert(self.buttons, button)
    return button
end

local function AuraFrame_DisplayButton(self,name,icon,spellid,count,duration,expiration)
    local button = self:GetButton(spellid)

    button:SetTexture(icon)
    button.used = true
    button.spellid = spellid

    button:UpdateCooldown(duration,expiration)

    self.spellids[spellid] = button
end

local function AuraFrame_Update(self)
    self:GetAuras()

    -- unregister and hide buttons which weren't used this update
    for _,button in pairs(self.buttons) do
        if button.spellid and not button.used then
            self.spellids[button.spellid] = nil

            button.duration = nil
            button.expiration = nil
            button.spellid = nil

            button:Hide()
        end

        -- set used to nil until they are recalled next update
        button.used = nil
    end

    self:ArrangeButtons()
end

local function AuraFrame_GetAuras(self)
    for i=1,40 do
        local name,_,icon,count,_,duration,expiration,_,_,_,spellid,_,isBoss = UnitAura(self.unit, i, self.filter)
        if not name then break end

        if  not self.callback or (self.callback and
            self.callback(name,duration,expiration,spellid,isBoss))
        then
            self:DisplayButton(name,icon,spellid,count,duration,expiration)
        end
    end
end

local function CreateAuraFrame(frame, filter, point)
    return {
        frame = frame,
        buttons = {},
        spellids = {},
        filter = filter,

        point = point,
        x_spacing = 0,
        y_spacing = 0,
        x_offset = 0,
        y_offset = 0,

        Update = AuraFrame_Update,
        GetAuras = AuraFrame_GetAuras,
        GetButton = AuraFrame_GetButton,
        DisplayButton = AuraFrame_DisplayButton,
        ArrangeButtons = AuraFrame_ArrangeButtons
    }
end

local function enable(self,unit)
    if not self.KuiAuras then return end

    self.KuiAuras.frames = {}

    local buffs = CreateAuraFrame(
        self,
        'HELPFUL PLAYER',
        { 'TOPLEFT', 'LEFT', 'RIGHT' }
    )

    local debuffs = CreateAuraFrame(
        self,
        'HARMFUL',
        { 'BOTTOMLEFT', 'LEFT', 'RIGHT' }
    )

    local dispel = CreateAuraFrame(
        self,
        'HARMFUL RAID',
        { 'BOTTOMRIGHT', 'RIGHT', 'LEFT' }
    )

    buffs.callback = function(name,duration,expiration,spellid,isBoss)
        if whitelist.list[spellid] and
           ((duration and duration <= 600) or not duration)
        then
            return true
        end
    end

    debuffs.callback = function(name,duration,expiration,spellid,isBoss)
        return isBoss or (spellid == 25771 or spellid == 6788)
    end

    self.KuiAuras.frames.buffs = buffs
    self.KuiAuras.frames.debuffs = debuffs
    self.KuiAuras.frames.dispel = dispel

    self:RegisterEvent('UNIT_AURA', update)
end

spelllist.RegisterChanged(whitelist, 'WhitelistChanged')

ouf:AddElement('KuiAuras', update, enable, nil)
