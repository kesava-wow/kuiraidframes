--[[
-- Raid auras element for oUF.
-- Shows player-cast buffs in KuiSpellList whitelist.
-- Shows dispellable and boss-cast debuffs.
-- By Kesava @ curse.com.
-- All rights reserved.
--]]
-- show forbearance (25771) for paladins
-- show weakened soul (6788) for priests
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

local function ArrangeButtons(self)
    -- sort by time remaining
    table.sort(self.KuiAuras.buttons, function(a,b)
        if a.expiration and b.expiration then
            return a.expiration < b.expiration
        else
            return a.expiration and not b.expiration
        end
    end)

    local prev
    self.KuiAuras.visible = 0

    -- set positions and show in-use buttons
    for spellid,button in pairs(self.KuiAuras.buttons) do
        if button.spellid then
            if self.KuiAuras.visible < 2 then
                self.KuiAuras.visible = self.KuiAuras.visible + 1
                button:ClearAllPoints()

                if not prev then
                    button:SetPoint('TOPLEFT', 1, -1)
                else
                    button:SetPoint('LEFT', prev, 'RIGHT', 1, 0)
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

local function GetButton(self,spellid)
    if self.KuiAuras.spellIds[spellid] then
        -- use current button for this spell id
        return self.KuiAuras.spellIds[spellid]
    end

    -- use hidden button
    for _,button in pairs(self.KuiAuras.buttons) do
        if not button:IsShown() then
            return button
        end
    end

    -- create new button
    local button = CreateFrame('Frame',nil,self.Health)
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

    tinsert(self.KuiAuras.buttons, button)
    return button
end

local function DisplayButton(self,name,icon,spellid,count,duration,expiration)
    local button = GetButton(self,spellid)

    button:SetTexture(icon)
    button.used = true
    button.spellid = spellid

    button:UpdateCooldown(duration,expiration)

    self.KuiAuras.spellIds[spellid] = button
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

        -- show boss debuffs
        for i=1,40 do
            local name,_,icon,_,_,_,_,_,_,_,spellid,_,isBoss,isPlayer = UnitAura(unit, i, 'HARMFUL')
            if not name then break end
            if isBoss then
                print('boss aura: '..name)
            end
        end
    end
end

local function update(self,event,unit)
    if self.unit ~= unit then return end

    GetAuras(self,unit)

    -- unregister and hide buttons which weren't used this update
    for _,button in pairs(self.KuiAuras.buttons) do
        if button:IsShown() and not button.used then
            self.KuiAuras.spellIds[button.spellid] = nil

            button.duration = nil
            button.expiration = nil
            button.spellid = nil

            button:Hide()
        end

        -- set used to nil until they are recalled next update
        button.used = nil
    end

    ArrangeButtons(self)
end
local function enable(self,unit)
    if not self.KuiAuras then return end

    self.KuiAuras.buttons = {}
    self.KuiAuras.spellIds = {}

    --[[
    self.KuiAuras.frames = {
        buffs = {},
        debuffs = {}
    }

    CreateAuraFrame(
        self.KuiAuras,
        'buffs',
        'HELPFUL PLAYER',
        'TOPLEFT'
    )

    -- also have callback for checking spell whitelist

    ]]

    self:RegisterEvent('UNIT_AURA', update)
end

spelllist.RegisterChanged(whitelist, 'WhitelistChanged')

ouf:AddElement('KuiAuras', update, enable, nil)
