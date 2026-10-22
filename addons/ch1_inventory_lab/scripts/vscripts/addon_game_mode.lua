-- This entry point is mounted only by dota_launch_custom_game ch1_inventory_lab dota.
-- Never require it from the ordinary bots/FretBots.lua startup path.
LinkLuaModifier('modifier_ch1_human_backpack', 'ch1_inventory/modifier_human_backpack.lua', LUA_MODIFIER_MOTION_NONE)

function Precache(context)
    PrecacheUnitByNameSync('npc_dota_hero_axe', context)
end

function Activate()
    print('[Ch1InventoryLab] addon activated')
    GameRules.Ch1InventoryLabActive=true
    -- BotPopulate is a no-op without cheat mode, even in a local custom game.
    -- Enable it here so a fresh desktop launch does not depend on a console command.
    SendToServerConsole('sv_cheats 1')
    local backpack=require('ch1_inventory.human_backpack')
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 5)
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 5)
    GameRules:SetIgnoreLobbyTeamsInCustomGame(false)
    GameRules:SetCustomGameSetupTimeout(-1)
    GameRules:EnableCustomGameSetupAutoLaunch(false)
    GameRules:SetHeroSelectionTime(60)
    GameRules:SetCustomGameBansPerTeam(0)
    GameRules:SetStrategyTime(0)
    GameRules:SetShowcaseTime(0)
    GameRules:SetPreGameTime(90)
    local mode=GameRules:GetGameModeEntity()
    -- Custom games otherwise use legacy rune spawns and no personal couriers.
    -- Opt into the installed game's current rules before any heroes spawn.
    mode:SetUseDefaultDOTARuneSpawnLogic(true)
    mode:SetFreeCourierModeEnabled(true)
    mode:SetBotThinkingEnabled(true)
    mode:SetDraftingHeroPickSelectTimeOverride(60)
    local botsPopulated=false
    local configuredBotHeroes={}
    mode:SetContextThink('Ch1InventoryLab',function()
        local state=GameRules:State_Get()
        if state==DOTA_GAMERULES_STATE_POST_GAME or state==DOTA_GAMERULES_STATE_DISCONNECT then
            GameRules.Ch1InventoryLabActive=false
            return nil
        end
        if state==DOTA_GAMERULES_STATE_HERO_SELECTION and not botsPopulated then
            if GameRules:IsCheatMode() then
                GameRules:BotPopulate()
                local players=0
                for id=0,DOTA_MAX_TEAM_PLAYERS-1 do
                    if PlayerResource:IsValidPlayerID(id) then
                        local team=PlayerResource:GetTeam(id)
                        if team==DOTA_TEAM_GOODGUYS or team==DOTA_TEAM_BADGUYS then players=players+1 end
                    end
                end
                botsPopulated=players>=10
                if botsPopulated then print('[Ch1InventoryLab] filled both teams: '..players..' players') end
            end
        end
        for id=0,DOTA_MAX_TEAM_PLAYERS-1 do
            if PlayerResource:IsValidPlayerID(id) then
                local hero=PlayerResource:GetSelectedHeroEntity(id)
                if PlayerResource:IsFakeClient(id) then
                    local team=PlayerResource:GetTeam(id)
                    if (team==DOTA_TEAM_GOODGUYS or team==DOTA_TEAM_BADGUYS)
                        and hero~=nil and not hero:IsNull() and hero:IsRealHero() and not hero:IsIllusion()
                        and hero:GetPlayerOwnerID()==id and hero:GetTeamNumber()==team
                        and configuredBotHeroes[id]~=hero then
                        -- Do not rely on the lobby difficulties inherited by BotPopulate.
                        -- Valve's tutorial_assist_game uses this hero API: 0 is passive,
                        -- 4 is unfair. Set both teams explicitly, independent of lobby defaults
                        -- and FretBots' separate bonus scale. Wait for each real hero to exist.
                        hero:SetBotDifficulty(4)
                        configuredBotHeroes[id]=hero
                        print('[Ch1InventoryLab] bot AI ready player='..id..' team='..team..' difficulty=4')
                    end
                elseif backpack.Apply(hero) then
                    print('[Ch1InventoryLab] human modifier applied player='..id..' hero='..hero:GetUnitName())
                end
            end
        end
        return 0.5
    end,0.5)
end
