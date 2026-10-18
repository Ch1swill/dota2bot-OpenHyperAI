-- Server-only support for human heroes using all nine carried item slots.
local M = {}
M.modifierName = 'modifier_ch1_human_backpack'

function M.IsEligible(hero)
    if hero == nil or hero:IsNull() or not hero:IsRealHero() or hero:IsIllusion()
    or PlayerResource == nil then return false end
    local id = hero:GetPlayerOwnerID()
    local team = hero:GetTeamNumber()
    return id ~= nil and id >= 0 and (team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS)
        and PlayerResource:IsValidPlayerID(id) and not PlayerResource:IsFakeClient(id)
        and PlayerResource:GetSelectedHeroEntity(id) == hero
end

function M.Apply(hero)
    if M.IsEligible(hero) and not hero:HasModifier(M.modifierName) then
        hero:AddNewModifier(hero, nil, M.modifierName, {})
    end
end

function M.Start()
    if type(IsServer) ~= 'function' or not IsServer() or GameRules == nil
    or (type(IsDedicatedServer) == 'function' and IsDedicatedServer()) then return end
    if type(GetMapName) == 'function' and GetMapName() ~= 'dota' and GetMapName() ~= 'start' then return end
    if _G.Ch1HumanBackpackStarted then return end
    if MODIFIER_STATE_CAN_USE_BACKPACK_ITEMS == nil then
        print('[OHA.Ch1] Human backpack disabled: this engine has no backpack item state.')
        return
    end
    local ok, customize = pcall(require, 'bots.FunLib.custom_loader')
    if not ok or type(customize) ~= 'table' then
        print('[OHA.Ch1] Human backpack could not load customization.')
        return
    end
    if customize.Enable == false or customize.Human_Backpack_Active == false then return end

    LinkLuaModifier(M.modifierName, 'bots/FretBots/modifiers/modifier_ch1_human_backpack.lua', LUA_MODIFIER_MOTION_NONE)
    require('bots.FretBots.modifiers.modifier_ch1_human_backpack')
    local thinker = SpawnEntityFromTableSynchronous('info_target', {targetname='ch1_human_backpack'})
    if thinker == nil then return end
    _G.Ch1HumanBackpackStarted = true
    -- A spawn event may precede GetSelectedHeroEntity being assigned. Polling also
    -- handles late player heroes and replacement heroes without duplicate effects.
    thinker:SetContextThink('Ch1HumanBackpack', function()
        local state = GameRules:State_Get()
        if state == DOTA_GAMERULES_STATE_POST_GAME or state == DOTA_GAMERULES_STATE_DISCONNECT then
            UTIL_Remove(thinker)
            return nil
        end
        for team = DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS do
            for index = 0, PlayerResource:GetPlayerCountForTeam(team) - 1 do
                local id = PlayerResource:GetNthPlayerIDOnTeam(team, index)
                if id ~= nil and id >= 0 then M.Apply(PlayerResource:GetSelectedHeroEntity(id)) end
            end
        end
        return 0.5
    end, 0)
end

return M
