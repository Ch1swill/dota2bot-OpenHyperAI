-- Run: lua tests/team_players_regression.lua [bots-directory]
local root = (arg and arg[1]) or 'bots'
local passed, failed = 0, 0
local function test(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1 print('PASS ' .. name)
    else failed = failed + 1 print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function equal(actual, expected)
    assert(table.concat(actual, ',') == table.concat(expected, ','),
        'expected ' .. table.concat(expected, ',') .. ', got ' .. table.concat(actual, ','))
end
local function world()
    local w = {teams = {[2] = {}, [3] = {}}, humans = {}}
    local env = setmetatable({
        TEAM_RADIANT = 2, TEAM_DIRE = 3, CDOTA_Bot_Script = {}, package = {path = ''},
        GetScriptDirectory = function() return 'bots' end,
        require = function(name)
            assert(name == 'bots/FunLib/utils')
            return {DebugMode = false}
        end,
        GetTeamPlayers = function(team)
            local copy = {}
            for i, id in ipairs(w.teams[team] or {}) do copy[i] = id end
            return copy
        end,
        IsPlayerBot = function(id) return not w.humans[id] end,
    }, {__index = _G})
    env._G = env
    local chunk, err
    if setfenv then
        chunk, err = loadfile(root .. '/FunLib/aba_global_overrides.lua')
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(root .. '/FunLib/aba_global_overrides.lua', 't', env)
    end
    assert(chunk, err)
    w.api = chunk()
    return w
end

test('Dire roster refreshes after BotPopulate fills initially empty slots', function()
    local w = world()
    equal(w.api.GetTeamPlayers(3), {})
    w.teams[3] = {5, 6, 7, 8, 9}
    equal(w.api.GetTeamPlayers(3), {5, 6, 7, 8, 9})
end)

test('partially populated Dire roster grows to all five players', function()
    local w = world()
    w.teams[3] = {5, 6}
    equal(w.api.GetTeamPlayers(3), {5, 6})
    w.teams[3] = {5, 6, 7, 8, 9}
    equal(w.api.GetTeamPlayers(3), {5, 6, 7, 8, 9})
end)

test('same-size roster changes preserve current native order', function()
    local w = world()
    w.teams[3] = {5, 6, 7, 8, 9}
    equal(w.api.GetTeamPlayers(3), w.teams[3])
    w.teams[3] = {9, 6, 7, 8, 5}
    equal(w.api.GetTeamPlayers(3), w.teams[3])
end)

test('ordinary-lobby Dire human ID correction and bypass are preserved', function()
    local w = world()
    w.humans[0] = true
    w.teams[3] = {0, 5, 6, 7, 8}
    equal(w.api.GetTeamPlayers(3), {0, 6, 7, 8, 9})
    equal(w.api.GetTeamPlayers(3, true), {0, 5, 6, 7, 8})
    equal(w.teams[3], {0, 5, 6, 7, 8})
end)

test('custom-map human in Dire slot five retains real team IDs', function()
    local w = world()
    w.humans[5] = true
    w.teams[3] = {5, 6, 7, 8, 9}
    equal(w.api.GetTeamPlayers(3), {5, 6, 7, 8, 9})
end)

test('human assignment changes are observed after an initial bot-only roster', function()
    local w = world()
    w.teams[3] = {5, 6, 7, 8, 9}
    equal(w.api.GetTeamPlayers(3), w.teams[3])
    w.humans[0] = true
    w.teams[3] = {0, 5, 6, 7, 8}
    equal(w.api.GetTeamPlayers(3), {0, 6, 7, 8, 9})
end)

test('Radiant roster remains fresh while Dire is queried', function()
    local w = world()
    equal(w.api.GetTeamPlayers(2), {})
    w.api.GetTeamPlayers(3)
    w.teams[2] = {0, 1, 2, 3, 4}
    equal(w.api.GetTeamPlayers(2), w.teams[2])
end)

print(string.format('Team player regression: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
