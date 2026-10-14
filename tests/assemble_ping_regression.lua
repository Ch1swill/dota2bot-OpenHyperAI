-- Run from the repository root: lua tests/assemble_ping_regression.lua
local sourceRoot = (arg and arg[1]) or 'bots'
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

local function vector(x, y)
    return {x = x, y = y or 0, z = 0}
end

local function distance(a, b)
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

local function world()
    local w = {now = 100, blocked = false, announcements = 0}
    local bot = {location = vector(0), alive = true}
    function bot:IsInvulnerable() return false end
    function bot:IsHero() return true end
    function bot:IsIllusion() return false end
    function bot:IsBot() return true end
    function bot:IsAlive() return self.alive end
    function bot:GetUnitName() return 'npc_dota_hero_axe' end
    function bot:Action_MoveToLocation(loc) self.destination = loc end
    function bot:GetMostRecentPing() return self.ping end
    local function human()
        return {
            IsBot = function() return false end,
            GetMostRecentPing = function(self) return self.ping end,
        }
    end
    w.bot, w.human, w.otherHuman = bot, human(), human()
    local members = {w.human, w.otherHuman, bot}
    local jmz = {
        CanNotUseAction = function() return w.blocked or not bot.alive end,
        GetHumanPing = function() return w.human, w.human.ping end,
        ModeAnnounce = function() w.announcements = w.announcements + 1 end,
    }
    local env = setmetatable({
        BOT_MODE_DESIRE_NONE = 0,
        BOT_MODE_DESIRE_ABSOLUTE = 1,
        GetBot = function() return bot end,
        GameTime = function() return w.now end,
        GetScriptDirectory = function() return 'bots' end,
        GetTeam = function() return 2 end,
        GetTeamPlayers = function() return {0, 1, 2} end,
        GetTeamMember = function(i) return members[i] end,
        GetUnitToLocationDistance = function(u, loc) return distance(u.location, loc) end,
        require = function() return jmz end,
    }, {__index = _G})
    local path = sourceRoot .. '/mode_assemble_generic.lua'
    if setfenv then
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    else
        assert(loadfile(path, 't', env))()
    end
    function w:ping(loc, member, normal)
        (member or self.human).ping = {time = self.now, location = loc, normal_ping = normal ~= false}
    end
    w.env = env
    return w
end

test('ground ping draws a bot from the opposite side of the map', function()
    local w = world()
    local target = vector(12000, 8000)
    w:ping(target)
    assert(w.env.GetDesire() == 1, 'distant ping lacks absolute priority')
    w.env.Think()
    assert(w.bot.destination == target, 'bot does not move to the distant ping')
end)

test('travel continues after the ping recency window and old timeout', function()
    local w = world()
    local target = vector(12000)
    w:ping(target)
    w.env.GetDesire()
    w.now = w.now + 90
    assert(w.env.GetDesire() == 1, 'long journey expires')
    w.env.Think()
    assert(w.bot.destination == target, 'destination is forgotten during travel')
end)

test('a newer ground ping redirects the journey', function()
    local w = world()
    w:ping(vector(12000))
    w.env.GetDesire()
    w.now = w.now + 20
    local target = vector(-12000)
    w:ping(target)
    assert(w.env.GetDesire() == 1, 'new destination has no priority')
    w.env.Think()
    assert(w.bot.destination == target, 'bot still follows the previous ping')
end)

test('arrival completes the order without rereading the same ping', function()
    local w = world()
    local target = vector(2000)
    w:ping(target)
    w.env.GetDesire()
    w.bot.location = target
    assert(w.env.GetDesire() == 0, 'arrived bot keeps assembling')
    w.bot.location = vector(0)
    w.now = w.now + 1
    assert(w.env.GetDesire() == 0, 'completed ping is treated as a new command')
    assert(w.announcements == 1, 'one command produces repeated announcements')
end)

test('mode interruption preserves the destination', function()
    local w = world()
    local target = vector(2000)
    w:ping(target)
    w.env.GetDesire()
    w.env.OnEnd()
    w.now = w.now + 20
    assert(w.env.GetDesire() == 1, 'temporary mode switch cancels the order')
    w.env.Think()
    assert(w.bot.destination == target, 'bot cannot resume its journey')
end)

test('the most recent allied human ping wins regardless of slot', function()
    local w = world()
    w:ping(vector(2000))
    w.now = w.now + 1
    local target = vector(12000)
    w:ping(target, w.otherHuman)
    assert(w.env.GetDesire() == 1, 'second human is ignored')
    w.env.Think()
    assert(w.bot.destination == target, 'first human slot overrides a newer command')
end)

test('bot pings do not recruit other bots', function()
    local w = world()
    w:ping(vector(2000), w.bot)
    assert(w.env.GetDesire() == 0, 'bot announcement becomes a human command')
end)

test('danger pings do not create assembly orders', function()
    local w = world()
    w:ping(vector(2000), nil, false)
    assert(w.env.GetDesire() == 0, 'warning ping is treated as gather here')
end)

test('unobserved old pings do not create new orders', function()
    local w = world()
    w:ping(vector(2000))
    w.now = w.now + 9
    assert(w.env.GetDesire() == 0, 'stale ping is accepted on first observation')
end)

test('future and zero timestamps are ignored', function()
    local w = world()
    w.human.ping = {time = 0, location = vector(2000), normal_ping = true}
    assert(w.env.GetDesire() == 0, 'empty ping timestamp is accepted')
    w.human.ping.time = w.now + 1
    assert(w.env.GetDesire() == 0, 'future ping timestamp is accepted')
end)

test('an order observed while dead resumes after respawn', function()
    local w = world()
    local target = vector(12000)
    w.bot.alive = false
    w:ping(target)
    assert(w.env.GetDesire() == 0, 'dead bot attempts to move')
    w.now, w.bot.alive = w.now + 30, true
    assert(w.env.GetDesire() == 1, 'respawn loses the recorded destination')
    w.env.Think()
    assert(w.bot.destination == target, 'respawned bot does not follow the order')
end)

test('an inability to act pauses movement without clearing the order', function()
    local w = world()
    local target = vector(12000)
    w:ping(target)
    w.env.GetDesire()
    w.blocked = true
    w.env.Think()
    assert(w.bot.destination == nil, 'movement interrupts an action that cannot be replaced')
    w.now, w.blocked = w.now + 20, false
    assert(w.env.GetDesire() == 1, 'pause cancels the assembly order')
    w.env.Think()
    assert(w.bot.destination == target, 'movement does not resume')
end)

print(string.format('%d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
