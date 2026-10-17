-- Run from the repository root: lua tests/fretbots_autostart_regression.lua [game-directory]
local sourceRoot = (arg and arg[1]) or 'game'
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

local function world(options)
    local opts = options or {}
    local w = {phase = opts.phase or 1, listeners = {}, nextId = 0, commands = {}, attempts = 0, logs = {}, settingsLoads = 0, now = 0, thinks = {}, thinkRegistrations = 0}
    w.teams = opts.teams or {[2] = {0, 1}, [3] = {2}}
    w.botIds = opts.botIds or {[1] = true, [2] = true}
    w.settings = opts.settings or {Fretbots = {}}
    local env = setmetatable({
        DOTA_TEAM_GOODGUYS = 2, DOTA_TEAM_BADGUYS = 3,
        DOTA_GAMERULES_STATE_HERO_SELECTION = 3,
        DOTA_GAMERULES_STATE_PRE_GAME = 6,
        DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 7,
        DOTA_GAMERULES_STATE_POST_GAME = 8,
        DOTA_GAMERULES_STATE_DISCONNECT = 9,
        DOTA_GAMERULES_STATE_WAIT_FOR_MAP_TO_LOAD = 10,
        DOTA_GAMERULES_STATE_PLAYER_DRAFT = 12,
        IsServer = function() return not opts.client end,
        IsDedicatedServer = function() return opts.dedicated or false end,
        GetMapName = function() return opts.map or 'dota' end,
        print = function(msg) table.insert(w.logs, msg) end,
    }, {__index = _G})
    env._G = env
    w.env = env
    w.thinkerReady = not opts.noThinker
    w.mode = {SetContextThink = function(_, name, callback, delay)
        w.thinkRegistrations = w.thinkRegistrations + 1
        w.thinks[name] = callback and {callback = callback, at = w.now + delay} or nil
    end}
    w.rules = {
        State_Get = function() return w.phase end,
        -- This is nil in the real standard Dota map, unlike custom games.
        GetGameModeEntity = function() return nil end,
    }
    env.SpawnEntityFromTableSynchronous = function(class, attributes)
        assert(w.phase >= 3, 'Thinker must not spawn during early map initialization')
        assert(class == 'info_target' and attributes.targetname == 'ch1_fretbots_autostart_thinker')
        return w.thinkerReady and w.mode or nil
    end
    env.UTIL_Remove = function(entity) assert(entity == w.mode) w.thinkerRemoved = true end
    w.resource = {
        GetSteamID = function(_, id) return (id == 100 or w.botIds[id]) and '0' or 'human-' .. id end,
        GetPlayerCountForTeam = function(_, team) return #(w.teams[team] or {}) end,
        GetNthPlayerIDOnTeam = function(_, team, index) return w.teams[team][index + 1] end,
    }
    if not opts.noRules then env.GameRules = w.rules end
    if not opts.noResource then env.PlayerResource = w.resource end
    if opts.initialized then env.Flags = {isFretBotsInitialized = true} end
    env.ListenToGameEvent = function(event, callback)
        w.nextId = w.nextId + 1
        w.listeners[w.nextId] = {event = event, callback = callback}
        return w.nextId
    end
    env.StopListeningToGameEvent = function(id) w.listeners[id] = nil end
    env.SendToServerConsole = function(command)
        w.attempts = w.attempts + 1
        if w.failDispatch then error('simulated console failure') end
        table.insert(w.commands, command)
        if w.onDispatch then w.onDispatch() end
    end
    if opts.botVM then
        env.IsServer, env.ListenToGameEvent, env.SendToServerConsole = nil, nil, nil
    end
    local cachedLoader
    env.require = function(name)
        if name == 'game/dkjson' then return {} end
        if name == 'game.ch1_fretbots_autostart' then
            if opts.missingLoader then error('simulated missing loader') end
            if cachedLoader == nil then cachedLoader = loadIn(sourceRoot .. '/ch1_fretbots_autostart.lua', env) end
            return cachedLoader
        end
        if name == 'bots.FunLib.custom_loader' then
            w.settingsLoads = w.settingsLoads + 1
            if opts.invalidSettings then error('simulated invalid customization') end
            return w.settings
        end
        error('Unexpected require: ' .. tostring(name))
    end
    function w:boot() loadIn(sourceRoot .. '/gameinit.lua', env) end
    function w:reloadLoader() loadIn(sourceRoot .. '/ch1_fretbots_autostart.lua', env) end
    function w:emit(event)
        local callbacks = {}
        for _, listener in pairs(self.listeners) do
            if listener.event == event then table.insert(callbacks, listener.callback) end
        end
        for _, callback in ipairs(callbacks) do callback({}) end
    end
    function w:enter(phase) self.phase = phase self:emit('game_rules_state_change') end
    function w:listenerCount()
        local count = 0
        for _ in pairs(self.listeners) do count = count + 1 end
        return count
    end
    function w:advance(seconds)
        local finish = self.now + seconds
        while true do
            local name, think
            for key, candidate in pairs(self.thinks) do
                if candidate.at <= finish and (think == nil or candidate.at < think.at) then name, think = key, candidate end
            end
            if think == nil then break end
            self.now = think.at
            self.thinks[name] = nil
            local interval = think.callback()
            if interval ~= nil then self.thinks[name] = {callback = think.callback, at = self.now + interval} end
        end
        self.now = finish
    end
    return w
end

test('early VM startup waits for GameRules and hero selection', function()
    local w = world({noRules = true})
    w:boot()
    assert(#w.commands == 0 and w:listenerCount() == 2)
    w.env.GameRules = w.rules
    w:enter(2)
    assert(#w.commands == 0 and w.settingsLoads == 0)
    w:enter(3)
    assert(#w.commands == 1)
    assert(w.commands[1] == 'sv_cheats 1; script_reload_code bots/fretbots')
    assert(w:listenerCount() == 0)
end)

test('loading during hero selection starts immediately', function()
    local w = world({phase = 3})
    w:boot()
    assert(#w.commands == 1 and w:listenerCount() == 0)
end)

test('empty player slots wait until bots spawn', function()
    local w = world({phase = 3, teams = {[2] = {0}, [3] = {}}})
    w:boot()
    assert(#w.commands == 0)
    w.teams[3] = {2}
    w:emit('dota_on_hero_finish_spawn')
    assert(#w.commands == 1)
end)

test('missing PlayerResource waits for the next game event', function()
    local w = world({phase = 3, noResource = true})
    w:boot()
    assert(#w.commands == 0)
    w.env.PlayerResource = w.resource
    w:enter(7)
    assert(#w.commands == 1)
end)

test('reloading the module while waiting registers no duplicate listeners', function()
    local w = world()
    w:boot()
    w:reloadLoader()
    assert(w:listenerCount() == 2)
    w:enter(3)
    assert(#w.commands == 1)
end)

test('later events and script reloads never issue a second command', function()
    local w = world({phase = 3})
    w:boot()
    w:enter(7)
    w:emit('dota_on_hero_finish_spawn')
    w:reloadLoader()
    w:boot()
    assert(w.attempts == 1 and w:listenerCount() == 0)
end)

test('reentrant console dispatch is latched before execution', function()
    local w = world()
    w.onDispatch = function() w:reloadLoader() w:emit('dota_on_hero_finish_spawn') end
    w:boot()
    w:enter(3)
    assert(w.attempts == 1)
end)

test('manual FretBots startup suppresses the automatic command', function()
    local w = world({phase = 3, initialized = true})
    w:boot()
    assert(w.attempts == 0 and w:listenerCount() == 0)
end)

test('client VM leaves console and listeners untouched', function()
    local w = world({phase = 3, client = true})
    w:boot()
    assert(w.attempts == 0 and w:listenerCount() == 0)
end)

test('dedicated servers do not run the local command', function()
    local w = world({phase = 3, dedicated = true})
    w:boot()
    assert(w.attempts == 0 and w:listenerCount() == 0)
end)

test('restricted bot VM keeps ordinary gameinit functions', function()
    local w = world({phase = 3, botVM = true})
    w:boot()
    assert(w.attempts == 0 and w:listenerCount() == 0)
    local base = {}
    assert(w.env.HasBaseClass(setmetatable({}, {__index = base}), base))
end)

test('hero demo map skips startup even with bot slots', function()
    local w = world({phase = 3, map = 'hero_demo_main'})
    w:boot()
    assert(w.attempts == 0 and w:listenerCount() == 0)
end)

test('GC-created local lobby host map start runs FretBots', function()
    local w = world({phase = 3, map = 'start'})
    w:boot()
    assert(#w.commands == 1 and w:listenerCount() == 0)
    w:advance(1)
    assert(w.attempts == 1 and w.thinkerRemoved)
end)

test('local lobby waits for hero selection before enabling FretBots', function()
    local w = world({phase = 1, map = 'start'})
    w:boot()
    w:advance(1)
    assert(w.attempts == 0 and not w.env.Ch1FretBotsAutostart.stopped)
    w:enter(3)
    assert(#w.commands == 1)
end)

test('local lobby catches late bot slots on the start host map', function()
    local w = world({phase = 3, map = 'start', teams = {[2] = {0}, [3] = {}}})
    w:boot()
    w:emit('dota_on_hero_finish_spawn')
    w.teams[3] = {2}
    w:advance(0.5)
    assert(#w.commands == 1 and w.thinkerRemoved)
end)

test('human-only game never enables cheats', function()
    local w = world({botIds = {}})
    w:boot()
    w:enter(3)
    w:enter(8)
    w:enter(9)
    assert(w.attempts == 0 and w.settingsLoads == 0 and w:listenerCount() == 0)
end)

test('Auto_Start=false disables this match', function()
    local w = world({phase = 3, settings = {Fretbots = {Auto_Start = false}}})
    w:boot()
    w:enter(7)
    assert(w.attempts == 0 and w:listenerCount() == 0)
end)

test('old customization without Fretbots settings defaults to enabled', function()
    local w = world({phase = 3, settings = {}})
    w:boot()
    assert(#w.commands == 1)
end)

test('invalid customization does not run the command', function()
    local w = world({phase = 3, invalidSettings = true})
    w:boot()
    assert(w.attempts == 0 and w:listenerCount() == 0)
end)

test('console failure retries at the next event without duplicate error logs', function()
    local w = world()
    w.failDispatch = true
    w:boot()
    w:enter(3)
    w:enter(7)
    assert(w.attempts == 2 and #w.commands == 0 and #w.logs == 1)
    w.failDispatch = false
    w:emit('dota_on_hero_finish_spawn')
    assert(w.attempts == 3 and #w.commands == 1 and w:listenerCount() == 0)
end)

test('post-game cancels pending startup and cannot restart', function()
    local w = world({phase = 8})
    w:boot()
    w:enter(3)
    w:reloadLoader()
    assert(w.attempts == 0 and w:listenerCount() == 0)
end)

test('new match with a fresh server VM runs once again', function()
    local first, second = world({phase = 3}), world({phase = 3})
    first:boot()
    second:boot()
    assert(#first.commands == 1 and #second.commands == 1)
end)

test('a missing loader cannot break native gameinit', function()
    local w = world({phase = 3, missingLoader = true})
    w:boot()
    assert(w.attempts == 0 and w:listenerCount() == 0 and #w.logs == 1)
    local base = {}
    assert(w.env.HasBaseClass(base, base))
end)

test('late bot insertion after hero-spawn is detected without another event', function()
    local w = world({phase = 3, teams = {[2] = {0}, [3] = {}}})
    w:boot()
    w:emit('dota_on_hero_finish_spawn')
    assert(w.attempts == 0)
    w.teams[3] = {2}
    w:advance(0.5)
    assert(#w.commands == 1 and w:listenerCount() == 0)
    assert(next(w.thinks) == nil and w.thinkerRemoved)
end)

test('polling waits for native thinker availability', function()
    local w = world({phase = 3, noThinker = true, teams = {[2] = {0}, [3] = {}}})
    w:boot()
    assert(w.thinkRegistrations == 0)
    w.thinkerReady = true
    w:enter(3)
    assert(w.thinkRegistrations == 1)
    w.teams[3] = {2}
    w:advance(1)
    assert(#w.commands == 1)
end)

test('polling notices delayed PlayerResource without a spawn event', function()
    local w = world({phase = 3, noResource = true})
    w:boot()
    w:advance(1)
    assert(w.attempts == 0)
    w.env.PlayerResource = w.resource
    w:advance(0.5)
    assert(#w.commands == 1)
end)

test('polling does not enable cheats before hero selection', function()
    local w = world({phase = 2})
    w:boot()
    w:advance(2)
    assert(w.attempts == 0)
    w:enter(3)
    w:advance(0.5)
    assert(#w.commands == 1)
end)

test('loader reloads while waiting keep only one native think', function()
    local w = world({phase = 3, teams = {[2] = {0}, [3] = {}}})
    w:boot()
    w:reloadLoader()
    w:advance(2)
    w:reloadLoader()
    assert(w.thinkRegistrations == 1)
    w.teams[3] = {2}
    w:advance(5)
    assert(w.attempts == 1 and next(w.thinks) == nil)
end)

test('native map-loading state 10 is not confused with post-game', function()
    local w = world({phase = 10, teams = {[2] = {0}, [3] = {}}})
    w:boot()
    assert(not w.env.Ch1FretBotsAutostart.stopped)
    w.teams[3] = {2}
    w:advance(0.5)
    assert(#w.commands == 1)
end)

test('native player-draft state 12 waits for hero selection', function()
    local w = world({phase = 12})
    w:boot()
    w:advance(1)
    assert(w.attempts == 0 and not w.env.Ch1FretBotsAutostart.stopped)
    w:enter(3)
    w:advance(0.5)
    assert(#w.commands == 1)
end)

test('post-game and disconnect release pending native thinks', function()
    for _, phase in ipairs({8, 9}) do
        local w = world({phase = 3, teams = {[2] = {0}, [3] = {}}})
        w:boot()
        w.phase = phase
        w:advance(1)
        assert(w.attempts == 0 and next(w.thinks) == nil and w:listenerCount() == 0 and w.thinkerRemoved)
    end
end)

test('disabled automatic startup releases its scheduled think', function()
    local w = world({phase = 3, settings = {Fretbots = {Auto_Start = false}}})
    w:boot()
    w:advance(1)
    assert(w.attempts == 0 and next(w.thinks) == nil and w:listenerCount() == 0 and w.thinkerRemoved)
end)

print(string.format('FretBots autostart regression: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
