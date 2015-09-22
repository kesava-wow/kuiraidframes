--[[
-- Raid auras element for oUF.
-- By Kesava @ curse.com.
-- All rights reserved.
--]]
local ouf = oUF or oUFKuiEmbed
local UnitIsFriend = UnitIsFriend
local kui = LibStub('Kui-1.0')

-- sorts buttons by time remaining ( shorter > longer > timeless )
local time_sort = function(a,b)
    if a.expiration and b.expiration then
        return a.expiration < b.expiration
    else
        return a.expiration and not b.expiration
    end
end

-- #############################################################################
-- button functions ############################################################
local button_UpdateCooldown = function(self,duration,expiration)
    if expiration > 0 then
        self.expiration = expiration
        self.cd:SetCooldown(expiration - duration, duration)
    else
        self.expiration = nil
        self.cd:SetCooldown(0,0)
    end
end
local button_SetTexture = function(self,texture)
    self.icon:SetTexture(texture)
end
local button_UpdateTooltip = function(self)
    GameTooltip:SetUnitAura(self.parent.frame.unit, self.index, self.parent.filter)
end
local button_OnEnter = function(self)
    GameTooltip:SetOwner(self,'ANCHOR_TOPRIGHT')
    self:UpdateTooltip()
end
local button_OnLeave = function()
    GameTooltip:Hide()
end
-- #############################################################################
-- aura frame functions ########################################################
local function AuraFrame_ArrangeButtons(self)
    table.sort(self.buttons, self.sort and self.sort or time_sort)

    local prev
    self.visible = 0

    -- set positions and show in-use buttons
    for _,button in ipairs(self.buttons) do
        if button.spellid then
            if not self.max or self.visible < self.max then
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
                -- hide overflow but keep attached data (spellid, etc)
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
    local button = CreateFrame('Frame',nil,self.parent and self.parent or self.frame.Health)
    button:SetSize(self.size, self.size)

    local icon = button:CreateTexture(nil, 'ARTWORK', nil, 1)
    icon:SetTexCoord(.1,.9,.1,.9)

    if self.bg then
        local bg = button:CreateTexture(nil, 'ARTWORK', nil, 0)
        bg:SetTexture(kui.m.t.solid)
        bg:SetVertexColor(0,0,0,1)

        bg:SetAllPoints(button)
        icon:SetPoint('TOPLEFT',bg,'TOPLEFT',1,-1)
        icon:SetPoint('BOTTOMRIGHT',bg,'BOTTOMRIGHT',-1,1)

        button.bg = bg
    else
        icon:SetAllPoints(button)
    end

    local cd = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
    cd:SetAllPoints(button)
    cd:SetDrawEdge(false)
    cd:SetReverse(true)
    cd:SetHideCountdownNumbers(true)

    button.parent = self
    button.icon = icon
    button.cd = cd

    button.UpdateCooldown = button_UpdateCooldown
    button.SetTexture = button_SetTexture
    button.UpdateTooltip = button_UpdateTooltip

    if self.mouse then
        button:EnableMouse(true)
        button:SetScript('OnEnter', button_OnEnter)
        button:SetScript('OnLeave', button_OnLeave)
    end

    tinsert(self.buttons, button)
    return button
end

local function AuraFrame_DisplayButton(self,name,icon,spellid,count,duration,expiration,index)
    local button = self:GetButton(spellid)

    button:SetTexture(icon)
    button.used = true
    button.spellid = spellid
    button.index = index

    button:UpdateCooldown(duration,expiration)

    if self.PreShowButton then
        self.PreShowButton(self,button)
    end

    self.spellids[spellid] = button
end

local function AuraFrame_HideButton(self,button)
    -- hide a button and nil its data
    if button.spellid then
        self.spellids[button.spellid] = nil
    end

    button.duration = nil
    button.expiration = nil
    button.spellid = nil
    button.index = nil

    button:Hide()
end

local function AuraFrame_Update(self)
    if  (self.only_friends and self.unit_is_friend)
        or not self.only_friends
    then
        -- update auras
        self:GetAuras()

        -- unregister and hide buttons which weren't used this update
        for _,button in pairs(self.buttons) do
            if button.spellid and not button.used then
                self:HideButton(button)
            end

            -- set used to nil until they are called again next update
            button.used = nil
        end

        self:ArrangeButtons()
    else
        if self.visible and self.visible > 0 then
            -- hide all
            for _,button in pairs(self.buttons) do
                self:HideButton(button)
                button.used = nil
            end

            -- force visible count to 0 (usually updated by ArrangeButtons)
            self.visible = 0
        end
    end
end

local function AuraFrame_GetAuras(self)
    for i=1,40 do
        local name,_,icon,count,_,duration,expiration,_,_,_,spellid,_,isBoss = UnitAura(self.unit, i, self.filter)
        if not name then break end

        if  not self.callback or (self.callback and
            self.callback(name,duration,expiration,spellid,isBoss))
        then
            self:DisplayButton(name,icon,spellid,count,duration,expiration,i)
        end
    end
end

-- aura frame metatable
local aura_meta = {
    size = 8,
    x_spacing = 0,
    y_spacing = 0,
    x_offset = 0,
    y_offset = 0,

    Update = AuraFrame_Update,
    GetAuras = AuraFrame_GetAuras,
    GetButton = AuraFrame_GetButton,
    DisplayButton = AuraFrame_DisplayButton,
    HideButton = AuraFrame_HideButton,
    ArrangeButtons = AuraFrame_ArrangeButtons
}
aura_meta.__index = aura_meta

local function CreateAuraFrame(frame, filter, point)
    local auraframe = {}
    setmetatable(auraframe, aura_meta)

    auraframe.frame = frame
    auraframe.filter = filter
    auraframe.point = point
    auraframe.buttons = {}
    auraframe.spellids = {}

    return auraframe
end
-- #############################################################################
-- ouf functions ###############################################################
local function update(self,event,unit)
    if self.unit ~= unit then return end

    for name,frame in pairs(self.KuiAuras.frames) do
        frame.unit_is_friend = UnitIsFriend('player',unit)
        frame.unit = unit
        frame:Update()
    end
end
local function enable(self,unit)
    if not self.KuiAuras then return end

    self.KuiAuras.frames = {}

    for i,frame_def in ipairs(self.KuiAuras) do
        local new_frame = CreateAuraFrame(self)

        for k,v in pairs(frame_def) do
            new_frame[k] = v
        end

        self.KuiAuras.frames[i] = new_frame
        self.KuiAuras[i] = nil
    end

    if #self.KuiAuras.frames > 0 then
        self:RegisterEvent('UNIT_AURA', update)
        return true
    end
end

ouf:AddElement('KuiAuras', update, enable, nil)
