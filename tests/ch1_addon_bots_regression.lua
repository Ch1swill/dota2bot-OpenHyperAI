-- Run from the repository root: lua tests/ch1_addon_bots_regression.lua [addon-directory]
local sourceRoot = (arg and arg[1]) or 'addons/ch1_inventory_lab'
local passed, failed = 0, 0

local function test(name, run)
    local ok, err = pcall(run)
    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

local function loadIn(path, env)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, 't', env)
    end
    assert(chunk, err)
    return chunk()
end

local function world(humanTeam)
    local w = {state = 3, cheats = false, slots = {}, commands = {}, logs = {}, fills = 0}
    local env = setmetatable({
        DOTA_TEAM_GOODGUYS = 2, DOTA_TEAM_BADGUYS = 3, DOTA_MAX_TEAM_PLAYERS = 24,
        DOTA_GAMERULES_STATE_HERO_SELECTION = 3, DOTA_GAMERULES_STATE_PRE_GAME = 6,
        DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 7,
        DOTA_GAMERULES_STATE_POST_GAME = 8, DOTA_GAMERULES_STATE_DISCONNECT = 9,
        LUA_MODIFIER_MOTION_NONE = 0,
        IsServer = function() return true end,
        LinkLuaModifier = function() end,
        print = function(message) w.logs[#w.logs + 1] = message end,
        SendToServerConsole = function(command) w.commands[#w.commands + 1] = command end,
    }, {__index = _G})
    w.env = env
    env.GameRules = {
        State_Get = function() return w.state end,
        IsCheatMode = function() return w.cheats end,
        BotPopulate = function() w.fills = w.fills + 1 end,
    }
    for _, method in ipairs({'SetCustomGameTeamMaxPlayers', 'SetIgnoreLobbyTeamsInCustomGame',
        'SetCustomGameSetupTimeout', 'EnableCustomGameSetupAutoLaunch', 'SetHeroSelectionTime',
        'SetCustomGameBansPerTeam', 'SetStrategyTime', 'SetShowcaseTime', 'SetPreGameTime'}) do
        env.GameRules[method] = function() end
    end
    w.mode = {
        GetClassname = function() return w.modeClass or 'dota_base_game_mode' end,
        SetUseDefaultDOTARuneSpawnLogic = function(_, enabled) w.currentRuneRules = enabled end,
        SetFreeCourierModeEnabled = function(_, enabled) w.personalCouriers = enabled end,
        SetBotThinkingEnabled = function(_, enabled) w.thinking = enabled end,
        SetDraftingHeroPickSelectTimeOverride = function() end,
        SetExecuteOrderFilter = function(self, callback, context)
            assert(self==w.mode,'Order filter attached to the replaced base mode')
            w.orderFilter=function(order) return callback(context,order) end
        end,
        SetContextThink = function(self, _, callback)
            assert(self==w.mode,'Thinker attached to the replaced base mode')
            w.tick = callback
        end,
    }
    env.GameRules.GetGameModeEntity = function() return w.mode end
    env.SpawnEntityFromTableSynchronous = function(classname)
        assert(classname=='dota_turbo_game_mode')
        assert(w.tick==nil and w.orderFilter==nil,'Callbacks installed on the replaced mode')
        w.turboSpawns=(w.turboSpawns or 0)+1
        w.modeClass=classname
        local replacement={}
        for name,method in pairs(w.mode) do replacement[name]=method end
        w.mode=replacement
        return w.mode
    end
    env.PlayerResource = {
        IsValidPlayerID = function(_, id) return w.slots[id] ~= nil end,
        IsFakeClient = function(_, id) return w.slots[id].fake end,
        GetTeam = function(_, id) return w.slots[id].team end,
        GetSelectedHeroEntity = function(_, id) return w.slots[id].hero end,
    }
    local backpack = loadIn(sourceRoot .. '/scripts/vscripts/ch1_inventory/human_backpack.lua', env)
    env.require = function(name)
        if name == 'ch1_inventory.human_backpack' then return backpack end
        if name == 'ch1_inventory.bot_control' then
            return loadIn(sourceRoot .. '/scripts/vscripts/ch1_inventory/bot_control.lua', env)
        end
        if name == 'ch1_inventory.turbo_rules' then
            return loadIn(sourceRoot .. '/scripts/vscripts/ch1_inventory/turbo_rules.lua', env)
        end
        error('Unexpected dependency: ' .. name)
    end
    function w:hero(id, options)
        local opts = options or {}
        local hero = {difficulty = opts.difficulty or 0, settings = 0, modifiers = 0}
        hero.IsNull = function() return opts.null or false end
        hero.IsRealHero = function() return not opts.nonHero end
        hero.IsIllusion = function() return opts.illusion or false end
        hero.GetPlayerOwnerID = function() return opts.owner or id end
        hero.GetTeamNumber = function() return opts.team or self.slots[id].team end
        hero.GetUnitName = function() return 'npc_dota_hero_axe' end
        hero.SetBotDifficulty = function(_, difficulty)
            hero.difficulty = difficulty
            hero.settings = hero.settings + 1
        end
        hero.SetControllableByAllPlayers = function(_, enabled) hero.allPlayerControl = enabled end
        hero.SetControllableByPlayer = function(_, owner, skipAdjust)
            hero.controller = owner
            hero.skipAdjust = skipAdjust
        end
        hero.HasModifier = function() return hero.modifiers > 0 end
        hero.AddNewModifier = function()
            hero.modifiers = hero.modifiers + 1
            return {IsNull = function() return false end}
        end
        return hero
    end
    for id = 0, 9 do
        local team = id < 5 and 2 or 3
        local humanId = humanTeam == 3 and 5 or 0
        w.slots[id] = {team = team, fake = id ~= humanId}
        w.slots[id].hero = w:hero(id, {difficulty = team == 2 and 4 or 0})
    end
    function w:boot()
        loadIn(sourceRoot .. '/scripts/vscripts/addon_game_mode.lua', env)
        env.Activate()
    end
    return w
end

test('native Turbo is initialized before filters and thinkers and reused on reload', function()
    local w=world(2)
    w:boot()
    assert(w.modeClass=='dota_turbo_game_mode' and w.turboSpawns==1)
    w.env.Activate()
    assert(w.turboSpawns==1,'Reload replaced a configured Turbo entity')
    assert(w.thinking and type(w.orderFilter)=='function' and type(w.tick)=='function')
end)

test('a failed native Turbo registration stops setup before bot or inventory changes', function()
    local w=world(2)
    w.env.SpawnEntityFromTableSynchronous=function() return {} end
    local ok=pcall(function() w:boot() end)
    assert(not ok and w.tick==nil and w.orderFilter==nil and #w.commands==0)
end)

test('current official rune rules and personal couriers are enabled before bot filling', function()
    local w = world(2)
    w:boot()
    assert(w.currentRuneRules == true and w.personalCouriers == true)
    assert(w.fills == 0, 'Roster filled before rules were configured')
end)

test('enemy passive bots receive combat difficulty while allied bots stay unfair', function()
    local w = world(2)
    w:boot()
    w.state = 6
    w.tick()
    for id = 1, 9 do
        assert(w.slots[id].hero.difficulty == 4, 'Bot ' .. id .. ' still has passive/different difficulty')
    end
    assert(w.thinking == true)
end)

test('both teams are configured when the human selects Dire', function()
    local w = world(3)
    w:boot()
    w.state = 7
    w.tick()
    for id = 0, 9 do
        if id ~= 5 then assert(w.slots[id].hero.difficulty == 4, 'Bot ' .. id) end
    end
    assert(w.slots[5].hero.settings == 0)
end)

test('human gets nine slots and bots never get the human modifier', function()
    local w = world(2)
    w:boot()
    w.state = 6
    w.tick()
    assert(w.slots[0].hero.settings == 0)
    assert(w.slots[0].hero.modifiers == 1)
    for id = 1, 9 do assert(w.slots[id].hero.modifiers == 0, 'Bot ' .. id .. ' got nine slots') end
end)

test('both teams retain their own bot controllers without all-player control', function()
    for _,humanTeam in ipairs({2,3}) do
        local w=world(humanTeam)
        w:boot()
        w.state=7
        w.tick()
        assert(type(w.orderFilter)=='function', 'Missing server-side order protection')
        for id=0,9 do
            local hero=w.slots[id].hero
            if w.slots[id].fake then
                assert(hero.allPlayerControl==false and hero.controller==id and hero.skipAdjust==true)
            else
                assert(hero.allPlayerControl==nil and hero.controller==nil, 'Human control changed')
            end
        end
    end
end)

test('late heroes and late player slots are initialized after roster filling', function()
    local w = world(2)
    w.slots[9].hero = nil
    w.slots[8] = nil
    w:boot()
    w.state = 7
    w.tick()
    w.slots[9].hero = w:hero(9)
    w.slots[8] = {team = 3, fake = true}
    w.slots[8].hero = w:hero(8)
    w.tick()
    assert(w.slots[8].hero.difficulty == 4 and w.slots[9].hero.difficulty == 4)
end)

test('hero handle replacement is configured but repeated ticks do not reset AI', function()
    local w = world(2)
    w:boot()
    w.state = 7
    w.tick()
    w.tick()
    assert(w.slots[9].hero.settings == 1)
    w.slots[9].hero = w:hero(9)
    w.tick()
    assert(w.slots[9].hero.settings == 1 and w.slots[9].hero.difficulty == 4)
end)

test('spectators, invalid handles, illusions and mismatched owners/teams are excluded', function()
    local w = world(2)
    w.slots[9].team = 1
    w.slots[8].hero = w:hero(8, {null = true})
    w.slots[7].hero = w:hero(7, {illusion = true})
    w.slots[6].hero = w:hero(6, {nonHero = true})
    w.slots[5].hero = w:hero(5, {owner = 0})
    w.slots[4].hero = w:hero(4, {team = 3})
    w:boot()
    w.state = 7
    w.tick()
    for id = 4, 9 do assert(w.slots[id].hero.settings == 0, 'Invalid hero ' .. id .. ' changed') end
end)

test('cheat mode must be available before filling and a full roster is not refilled', function()
    local w = world(2)
    for id = 0, 9 do w.slots[id].hero = nil end
    w:boot()
    w.tick()
    assert(w.fills == 0)
    w.cheats = true
    w.tick()
    w.tick()
    assert(w.fills == 1)
    assert(#w.commands == 1 and w.commands[1] == 'sv_cheats 1', 'Unexpected console/configuration command')
end)

test('postgame and disconnect stop the addon before changing heroes', function()
    for _, phase in ipairs({8, 9}) do
        local w = world(2)
        w:boot()
        w.state = phase
        assert(w.tick() == nil and w.env.GameRules.Ch1InventoryLabActive == false)
        for id = 0, 9 do
            assert(w.slots[id].hero.settings == 0 and w.slots[id].hero.modifiers == 0)
        end
    end
end)

print(string.format('Ch1 addon bot regression: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
