print('[Ch1InventoryLab] state='..GameRules:State_Get()..' map='..GetMapName())
for id=0,DOTA_MAX_TEAM_PLAYERS-1 do
    if PlayerResource:IsValidPlayerID(id) then
        local hero=PlayerResource:GetSelectedHeroEntity(id)
        local player=PlayerResource:GetPlayer(id)
        print('[Ch1InventoryLab] player='..id..' fake='..tostring(PlayerResource:IsFakeClient(id))
            ..' team='..PlayerResource:GetTeam(id)..' customTeam='..PlayerResource:GetCustomTeamAssignment(id)
            ..' entity='..tostring(player)..' hero='..tostring(hero and hero:GetUnitName())
            ..' modifier='..tostring(hero and hero:HasModifier('modifier_ch1_human_backpack')))
    end
end
