local HumanBackpack = require('bots.FretBots.HumanBackpack')
modifier_ch1_human_backpack = class({})
local M = modifier_ch1_human_backpack

function M:IsHidden() return true end
function M:IsPurgable() return false end
function M:RemoveOnDeath() return false end
function M:AllowIllusionDuplicate() return false end

function M:CheckState()
    if MODIFIER_STATE_CAN_USE_BACKPACK_ITEMS == nil then return {} end
    return {[MODIFIER_STATE_CAN_USE_BACKPACK_ITEMS] = true}
end

function M:OnCreated()
    if not IsServer() then return end
    self.provided = {}
    self:OnIntervalThink()
    if not self:IsNull() then self:StartIntervalThink(0.2) end
end

local function Valid(entity)
    return entity ~= nil and not entity:IsNull()
end

local function HasIntrinsic(hero, item, name)
    for _, modifier in ipairs(hero:FindAllModifiersByName(name)) do
        -- Respect native non-stacking modifiers and effects already supplied by
        -- this exact item. Never take ownership of another item's modifier.
        if modifier:GetAbility() == item
        or bit.band(modifier:GetAttributes(), MODIFIER_ATTRIBUTE_MULTIPLE) == 0 then return true end
    end
    return false
end

function M:OnIntervalThink()
    if not IsServer() then return end
    local hero = self:GetParent()
    if not HumanBackpack.IsEligible(hero) then self:Destroy() return end
    local backpack, main = {}, {}
    for slot = 0, 8 do
        local item = hero:GetItemInSlot(slot)
        if Valid(item) then
            if slot >= 6 then
                if not item:IsMuted() then backpack[item] = true end
            else main[item] = true end
        end
    end

    local changed = false
    for item, modifier in pairs(self.provided) do
        if not backpack[item] or not Valid(modifier) then
            if Valid(modifier) then modifier:Destroy() changed = true end
            self.provided[item] = nil
            -- Moving into a main slot must leave one native intrinsic, rather
            -- than accidentally removing the item's newly active main-slot stats.
            if main[item] and Valid(item) then item:RefreshIntrinsicModifier() end
        end
    end

    for item in pairs(backpack) do
        if self.provided[item] == nil then
            local name = item:GetIntrinsicModifierName()
            if name ~= nil and name ~= '' and not HasIntrinsic(hero, item, name) then
                local modifier = hero:AddNewModifier(hero, item, name, {})
                if Valid(modifier) then self.provided[item] = modifier changed = true end
            end
        end
    end
    if changed then hero:CalculateStatBonus(true) end
end

function M:OnDestroy()
    if not IsServer() then return end
    local hero = self:GetParent()
    for item, modifier in pairs(self.provided or {}) do
        if Valid(modifier) then modifier:Destroy() end
        if Valid(hero) and Valid(item) then
            for slot = 0, 5 do
                if hero:GetItemInSlot(slot) == item then item:RefreshIntrinsicModifier() break end
            end
        end
    end
    self.provided = {}
    if Valid(hero) then hero:CalculateStatBonus(true) end
end
