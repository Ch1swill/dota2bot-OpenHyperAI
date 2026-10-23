-- Run from the repository root: lua tests/turbo_push_regression.lua
-- Supports Lua 5.1 and newer; the optional argument selects another bots directory.
local sourceRoot = (arg and arg[1]) or 'bots'
local passed, failed = 0, 0

local function check(condition, message)
    assert(condition, message)
end

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

local function nearby(units, location, radius)
    local result = {}
    for _, unit in ipairs(units) do
        if unit:IsAlive() and distance(unit:GetLocation(), location) <= radius then
            table.insert(result, unit)
        end
    end
    return result
end

local function world()
    local w = {
        now = 1500, turbo = true, late = true, pitVisible = false,
        teamNetworth = 90000, enemyNetworth = 90000,
        aliveAllies = 5, aliveEnemies = 5, baseThreat = 0,
        pit = vector(-2000), waiting = vector(-2000, 2000),
        fronts = {[1] = vector(2000, 2500), [2] = vector(2000), [3] = vector(2000, -2500)},
        allies = {}, enemies = {}, neutrals = {}, buildings = {},
    }

    local function unit(id, core, location)
        local u = {id = id, core = core, location = location, alive = true, hp = 1, mode = 0, attacking = false}
        function u:GetLocation() return self.location end
        function u:GetPlayerID() return self.id end
        function u:GetTeam() return 3 end
        function u:GetUnitName() return self.name or 'npc_dota_hero_axe' end
        function u:IsAlive() return self.alive end
        function u:IsBot() return true end
        function u:IsHero() return true end
        function u:IsIllusion() return false end
        function u:IsInvulnerable() return false end
        function u:IsNull() return false end
        function u:CanBeSeen() return true end
        function u:GetLevel() return 20 end
        function u:GetNetWorth() return 18000 end
        function u:GetAttackDamage() return 600 end
        function u:GetAttackSpeed() return 2 end
        function u:GetAttackRange() return 150 end
        function u:GetHealth() return 2000 * self.hp end
        function u:GetMaxHealth() return 2000 end
        function u:GetHealthRegen() return 10 end
        function u:GetActiveMode() return self.mode end
        function u:GetActiveModeDesire() return 0 end
        function u:GetAssignedLane() return 2 end
        function u:GetAttackTarget() return self.target end
        function u:GetTarget() return self.target end
        function u:HasModifier() return false end
        function u:WasRecentlyDamagedByAnyHero() return false end
        function u:WasRecentlyDamagedByTower() return false end
        function u:GetNearbyTowers() return {} end
        function u:GetNearbyLaneCreeps() return {} end
        function u:GetNearbyCreeps() return {} end
        function u:GetNearbyNeutralCreeps(radius) return nearby(w.neutrals, self.location, radius) end
        function u:Action_MoveToLocation(loc) self.action = {'move', loc} end
        function u:Action_AttackMove(loc) self.action = {'attack_move', loc} end
        function u:Action_AttackUnit(target) self.action = {'attack', target} end
        return u
    end

    for i = 1, 5 do
        w.allies[i] = unit(i - 1, i <= 3, vector(0))
        w.allies[i].tormentor_state = true
        w.allies[i].tormentor_team_healthy = true
        w.allies[i].tormentor_kill_time = 0
    end
    w.bot = w.allies[1]
    w.ancient = unit(20, false, vector(-10000))
    w.enemyAncient = unit(21, false, vector(10000))
    w.tormentor = unit(22, false, w.pit)
    w.tormentor.name = 'npc_dota_miniboss'

    local jmz = {
        Utils = {
            GameStates = {defendPings = {pingedTime = 0}},
            IsTeamPushingSecondTierOrHighGround = function() return false end,
            CountEnemyHeroesNear = function() return w.baseThreat end,
            GetAllyIdsInTpToLocation = function() return {} end,
            NumHumanBotPlayersInTeam = function() return 1, 4 end,
            HasTeamMemberWithCriticalItemInCooldown = function() return false end,
            HasTeamMemberWithCriticalSpellInCooldown = function() return false end,
            IsAnyBarracksOnLaneAlive = function() return true end,
            IsBotThinkingMeaningfulAction = function() return false end,
        },
        IsModeTurbo = function() return w.turbo end,
        IsLateGame = function() return w.late end,
        IsEarlyGame = function() return not w.late end,
        IsMidGame = function() return false end,
        IsInLaningPhase = function() return false end,
        IsCore = function(u) return u.core end,
        GetPosition = function(u) return u.id + 1 end,
        IsValid = function(u) return u ~= nil and u.alive end,
        IsValidHero = function(u) return u ~= nil and u.alive end,
        IsValidBuilding = function(u) return u ~= nil and u.alive and u.building end,
        IsTormentor = function(u) return u ~= nil and u.alive and u.name == 'npc_dota_miniboss' end,
        IsRoshan = function() return false end,
        IsDoingRoshan = function() return false end,
        IsDoingTormentor = function(u) return u.mode == 6 end,
        IsDefending = function() return false end,
        IsAttacking = function(u) return u.attacking end,
        IsRealInvisible = function() return false end,
        DoesUnitHaveTemporaryBuff = function() return false end,
        GetProperTarget = function(u) return u.target end,
        GetHP = function(u) return u.hp end,
        GetMP = function() return 1 end,
        CanNotUseAction = function() return false end,
        CanBeAttacked = function(u) return u ~= nil and u.alive end,
        GetCoresAverageNetworth = function() return 18000 end,
        GetTormentorLocation = function() return w.pit end,
        GetTormentorWaitingLocation = function() return w.waiting end,
        GetCurrentRoshanLocation = function() return vector(9000, 9000) end,
        GetAlliesNearLoc = function(loc, radius) return nearby(w.allies, loc, radius) end,
        GetEnemiesNearLoc = function(loc, radius) return nearby(w.enemies, loc, radius) end,
        GetLastSeenEnemiesNearLoc = function() return {} end,
        GetEnemiesAroundLoc = function() return 0 end,
        GetEnemiesAroundAncient = function() return 0 end,
        GetFirstBotInTeam = function() return w.allies[1] end,
        GetAliveAllyCoreCount = function() return 3 end,
        GetNumOfAliveHeroes = function(enemy) return enemy and w.aliveEnemies or w.aliveAllies end,
        GetAliveCoreCount = function() return 3 end,
        GetInventoryNetworth = function() return w.teamNetworth, w.enemyNetworth end,
        GetAverageLevel = function() return 20 end,
        DoesTeamHaveAegis = function() return false end,
        GetTeamFountain = function() return vector(-10000) end,
        GetHumanPing = function() return nil, nil end,
        GetDistance = distance,
        GetRandomLocationWithinDist = function(loc) return loc end,
        IsInRange = function(a, b, radius) return distance(a.location, b.location) <= radius end,
    }
    local modes = {None = 0, SideShop = 6, PushTowerTop = 8, PushTowerMid = 9, PushTowerBot = 10}
    local unitTypes = {AlliedHeroes = 2, AlliedCreeps = 3, Enemies = 7, EnemyBuildings = 11}
    local cache = {
        getGlobalGameState = function()
            return {
                currentTime = w.now * (w.turbo and 2 or 1), gameMode = w.turbo and 23 or 1,
                team = 3, enemyTeam = 2, ourAncient = w.ancient, enemyAncient = w.enemyAncient,
                aliveAllyCount = w.aliveAllies, aliveEnemyCount = w.aliveEnemies,
                aliveAllyCoreCount = 3, aliveEnemyCoreCount = 3,
                teamNetworth = w.teamNetworth, enemyNetworth = w.enemyNetworth, averageLevel = 20,
                hasAegis = false, isEarlyGame = not w.late, isMidGame = false, isLateGame = w.late, isLaningPhase = false,
            }
        end,
        getGlobalLocationState = function()
            return {teamFountain = vector(-10000), roshanLocation = vector(9000, 9000), tormentorLocation = w.pit, tormentorWaitingLocation = w.waiting}
        end,
        getCachedAlliesNearLoc = jmz.GetAlliesNearLoc,
        getCachedEnemiesNearLoc = jmz.GetEnemiesNearLoc,
        autoCleanupCache = function() end,
        getCachedData = function(_, _, fetch) return fetch() end,
    }
    local env = setmetatable({
        BOT_MODE_DESIRE_NONE = 0, BOT_MODE_DESIRE_LOW = 0.25, BOT_MODE_DESIRE_HIGH = 0.75, BOT_MODE_DESIRE_VERYHIGH = 0.9,
        DotaTime = function() return w.now end,
        GameTime = function() return w.now end,
        GetBot = function() return w.bot end,
        GetTeam = function() return 3 end,
        GetOpposingTeam = function() return 2 end,
        GetScriptDirectory = function() return 'bots' end,
        GetGameMode = function() return w.turbo and 23 or 1 end,
        GetTeamPlayers = function(team) return team == 3 and {0, 1, 2, 3, 4} or {5, 6, 7, 8, 9} end,
        GetTeamMember = function(i) return w.allies[i] end,
        GetAncient = function(team) return team == 3 and w.ancient or w.enemyAncient end,
        GetTower = function(team) return team == 3 and w.ancient or nil end,
        GetBarracks = function() return nil end,
        IsLocationVisible = function() return w.pitVisible end,
        IsHeroAlive = function() return true end,
        GetHeroLastSeenInfo = function() return {} end,
        GetIncomingTeleports = function() return {} end,
        GetLaneFrontLocation = function(_, lane) return w.fronts[lane] end,
        GetUnitToLocationDistance = function(u, loc) return distance(u.location, loc) end,
        GetUnitToUnitDistance = function(a, b) return distance(a.location, b.location) end,
        GetUnitList = function(kind)
            if kind == unitTypes.AlliedHeroes then return w.allies end
            if kind == unitTypes.EnemyBuildings then return w.buildings end
            if kind == unitTypes.Enemies then return w.enemies end
            return {}
        end,
        RemapValClamped = function(value, low, high, min, max)
            return min + math.max(0, math.min(1, (value - low) / (high - low))) * (max - min)
        end,
        RandomFloat = function(low) return low end,
        unpack = table.unpack or unpack,
        require = function(name)
            if name:find('jmz_func', 1, true) then return jmz end
            if name:find('Customize', 1, true) then return {Enable = true, ThinkLess = 1} end
            if name:find('localization', 1, true) then return {} end
            if name:find('global_cache', 1, true) then return cache end
            if name:find('ts_libs/dota', 1, true) then
                return {
                    Lane = {Top = 1, Mid = 2, Bot = 3}, Team = {Radiant = 2, Dire = 3}, BotMode = modes,
                    BotModeDesire = {None = 0, ExtraLow = 0.1, VeryLow = 0.15}, Tower = {}, Barracks = {}, UnitType = unitTypes, DamageType = {},
                }
            end
            if name:find('utils', 1, true) then
                return {GetLocationToLocationDistance = distance, IsValidUnit = jmz.IsValid, RadiantFountainTpPoint = vector(-10000), DireFountainTpPoint = vector(10000)}
            end
            error('Unexpected require: ' .. name)
        end,
    }, {__index = _G})
    w.env = env
    return w
end

local function loadModule(w, path)
    if setfenv then
        local chunk = assert(loadfile(sourceRoot .. '/' .. path))
        setfenv(chunk, w.env)
        return chunk()
    end
    return assert(loadfile(sourceRoot .. '/' .. path, 't', w.env))()
end

test('visible empty Tormentor pit releases every teammate', function()
    local w = world()
    w.pitVisible = true
    for _, member in ipairs(w.allies) do member.location = w.pit end
    loadModule(w, 'mode_side_shop_generic.lua')
    check(w.env.GetDesire() == 0, 'missing Tormentor still claims the mode')
    for _, member in ipairs(w.allies) do
        check(not member.tormentor_state and not member.tormentor_team_healthy, 'stale teammate state survives')
        check(member.tormentor_kill_time == w.now, 'absence is not shared')
    end
    w.now = w.now + 10
    check(w.env.GetDesire() == 0, 'empty pit immediately recruits the group again')
end)

test('fog of war does not invent a Tormentor kill', function()
    local w = world()
    loadModule(w, 'mode_side_shop_generic.lua')
    check(w.env.GetDesire() > 0, 'unseen objective cannot be scouted')
    check(w.bot.tormentor_kill_time == 0, 'fog was mistaken for a confirmed kill')
end)

for _, turbo in ipairs({true, false}) do
    test((turbo and 'Turbo' or 'normal') .. ' waiting has a deadline and retry cooldown', function()
        local w = world()
        w.turbo = turbo
        w.now = turbo and 1200 or 1500
        for _, member in ipairs(w.allies) do member.location = w.waiting end
        loadModule(w, 'mode_side_shop_generic.lua')
        check(w.env.GetDesire() > 0, 'group never starts waiting')
        w.now = w.now + (turbo and 45 or 90)
        check(w.env.GetDesire() == 0, 'group waits forever')
        w.now = w.now + 10
        w.allies[2].tormentor_state = true
        check(w.env.GetDesire() == 0, 'stale teammate bypasses retry cooldown')
        w.now = w.now + 51
        check(w.env.GetDesire() > 0, 'objective permanently disabled after timeout')
    end)
end

test('active Tormentor combat survives the waiting deadline', function()
    local w = world()
    w.neutrals = {w.tormentor}
    w.pitVisible = true
    for _, member in ipairs(w.allies) do member.location = w.pit end
    w.bot.target = w.tormentor
    w.bot.attacking = true
    loadModule(w, 'mode_side_shop_generic.lua')
    for _ = 1, 4 do
        check(w.env.GetDesire() > 0, 'ongoing Tormentor combat was abandoned')
        w.now = w.now + 46
    end
end)

test('Tormentor group counts use current positions', function()
    local w = world()
    w.now = 1200
    for _, member in ipairs(w.allies) do member.location = vector(6000) end
    w.allies[1].location, w.allies[4].location = w.waiting, w.waiting
    loadModule(w, 'mode_side_shop_generic.lua')
    check(w.env.GetDesire() > 0.75, 'nearby group did not get group desire')
    w.allies[1].location, w.allies[4].location = vector(6000), vector(6000)
    w.now = w.now + 1
    check(w.env.GetDesire() <= 0.75, 'nearby group counts accumulate across evaluations')
end)

test('late-game grouped Turbo bots prefer pushing over passive farming', function()
    local w = world()
    local push = loadModule(w, 'FunLib/aba_push.lua')
    check(push.GetPushDesireHelper(w.bot, 2) > 0.6, '5v5 group is permanently capped below farm desire')
end)

test('early-game groups retain conservative push desire', function()
    local w = world()
    w.late, w.now = false, 700
    local push = loadModule(w, 'FunLib/aba_push.lua')
    check(push.GetPushDesireHelper(w.bot, 2) <= 0.41, 'early group gets late-game aggression')
end)

test('solo pushing remains disabled against three or more enemies', function()
    local w = world()
    for i = 2, 5 do w.allies[i].location = vector(6000) end
    local push = loadModule(w, 'FunLib/aba_push.lua')
    check(push.GetPushDesireHelper(w.bot, 2) == 0, 'solo safety gate was removed')
end)

test('outnumbered teams retain the push safety gate', function()
    local w = world()
    w.aliveAllies = 3
    local push = loadModule(w, 'FunLib/aba_push.lua')
    check(push.GetPushDesireHelper(w.bot, 2) == 0, '3v5 group commits to pushing')
end)

test('base defense takes priority over a formed pushing group', function()
    local w = world()
    w.baseThreat = 1
    local push = loadModule(w, 'FunLib/aba_push.lua')
    check(push.GetPushDesireHelper(w.bot, 2) <= 0.1, 'group ignores enemies at its Ancient')
end)

test('low-health groups retain a low push desire', function()
    local w = world()
    w.bot.hp = 0.4
    local push = loadModule(w, 'FunLib/aba_push.lua')
    check(push.GetPushDesireHelper(w.bot, 2) <= 0.25, 'group bonus bypasses health safety cap')
end)

test('push movement uses the current lane waypoint within cache TTL', function()
    local w = world()
    local push = loadModule(w, 'FunLib/aba_push.lua')
    push.PushThink(w.bot, 2)
    check(w.bot.action and w.bot.action[1] == 'move', 'far waypoint was treated as already reached')
    check(w.bot.action[2] == w.fronts[2], 'wrong waypoint selected')
    w.now = w.now + 0.1
    w.bot.location, w.fronts[2] = vector(2000), vector(4000)
    push.PushThink(w.bot, 2)
    check(w.bot.action[1] == 'move' and w.bot.action[2] == w.fronts[2], 'cached snapshot hides a changed waypoint')
end)

print(string.format('%d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
