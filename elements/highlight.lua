--[[
-- Highlight element
-- Calls provided function when the unit frame is the target or mouseover
-- By Kesava @ curse.com.
-- All rights reserved.
--]]
local ouf = oUF or oUFKuiEmbed

local function update(self,event,unit)
    if event == 'OnEnter' or event == 'OnLeave' then
        if self.unit ~= unit then return end
    end

    local show

    if  event == 'OnEnter' or
        UnitIsUnit('target',self.unit) or
        MouseIsOver(self)
    then
        show = true
    end

    self.KuiTargetHighlight.func(self,show)
end

local function OnEnter(self)
    update(self,'OnEnter',self.unit)
end

local function OnLeave(self)
    update(self,'OnLeave',self.unit)
end

local function enable(self,unit)
    if not self.KuiTargetHighlight then return end
    if not self.KuiTargetHighlight.func then return end

    -- FIXME PLAYER_TARGET_CHANGED doesn't fire on raid targets
    self:RegisterEvent('PLAYER_TARGET_CHANGED', update)
    self:RegisterEvent('GROUP_ROSTER_UPDATE', update)

    self:HookScript('OnEnter', OnEnter)
    self:HookScript('OnLeave', OnLeave)

    return true
end

ouf:AddElement('KuiTargetHighlight', update, enable)
