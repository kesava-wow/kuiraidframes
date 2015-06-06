--[[
-- Dispel element for oUF.
-- Adds little coloured blocks when the unit has a dispellable debuff.
-- By Kesava @ curse.com.
-- All rights reserved.
--]]
local ouf = oUF or oUFKuiEmbed

local class = select(2,UnitClass('player'))
local types = {
    Magic =   { .2, .6, 1 },
    Curse =   { .6,  0, 1 },
    Disease = { .6, .4, 0 },
    Poison =  {  0, .6, 0 },
}

local ICON_SIZE = 5
local ICON_SPACING = -1

local function CreateBlock(frame)
    local b = CreateFrame('Frame',nil,frame)
    b:SetBackdrop({
        bgFile = 'Interface\\AddOns\\Kui_Media\\t\\solid',
        edgeFile = 'Interface\\AddOns\\Kui_Media\\t\\solid',
        edgeSize = 1,
        insets = { top=1,right=1,bottom=1,left=1 }
    })

    b:SetSize(ICON_SIZE,ICON_SIZE)
    b:SetBackdropBorderColor(0,0,0,1)

    return b
end
local function ArrangeIcons(frame)
    local i,width,prev = 1,0
    for _,b in pairs(frame.KuiDispel.icons) do
        if b:IsShown() then
            if prev then
                b:SetPoint('RIGHT', prev, 'LEFT', -ICON_SPACING, 0)
                width = width + ICON_SIZE + -ICON_SPACING
            else
                b:SetPoint('TOPRIGHT')
                width = width + ICON_SIZE
            end

            prev = b
        end
    end

    frame.KuiDispel.container:SetWidth(width)
end

local function ScanDebuffs(self,unit)
    for i=1,40 do
        local name,_,_,_,d_type = UnitDebuff(unit,i)

        if name and d_type and types[d_type] then
            self.KuiDispel.icons[d_type]:Show()
        end
    end
end

local function UNIT_AURA(self,event,unit)
    if not unit then return end
    if unit ~= self.unit then return end

    -- hide all icons
    for _,b in pairs(self.KuiDispel.icons) do
        b:Hide()
    end

    if UnitIsFriend('player',unit) then
        ScanDebuffs(self,unit)
        ArrangeIcons(self)
    end
end

local function update(self,event,unit)
    UNIT_AURA(self,nil,unit)
end

local function enable(self,unit)
    if not unit then return end

    local con = CreateFrame('Frame', nil, self.Health)
    con:SetHeight(ICON_SIZE)
    con:SetPoint('TOPRIGHT', 1, 1)

    self.KuiDispel = {
        container = con,
        icons = {}
    }

    for d_type,colour in pairs(types) do
        local b = CreateBlock(con)
        b:SetBackdropColor(unpack(colour))

        self.KuiDispel.icons[d_type] = b
    end

    self:RegisterEvent('UNIT_AURA', UNIT_AURA)
    update(self,nil,unit)

    return true
end

ouf:AddElement('KuiDispel', update, enable, nil)
