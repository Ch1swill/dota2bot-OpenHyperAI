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
    local w = {now = 100, blocked = false, announcements = 0, units = {}, towers = {[2] = {}, [3] = {}}, pit = vector(-9000, -9000), visible = false}
    local bot = {location = vector(0), alive = true, mode = 14}
    function bot:IsInvulnerable() return false end
    function bot:IsHero() return true end
    function bot:IsIllusion() return false end
    function bot:IsBot() return true end
    function bot:IsAlive() return self.alive end
    function bot:IsNull() return false end
    function bot:HasModifier() return false end
    function bot:CanBeSeen() return true end
    function bot:GetLocation() return self.location end
    function bot:GetTeam() return 2 end
    function bot:GetActiveMode() return self.mode end
    function bot:GetPlayerID() return 2 end
    function bot:GetTarget() return self.target end
    function bot:GetAttackTarget() return self.attackTarget end
    function bot:SetTarget(target) self.target = target end
    function bot:GetNearbyHeroes(radius)
        local units = {}
        for _, unit in ipairs(w.units[5] or {}) do
            if unit.alive and unit.seen and distance(unit.location, bot.location) <= radius then table.insert(units, unit) end
        end
        return units
    end
    function bot:GetNearbyLaneCreeps(radius)
        local units = {}
        for _, unit in ipairs(w.units[7] or {}) do
            if unit.alive and unit.seen and distance(unit.location, bot.location) <= radius then table.insert(units, unit) end
        end
        return units
    end
    function bot:GetUnitName() return 'npc_dota_hero_axe' end
    function bot:Action_MoveToLocation(loc) self.destination, self.action = loc, 'move' end
    function bot:Action_AttackUnit(target) self.attackTarget, self.action = target, 'attack' end
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
        ShouldWaitForBackup = function() return w.waitingForBackup or false end,
        GetHumanPing = function() return w.human, w.human.ping end,
        ModeAnnounce = function() w.announcements = w.announcements + 1 end,
        GetDistance = distance,
        IsValidHero = function(u) return u ~= nil and u.alive and u.seen and u.hero end,
        IsValidBuilding = function(u) return u ~= nil and u.alive and u.building end,
        IsSuspiciousIllusion = function(u) return u.illusion end,
        IsRoshan = function(u) return u ~= nil and u.alive and u.seen and u.roshan end,
        GetCurrentRoshanLocation = function() return w.pit end,
        CanBeAttacked = function(u) return u ~= nil and u.alive and u.seen and u.attackable end,
    }
    local env = setmetatable({
        BOT_MODE_DESIRE_NONE = 0,
        BOT_MODE_DESIRE_ABSOLUTE = 1,
        BOT_MODE_NONE = 0,
        BOT_MODE_ASSEMBLE = 14,
        BOT_MODE_ATTACK = 2,
        BOT_MODE_DEFEND_TOWER_MID = 12,
        BOT_MODE_PUSH_TOWER_MID = 9,
        BOT_MODE_ROSHAN = 20,
        UNIT_LIST_ENEMY_HEROES = 5,
        UNIT_LIST_ALLIED_HEROES = 2,
        UNIT_LIST_ENEMY_BUILDINGS = 11,
        UNIT_LIST_ALLIED_BUILDINGS = 10,
        UNIT_LIST_NEUTRAL_CREEPS = 13,
        TOWER_TOP_1 = 0, TOWER_TOP_2 = 1, TOWER_TOP_3 = 2,
        TOWER_MID_1 = 3, TOWER_MID_2 = 4, TOWER_MID_3 = 5,
        TOWER_BOT_1 = 6, TOWER_BOT_2 = 7, TOWER_BOT_3 = 8,
        TOWER_BASE_1 = 9, TOWER_BASE_2 = 10,
        GetBot = function() return bot end,
        GameTime = function() return w.now end,
        DotaTime = function() return w.now end,
        GetScriptDirectory = function() return 'bots' end,
        GetTeam = function() return 2 end,
        GetOpposingTeam = function() return 3 end,
        GetTower = function(team, id) return w.towers[team][id] end,
        GetTeamPlayers = function() return {0, 1, 2} end,
        GetTeamMember = function(i) return members[i] end,
        GetUnitToLocationDistance = function(u, loc) return distance(u.location, loc) end,
        GetUnitToUnitDistance = function(a, b) return distance(a.location, b.location) end,
        GetUnitList = function(kind) return w.units[kind] or {} end,
        IsLocationVisible = function() return w.visible end,
        IsPlayerBot = function(id) return id == 2 end,
        Vector = function(x, y) return vector(x, y) end,
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
    function w:unit(kind, loc)
        local u = {location = loc, alive = true, seen = true, attackable = true, modifiers = {}}
        u.hero = kind == 5 or kind == 2
        u.building = kind == 10 or kind == 11
        u.roshan = kind == 13
        function u:IsAlive() return self.alive end
        function u:IsNull() return false end
        function u:CanBeSeen() return self.seen end
        function u:GetLocation() return self.location end
        function u:GetTeam() return (kind == 2 or kind == 10) and 2 or 3 end
        function u:IsHero() return self.hero end
        function u:IsIllusion() return self.illusion or false end
        function u:GetPlayerID() return kind * 10 + #w.units[kind] end
        function u:IsBuilding() return self.building end
        function u:GetUnitName() return self.roshan and 'npc_dota_roshan' or 'test_unit' end
        function u:HasModifier(modifier) return self.modifiers[modifier] or false end
        w.units[kind] = w.units[kind] or {}
        table.insert(w.units[kind], u)
        return u
    end
    function w:loadRealJmz()
        local previousRequire = env.require
        env.require = function(name)
            if name:find('/aba_engagement', 1, true) then
                if setfenv then
                    local chunk = assert(loadfile(sourceRoot .. '/FunLib/aba_engagement.lua'))
                    setfenv(chunk, env)
                    return chunk()
                end
                return assert(loadfile(sourceRoot .. '/FunLib/aba_engagement.lua', 't', env))()
            end
            if name:find('/utils', 1, true) then
                return {IsValidHero = jmz.IsValidHero, IsValidUnit = jmz.IsValidHero}
            end
            return {}
        end
        local path = sourceRoot .. '/FunLib/jmz_func.lua'
        local result
        if setfenv then
            local chunk = assert(loadfile(path))
            setfenv(chunk, env)
            result = chunk()
        else
            result = assert(loadfile(path, 't', env))()
        end
        env.require = previousRequire
        return result
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

test('empty-ground danger pings do not create assembly orders', function()
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

test('enemy hero ping attacks and follows the visible target', function()
    local w = world()
    local enemy = w:unit(5, vector(2000))
    w:ping(enemy.location)
    assert(w.env.GetDesire() == 1)
    w.env.Think()
    assert(w.bot.action == 'attack' and w.bot.target == enemy and w.bot.attackTarget == enemy)
    assert(w.bot.humanPingMode == 'attack')
    enemy.location = vector(8000)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.attackTarget == enemy, 'moving target was replaced by the original ground point')
end)

test('enemy hero ping includes bots exactly 2500 units away', function()
    local w = world()
    local enemy = w:unit(5, vector(1500, 2000))
    w:ping(enemy.location)
    assert(w.env.GetDesire() == 1, 'bot on the response boundary is excluded')
    w.env.Think()
    assert(w.bot.attackTarget == enemy and w.bot.humanPingMode == 'attack')
end)

test('enemy hero ping excludes distant bots for either ping flag', function()
    for _, normal in ipairs({true, false}) do
        local w = world()
        local enemy = w:unit(5, vector(2501))
        w:ping(enemy.location, nil, normal)
        assert(w.env.GetDesire() == 0, 'distant hero ping recruits the bot')
        w.env.Think()
        assert(w.bot.action == nil and w.bot.humanPingMode == nil, 'rejected order issues an action')
        assert(w.announcements == 0, 'distant bot announces acceptance')
    end
end)

test('the same enemy ping recruits nearby bots and leaves distant bots alone', function()
    for _, position in ipairs({8500, 6500}) do
        local w = world()
        w.bot.location = vector(position)
        local enemy = w:unit(5, vector(10000))
        w:ping(enemy.location)
        local nearby = position == 8500
        assert(w.env.GetDesire() == (nearby and 1 or 0), 'response ignores individual bot distance')
        w.env.Think()
        assert((w.bot.attackTarget == enemy) == nearby, 'incorrect bot joins the attack')
    end
end)

test('a rejected hero ping is consumed and a fresh nearby ping is accepted', function()
    local w = world()
    local enemy = w:unit(5, vector(6000))
    w:ping(enemy.location)
    assert(w.env.GetDesire() == 0)
    w.now, w.bot.location = w.now + 1, vector(5000)
    assert(w.env.GetDesire() == 0, 'moving into range replays an ignored command')
    w:ping(enemy.location)
    assert(w.env.GetDesire() == 1, 'fresh nearby command is ignored')
    w.env.Think()
    assert(w.bot.attackTarget == enemy and w.announcements == 1)
end)

test('a distant hero ping preserves existing global orders', function()
    for _, kind in ipairs({'gather', 'push', 'roshan', 'defend'}) do
        local w = world()
        local destination = vector(12000)
        local objective
        if kind == 'push' then objective = w:unit(11, destination) end
        if kind == 'roshan' then objective = w:unit(13, destination) end
        if kind == 'defend' then objective = w:unit(10, destination) end
        w:ping(destination)
        assert(w.env.GetDesire() == 1, 'global ' .. kind .. ' order is restricted by distance')
        w.env.Think()
        w.now = w.now + 1
        local enemy = w:unit(5, vector(6000))
        w:ping(enemy.location)
        assert(w.env.GetDesire() == 1, 'rejected command cancels ' .. kind)
        w.env.Think()
        assert(w.bot.humanPingMode == kind and w.announcements == 1, 'rejected command replaces ' .. kind)
        if kind == 'push' or kind == 'roshan' then
            assert(w.bot.target == objective and w.bot.attackTarget == objective, 'objective target was lost')
        else
            assert(w.bot.destination == destination, 'global destination was lost')
        end
    end
end)

test('a distant hero ping preserves an already accepted attack', function()
    local w = world()
    local first = w:unit(5, vector(2000))
    w:ping(first.location)
    w.env.GetDesire()
    w.env.Think()
    w.now = w.now + 1
    local distant = w:unit(5, vector(6000))
    w:ping(distant.location)
    assert(w.env.GetDesire() == 1)
    w.env.Think()
    assert(w.bot.target == first and w.bot.attackTarget == first, 'distant ping clears the active focus')
    assert(w.announcements == 1, 'rejected retask is announced')
end)

test('lost hero vision searches the last seen point and releases the order', function()
    local w = world()
    local enemy = w:unit(5, vector(2000))
    w:ping(enemy.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.action == 'attack' and w.bot.target == enemy, 'focus command never started')
    enemy.seen, enemy.location = false, vector(10000)
    w.bot.location = vector(2000)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.action == 'move' and w.bot.destination.x == 2000, 'hidden live coordinates were followed')
    assert(w.bot.target == nil, 'hidden combat target survives')
    w.now = w.now + 9
    assert(w.env.GetDesire() == 0 and w.bot.humanPingMode == nil, 'fog search holds the team forever')
end)

test('a killed hero completes the attack order', function()
    local w = world()
    local enemy = w:unit(5, vector(2000))
    w:ping(enemy.location)
    w.env.GetDesire()
    w.env.Think()
    enemy.alive = false
    assert(w.env.GetDesire() == 0 and w.bot.target == nil, 'dead target keeps the attack order active')
end)

test('hero illusions do not become focused hero orders', function()
    local w = world()
    local illusion = w:unit(5, vector(6000))
    illusion.illusion = true
    w:ping(illusion.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.action == 'move' and w.bot.target == nil and w.bot.attackTarget ~= illusion)
end)

test('a target ping is recognized with either reported ping flag', function()
    local w = world()
    local enemy = w:unit(5, vector(2000))
    w:ping(enemy.location, nil, false)
    assert(w.env.GetDesire() == 1)
    w.env.Think()
    assert(w.bot.attackTarget == enemy, 'target ping is discarded solely because of its flag')
end)

test('enemy tower ping attacks the requested tower', function()
    local w = world()
    local tower = w:unit(11, vector(6000))
    w:ping(tower.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.humanPingMode == 'push' and w.bot.attackTarget == tower)
end)

test('protected towers are approached and waves are cleared before attacking', function()
    local w = world()
    local tower = w:unit(11, vector(6000))
    tower.modifiers.modifier_backdoor_protection_active = true
    w:ping(tower.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.action == 'move' and w.bot.attackTarget == nil, 'backdoored tower is attacked')
    w.bot.location = tower.location
    local creep = w:unit(7, vector(6100))
    w.env.Think()
    assert(w.bot.attackTarget == creep, 'bot waits instead of clearing a wave')
    tower.modifiers.modifier_backdoor_protection_active = false
    w.env.Think()
    assert(w.bot.attackTarget == tower, 'tower is not attacked after protection ends')
end)

test('permanently blocked targets have a bounded wait', function()
    local w = world()
    local tower = w:unit(11, vector(6000))
    tower.attackable = false
    w.bot.location = tower.location
    w:ping(tower.location)
    assert(w.env.GetDesire() == 1, 'blocked-objective order never started')
    w.env.Think()
    w.now = w.now + 21
    w.env.Think()
    assert(w.env.GetDesire() == 0, 'unattackable objective holds the team forever')
end)

test('known towers in fog are recognized before protection ends', function()
    local w = world()
    local tower = w:unit(11, vector(6000))
    tower.seen, tower.attackable = false, false
    w.towers[3][0] = tower
    w.units[11] = {}
    w:ping(tower.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.humanPingMode == 'push' and w.bot.destination == tower.location, 'known fog tower becomes a ground order')
    w.bot.location, tower.seen = tower.location, true
    w.env.Think()
    assert(w.bot.attackTarget == nil, 'protected tower is attacked')
    tower.attackable = true
    w.env.Think()
    assert(w.bot.attackTarget == tower, 'revealed, attackable tower is not attacked')
end)

test('temporary hero invulnerability does not discard a target ping', function()
    local w = world()
    local enemy = w:unit(5, vector(2000))
    enemy.attackable = false
    w:ping(enemy.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.humanPingMode == 'attack' and w.bot.destination == enemy.location)
    enemy.attackable = true
    w.env.Think()
    assert(w.bot.attackTarget == enemy)
end)

test('allied tower ping defends against enemy heroes without attacking the tower', function()
    local w = world()
    local tower = w:unit(10, vector(6000))
    w:ping(tower.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.action == 'move' and w.bot.destination == tower.location)
    w.bot.location = tower.location
    local enemy = w:unit(5, vector(6100))
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.humanPingMode == 'defend' and w.bot.attackTarget == enemy)
end)

test('allied tower defense clears enemy lane creeps', function()
    local w = world()
    local tower = w:unit(10, vector(6000))
    local creep = w:unit(7, vector(6100))
    w.bot.location = tower.location
    w:ping(tower.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.attackTarget == creep and w.bot.attackTarget ~= tower)
end)

test('quiet defense releases the team after arrival', function()
    local w = world()
    local tower = w:unit(10, vector(6000))
    w.bot.location = tower.location
    w:ping(tower.location)
    assert(w.env.GetDesire() == 1)
    w.env.Think()
    assert(w.bot.action == 'move' and w.bot.attackTarget == nil)
    w.now = w.now + 16
    assert(w.env.GetDesire() == 0, 'quiet defense becomes permanent camping')
end)

test('defense continues during pressure and ends after the threat is gone', function()
    local w = world()
    local tower = w:unit(10, vector(6000))
    local enemy = w:unit(5, vector(6100))
    w.bot.location = tower.location
    w:ping(tower.location)
    w.env.GetDesire()
    w.env.Think()
    w.now = w.now + 30
    assert(w.env.GetDesire() == 1, 'ongoing defense times out')
    w.env.Think()
    enemy.alive = false
    w.now = w.now + 16
    assert(w.env.GetDesire() == 0, 'resolved defense never releases the team')
end)

test('allied hero ping follows and supports the moving ally', function()
    local w = world()
    local ally = w:unit(2, vector(6000))
    w:ping(ally.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.humanPingMode == 'defend' and w.bot.destination == ally.location)
    ally.location = vector(8000)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.destination == ally.location and w.bot.attackTarget ~= ally)
end)

test('defense does not chase an attacker away from the protected objective', function()
    local w = world()
    local tower = w:unit(10, vector(6000))
    local enemy = w:unit(5, vector(6100))
    w.bot.location = tower.location
    w:ping(tower.location)
    w.env.GetDesire()
    w.env.Think()
    enemy.location, w.bot.location = vector(8000), vector(7900)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.action == 'move' and w.bot.destination == tower.location and w.bot.target == nil)
end)

test('visible Roshan ping attacks Roshan until it dies', function()
    local w = world()
    local roshan = w:unit(13, vector(6000))
    w:ping(roshan.location)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.humanPingMode == 'roshan' and w.bot.attackTarget == roshan)
    roshan.alive = false
    assert(w.env.GetDesire() == 0, 'dead Roshan keeps the command active')
end)

test('unseen Roshan pit ping travels to the pit and acquires Roshan', function()
    local w = world()
    w.pit = vector(6000)
    w:ping(w.pit)
    assert(w.env.GetDesire() == 1)
    w.env.Think()
    assert(w.bot.humanPingMode == 'roshan' and w.bot.destination == w.pit)
    w.now, w.bot.location, w.visible = w.now + 1, w.pit, true
    local roshan = w:unit(13, w.pit)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.attackTarget == roshan, 'pit arrival does not start the objective')
end)

test('confirmed empty Roshan pit releases the command', function()
    local w = world()
    w.pit, w.visible = vector(6000), true
    w:ping(w.pit)
    assert(w.env.GetDesire() == 0, 'bots are sent to camp a confirmed empty pit')
end)

test('new ground command clears the previous focused combat target', function()
    local w = world()
    local enemy = w:unit(5, vector(2000))
    w:ping(enemy.location)
    w.env.GetDesire()
    w.env.Think()
    w.now = w.now + 1
    local target = vector(-6000)
    w:ping(target)
    w.env.GetDesire()
    w.env.Think()
    assert(w.bot.target == nil and w.bot.humanPingMode == 'gather' and w.bot.destination == target)
end)

test('unsafe target ping waits without forgetting the order and resumes with backup', function()
    local w = world() local enemy = w:unit(5, vector(1000)) w:ping(enemy.location)
    w.waitingForBackup = true
    assert(w.env.GetDesire() == 0) w.env.Think()
    assert(w.bot.attackTarget == nil and w.bot.humanPingMode == 'attack')
    w.waitingForBackup = false
    assert(w.env.GetDesire() == 1) w.env.Think()
    assert(w.bot.attackTarget == enemy)
end)

test('distant ping still recruits bots before the local safety check applies', function()
    local w = world() w:ping(vector(12000)) w.waitingForBackup = true
    assert(w.env.GetDesire() == 1) w.env.Think()
    assert(w.bot.destination.x == 12000)
end)

test('hero ability context recognizes commanded attacks, defense, push and Roshan', function()
    local w = world()
    local actualJmz = w:loadRealJmz()
    w.bot.humanPingMode = 'attack'
    assert(not actualJmz.IsGoingOnSomeone(w.bot), 'attack spell context is enabled without a combat target')
    w.bot.target = w:unit(5, vector(100))
    assert(actualJmz.IsGoingOnSomeone(w.bot), 'attack spells cannot see a commanded fight')
    w.bot.humanPingMode = 'push'
    assert(actualJmz.IsPushing(w.bot), 'push spells cannot see a commanded siege')
    w.bot.humanPingMode = 'roshan'
    assert(actualJmz.IsDoingRoshan(w.bot), 'Roshan spells cannot see a commanded objective')
    w.bot.humanPingMode = 'defend'
    w.bot.target = w:unit(5, vector(100))
    assert(actualJmz.IsDefending(w.bot) and actualJmz.IsGoingOnSomeone(w.bot), 'defensive combat loses spell context')
    w.bot.mode = 0
    assert(not actualJmz.IsDefending(w.bot) and not actualJmz.IsGoingOnSomeone(w.bot), 'stale command state leaks into another mode')
    w.bot.humanPingMode = nil
    w.bot.mode = 2
    assert(actualJmz.IsGoingOnSomeone(w.bot), 'normal attack mode regresses')
    w.bot.mode = 9
    assert(actualJmz.IsPushing(w.bot), 'normal push mode regresses')
    w.bot.mode = 12
    assert(actualJmz.IsDefending(w.bot), 'normal defense mode regresses')
    w.bot.mode = 20
    assert(actualJmz.IsDoingRoshan(w.bot), 'normal Roshan mode regresses')
end)

print(string.format('%d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
