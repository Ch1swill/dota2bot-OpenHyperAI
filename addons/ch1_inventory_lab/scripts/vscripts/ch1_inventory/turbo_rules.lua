local M={}

function M.EnsureMode()
    local mode=GameRules:GetGameModeEntity()
    if mode~=nil and mode:GetClassname()=='dota_turbo_game_mode' then return mode end

    -- The addon must retain its custom-game client VM for Lua inventory modifiers.
    -- Spawning the native Turbo entity registers it as GameRules' active mode.
    -- Do this before installing filters/thinkers: those belong to this entity.
    local turbo=SpawnEntityFromTableSynchronous('dota_turbo_game_mode',{})
    mode=GameRules:GetGameModeEntity()
    assert(turbo~=nil and mode==turbo and mode:GetClassname()=='dota_turbo_game_mode',
        'Ch1 inventory addon could not initialize native Turbo rules')
    return mode
end

return M
