local M={modifierName='modifier_ch1_human_backpack'}

function M.IsEligible(hero)
    if hero==nil or hero:IsNull() or not hero:IsRealHero() or hero:IsIllusion() or PlayerResource==nil then return false end
    local id=hero:GetPlayerOwnerID()
    local team=hero:GetTeamNumber()
    return id~=nil and id>=0 and (team==DOTA_TEAM_GOODGUYS or team==DOTA_TEAM_BADGUYS)
        and PlayerResource:IsValidPlayerID(id) and not PlayerResource:IsFakeClient(id)
        and PlayerResource:GetSelectedHeroEntity(id)==hero
end

function M.Apply(hero)
    -- Only the addon entry point may authorize this feature. In a normal bot
    -- lobby the client Lua VM is unavailable and a Lua modifier can crash it.
    if not IsServer() or GameRules==nil or GameRules.Ch1InventoryLabActive~=true then return false end
    if M.IsEligible(hero) and not hero:HasModifier(M.modifierName) then
        local modifier=hero:AddNewModifier(hero,nil,M.modifierName,{})
        return modifier~=nil and not modifier:IsNull()
    end
    return false
end

return M
