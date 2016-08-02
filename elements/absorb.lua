--[[
-- Absorb element for oUF.
-- Displays absorbs over the health bar rather than adding to the end like
-- oUF's healprediction element does. Also highlights over-absorbs.
-- By Kesava @ curse.com.
-- All rights reserved.
--]]
local ouf = oUF or oUFKuiEmbed

local function update(self,event,unit)
    if self.unit ~= unit then return end

    local absorbs = UnitGetTotalAbsorbs(unit) or 0

    if absorbs <= 0 then
        self.KuiAbsorb.bar:SetValue(0)
        self.KuiAbsorb.bar:Hide()
        self.KuiAbsorb.spark:Hide()
        return
    else
        self.KuiAbsorb.bar:Show()
    end

    local maxHealth = UnitHealthMax(unit)
    local overAbsorb

    if absorbs > maxHealth then
        overAbsorb = absorbs - maxHealth
        absorbs = maxHealth

        self.KuiAbsorb.spark:Show()
    else
        self.KuiAbsorb.spark:Hide()
    end

    self.KuiAbsorb.bar:SetMinMaxValues(0,maxHealth)
    self.KuiAbsorb.bar:SetValue(absorbs)

    -- re-set the texture after SetValue so that it tiles correctly
    -- (a blizzard thing)
    self.KuiAbsorb.bar:SetStatusBarTexture(self.KuiAbsorb.texture)
end

local function enable(self,unit)
    if not self.KuiAbsorb then return end
    if self.HealPrediction and self.HealPrediction.absorbBar then return end

    local ka = self.KuiAbsorb

    ka.bar = CreateFrame('StatusBar', nil, self.Health)
    ka.bar:SetStatusBarTexture(ka.texture)
    ka.bar:SetStatusBarColor(unpack(ka.colour))
    ka.bar:SetAlpha(ka.alpha)
    ka.bar:SetAllPoints(self.Health)
    ka.bar:SetMinMaxValues(0,1)
    ka.bar:SetValue(0)

    do
        local t = ka.bar:GetStatusBarTexture()
        if t then
            t:SetDrawLayer(unpack(ka.drawLayer))
            t:SetHorizTile(true)
            t:SetVertTile(true)
        end
    end

    ka.spark = self.Health:CreateTexture(nil,'ARTWORK')
    ka.spark:SetTexture('Interface\\AddOns\\Kui_Media\\t\\spark')
    ka.spark:SetDrawLayer(unpack(ka.drawLayer))
    ka.spark:SetPoint('TOP', self.Health, 'TOPRIGHT', -1, 5)
    ka.spark:SetPoint('BOTTOM', self.Health, 'BOTTOMRIGHT', -1, -5)
    ka.spark:SetVertexColor(unpack(ka.colour))
    ka.spark:SetWidth(5)
    ka.spark:Hide()

    self:RegisterEvent('UNIT_MAXHEALTH', update)
    self:RegisterEvent('UNIT_ABSORB_AMOUNT_CHANGED', update)

    return true
end

ouf:AddElement('KuiAbsorb', update, enable)
