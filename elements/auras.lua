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

local function ArrangeButtons(self)
    local prev
    for spellid,button in pairs(self.KuiAuras.buttons) do
        if button:IsShown() then
            button:ClearAllPoints()

            if not prev then
                button:SetPoint('TOPRIGHT', -1, -1)
            else
                button:SetPoint('RIGHT', prev, 'LEFT', -1, 0)
            end

            prev = button
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
    local button = self.Health:CreateTexture(nil, 'BACKGROUND', nil, 7)
    button:SetTexCoord(.1,.9,.1,.9)
    button:SetSize(8,8)

    tinsert(self.KuiAuras.buttons, button)

    return button
end

local function DisplayButton(self,name,icon,spellid)
    local button = GetButton(self,spellid)
    button:SetTexture(icon)
    button:Show()

    button.spellid = spellid
    button.used = true

    self.KuiAuras.spellIds[spellid] = button
end

local function GetAuras(self,unit)
    -- show own cast buffs in whitelist
    if UnitCanAssist('player',unit) then
        for i=1,40 do
            local name,_,icon,_,_,_,_,_,_,_,spellid,_,isBoss,isPlayer = UnitAura(unit, i, 'HELPFUL PLAYER')
            if not name then break end
            if whitelist.list[spellid] then
                DisplayButton(self,name,icon,spellid)
            end
        end
    end

--[[
        -- show dispellable debuffs
        for i=1,40 do
            local name,_,icon,_,_,_,_,_,_,_,spellid,_,isBoss,isPlayer = UnitAura(unit, i, 'HARMFUL RAID')
            if not name then break end
            print('dispel: '..name)
        end
    end

    -- show isBossAura debuffs
    for i=1,40 do
        local name,_,icon,_,_,_,_,_,_,_,spellid,_,isBoss,isPlayer = UnitAura(unit, i, 'HARMFUL')
        if not name then break end
        if isBoss then
            print('boss aura: '..name)
        end
    end
]]
end

local function update(self,event,unit)
    if self.unit ~= unit then return end

    GetAuras(self,unit)

    -- hide buttons which weren't used this update
    for _,button in pairs(self.KuiAuras.buttons) do
        if not button.used then
            self.KuiAuras.spellIds[button.spellid] = nil
            button:Hide()
        end

        button.used = nil
    end

    ArrangeButtons(self)
end
local function enable(self,unit)
    if not self.KuiAuras then return end

    self.KuiAuras.buttons = {}
    self.KuiAuras.spellIds = {}

    self:RegisterEvent('UNIT_AURA', update)
end

spelllist.RegisterChanged(whitelist, 'WhitelistChanged')

ouf:AddElement('KuiAuras', update, enable, nil)
