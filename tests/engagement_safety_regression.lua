-- Run: lua tests/engagement_safety_regression.lua [bots-directory]
local sourceRoot = (arg and arg[1]) or 'bots'
local passed, failed = 0, 0
local function test(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1 print('PASS ' .. name)
    else failed = failed + 1 print('FAIL ' .. name .. ': ' .. tostring(err)) end
end

local vmt = {}
local function vector(x, y) return setmetatable({x = x, y = y or 0, z = 0}, vmt) end
vmt.__add = function(a, b) return vector(a.x + b.x, a.y + b.y) end
vmt.__sub = function(a, b) return vector(a.x - b.x, a.y - b.y) end
vmt.__mul = function(a, b) return vector(a.x * b, a.y * b) end
vmt.__index = {
    Length2D = function(a) return math.sqrt(a.x * a.x + a.y * a.y) end,
    Normalized = function(a) return a * (1 / math.max(1, a:Length2D())) end,
}
local function distance(a, b) return (a - b):Length2D() end
local function loadIn(path, env)
    local chunk, err
    if setfenv then chunk, err = loadfile(sourceRoot .. '/' .. path) if chunk then setfenv(chunk, env) end
    else chunk, err = loadfile(sourceRoot .. '/' .. path, 't', env) end
    assert(chunk, err) return chunk()
end

local function world()
    local w = {now = 100, allies = {}, enemies = {}, casts = {}, passable = true}
    local function hero(id, x, y, team)
        local unit = {id = id, location = vector(x, y), team = team or 2, hp = 1000, mode = 2,
            range = 150, speed = 300, facing = true, modifiers = {}, action = 1, queued = 0}
        function unit:IsNull() return false end
        function unit:IsAlive() return not self.dead end
        function unit:CanBeSeen() return not self.hidden end
        function unit:IsHero() return true end
        function unit:IsBot() return not self.human end
        function unit:IsIllusion() return self.illusion or false end
        function unit:IsInvulnerable() return self.invulnerable or false end
        function unit:IsStunned() return self.stunned or false end
        function unit:IsHexed() return self.hexed or false end
        function unit:IsNightmared() return self.nightmared or false end
        function unit:IsRooted() return self.rooted or false end
        function unit:IsDisarmed() return self.disarmed or false end
        function unit:IsSilenced() return self.silenced or false end
        function unit:IsUsingAbility() return self.using or false end
        function unit:IsCastingAbility() return self.casting or false end
        function unit:IsChanneling() return self.channeling or false end
        function unit:NumQueuedActions() return self.queued end
        function unit:HasModifier(name) return self.modifiers[name] or false end
        function unit:GetTeam() return self.team end
        function unit:GetPlayerID() return self.id end
        function unit:GetHealth() return self.hp end
        function unit:GetMaxHealth() return 1000 end
        function unit:GetActiveMode() return self.mode end
        function unit:GetActiveModeDesire() return 0.9 end
        function unit:GetUnitName() return 'npc_dota_hero_axe' end
        function unit:GetLocation() return self.location end
        function unit:GetTarget() return self.target end
        function unit:GetAttackTarget() return self.attackTarget end
        function unit:GetAttackRange() return self.range end
        function unit:GetCurrentMovementSpeed() return self.speed end
        function unit:GetCurrentActionType() return self.action end
        function unit:IsFacingLocation() return self.facing end
        function unit:WasRecentlyDamagedByAnyHero() return false end
        function unit:DistanceFromFountain() return 6000 end
        function unit:Action_MoveToLocation(location) self.destination = location end
        function unit:Action_ClearActions() self.cleared = true end
        return unit
    end
    w.bot = hero(0, 0)
    w.allies = {w.bot}
    function w:ally(x, y) local u = hero(#self.allies, x, y) table.insert(self.allies, u) return u end
    function w:enemy(x, y) local u = hero(5 + #self.enemies, x, y, 3) table.insert(self.enemies, u) return u end
    local env = setmetatable({
        Vector = vector, DotaTime = function() return w.now end,
        GetBot = function() return w.bot end, GetTeam = function() return 2 end,
        GetScriptDirectory = function() return 'bots' end,
        GetTeamPlayers = function() local ids = {} for _, u in ipairs(w.allies) do table.insert(ids, u.id) end return ids end,
        GetTeamMember = function(i) return w.allies[i] end,
        GetUnitList = function() return w.enemies end,
        GetUnitToLocationDistance = function(u, p) return distance(u.location, p) end,
        GetUnitToUnitDistance = function(a, b) return distance(a.location, b.location) end,
        GetAncient = function() return {GetLocation = function() return vector(-7000) end} end,
        IsPlayerBot = function() return true end,
        IsLocationPassable = function() return w.passable end,
        UNIT_LIST_ENEMY_HEROES = 5,
        BOT_MODE_RETREAT = 1, BOT_MODE_ATTACK = 2, BOT_MODE_EVASIVE_MANEUVERS = 19,
        BOT_MODE_ASSEMBLE = 14, BOT_MODE_DESIRE_MODERATE = 0.5,
        BOT_MODE_DESIRE_NONE = 0, BOT_MODE_DESIRE_ABSOLUTE = 1,
        BOT_ACTION_TYPE_MOVE_TO = 1, BOT_ACTION_TYPE_ATTACKMOVE = 2,
    }, {__index = _G})
    w.env = env
    w.safety = loadIn('FunLib/aba_engagement.lua', env)
    env.require = function(path)
        if path:find('aba_engagement', 1, true) then return w.safety end
        if path:find('/utils', 1, true) then
            return {IsValidHero = function(u) return u ~= nil and u:IsHero() and u:IsAlive() and u:CanBeSeen() end}
        end
        return {}
    end
    w.jmz = loadIn('FunLib/jmz_func.lua', env)
    env.require = function() return w.jmz end
    loadIn('mode_evasive_maneuvers_generic.lua', env)
    function w:group(x)
        self.bot.target = self:enemy(x or 1200)
        self:enemy((x or 1200) + 100, 100)
        self:enemy((x or 1200) + 200, -100)
    end
    function w:risk(location) return self.safety.Evaluate(self.bot, location) end
    function w:advance() self.now = self.now + 0.3 end
    function w:heroScript(name)
        local j = self.jmz
        j.CanNotUseAbility = function() return false end
        j.GetNearbyHeroes = function() return self.enemies end
        j.Skill = setmetatable({}, {__index = function() return function() return {} end end})
        j.Item.GetRoleItemsBuyList = function() return 'pos_3' end
        j.Role.IsPvNMode = function() return false end
        j.Role.IsAllShadow = function() return false end
        j.SetUserHeroInit = function(...) return ... end
        self.env.dofile = function() return {} end
        self.env.RandomInt = function(a) return a end
        function self.bot:GetAbilityByName(abilityName)
            return {GetName = function() return abilityName end, GetLevel = function() return 1 end,
                IsInAbilityPhase = function() return false end}
        end
        function self.bot:ActionQueue_UseAbilityOnLocation() table.insert(w.casts, 'queued-gap-close') end
        function self.bot:ActionQueue_UseAbility() table.insert(w.casts, 'queued-spell') end
        function self.bot:ActionQueue_Delay() end
        function self.bot:Action_UseAbilityOnEntity(ability) table.insert(w.casts, ability:GetName()) end
        local x = loadIn('BotLib/hero_' .. name .. '.lua', self.env)
        for key in pairs(x) do if key:find('Consider', 1, true) == 1 then x[key] = function() return 0 end end end
        self.env.CanBKB = function() return false end
        return x
    end
    return w
end

test('healthy lone hero waits before walking into three enemies', function()
    local w = world() w:group()
    assert(w:risk().unsafe and w:risk().enemies == 3 and w:risk().readyAllies == 1)
    assert(w.env.GetDesire() > 1 and not w.jmz.IsGoingOnSomeone(w.bot))
end)
test('one enemy does not block a solo pickoff', function()
    local w = world() w.bot.target = w:enemy(500)
    assert(not w:risk().unsafe and w.jmz.IsGoingOnSomeone(w.bot) and w.env.GetDesire() == 0)
end)
test('distant teammates in the old 2200 radius do not count as backup', function()
    local w = world() w:group() w:ally(-1200) w:ally(-1600)
    assert(w:risk().unsafe and w:risk().readyAllies == 1)
end)
test('a nearby teammate running away does not count as arriving backup', function()
    local w = world() w:group(800) local a = w:ally(400) a.mode = 1
    assert(w:risk().unsafe and w:risk().readyAllies == 1)
end)
for _, state in ipairs({'stunned', 'hexed', 'nightmared', 'dead', 'illusion', 'invulnerable'}) do
    test(state .. ' teammate is not counted as ready support', function()
        local w = world() w:group(800) local a = w:ally(500) a[state] = true
        assert(w:risk().readyAllies == 1)
    end)
end
test('low-health and teleporting teammates do not count as support', function()
    local w = world() w:group(800) w:ally(500).hp = 100
    w:ally(500).modifiers.modifier_teleporting = true
    assert(w:risk().readyAllies == 1)
end)
test('teammate unable to attack or cast is not counted as support', function()
    local w = world() w:group(800) local a = w:ally(500) a.disarmed = true a.silenced = true
    assert(w:risk().readyAllies == 1)
end)
test('nearby gathered squad can advance together without a waiting deadlock', function()
    local w = world() w:group(1600) w:ally(-100, 100) w:ally(-200, -100)
    assert(not w:risk().unsafe and w:risk().readyAllies == 3 and w.env.GetDesire() == 0)
end)
test('a very slow teammate beside the initiator cannot keep up', function()
    local w = world() w:group(1600) w:ally(-100).speed = 50
    assert(w:risk().readyAllies == 1)
end)
test('backup reaching attack range in time is counted', function()
    local w = world() w:group(1600) w:ally(1000) w:ally(1600, 600).range = 600
    assert(not w:risk().unsafe and w:risk().readyAllies == 3)
end)
test('idle distant allies are not treated as joining the fight', function()
    local w = world() w:group(1600) local a = w:ally(900) a.action = 0 a.facing = false
    assert(w:risk().readyAllies == 1)
end)
test('long-distance charge checks the landing fight rather than the origin', function()
    local w = world() w:group(6000) w:ally(-1000) w:ally(-1600)
    assert(w.jmz.ShouldWaitForBackup(w.bot, w.bot.target:GetLocation()))
    assert(not w:risk().unsafe, 'a distant group stops ordinary travel')
end)
test('waiting releases once real backup catches up', function()
    local w = world() w:group() local a = w:ally(-1600) local b = w:ally(-2000)
    assert(w.env.GetDesire() > 1) w.env.OnStart() w.bot.mode = 19
    assert(w.jmz.IsRetreating(w.bot))
    a.location, b.location = vector(1050, 200), vector(1100, -200) w:advance()
    assert(w.env.GetDesire() == 0) w.env.OnEnd() w.bot.mode = 2
    assert(w.jmz.IsGoingOnSomeone(w.bot) and w.bot.ch1WaitingForBackup == nil)
end)
test('waiting bot backs away from nearby enemies rather than walking into them', function()
    local w = world() w:group(500) w.env.Think()
    assert(w.bot.destination.x < 0)
end)
test('bot outside enemy reach holds its position until backup arrives', function()
    local w = world() w:group(1300) w.env.Think()
    assert(distance(w.bot.destination, w.bot.location) == 0)
end)
test('impassable escape point does not issue a move order', function()
    local w = world() w:group(500) w.passable = false w.env.Think()
    assert(w.bot.destination == nil)
end)
test('illusions and unseen heroes do not invent an enemy group', function()
    local w = world() w.bot.target = w:enemy(500) w:enemy(600).illusion = true w:enemy(700).hidden = true
    assert(not w:risk().unsafe and w:risk().enemies == 1)
end)
test('duplicate heroes owned by one player do not inflate group size', function()
    local w = world() w.bot.target = w:enemy(500) w:enemy(600).id = w.bot.target.id
    assert(w:risk().enemies == 1)
end)
test('hidden or dead target and departed enemies release waiting', function()
    local w = world() w:group() assert(w:risk().unsafe)
    for _, e in ipairs(w.enemies) do e.hidden = true end w:advance()
    assert(not w:risk().unsafe and w.env.GetDesire() == 0)
end)
test('enemy lost during the cache interval cannot break the waiting move', function()
    local w = world() w:group(500) w.enemies[2].location = vector(520)
    assert(w:risk().unsafe)
    w.bot.target.hidden = true w.env.Think()
    assert(distance(w.bot.destination, w.bot.location) == 0)
end)
for _, state in ipairs({'channeling', 'casting', 'using'}) do
    test(state .. ' bot is not interrupted by the wait mode', function()
        local w = world() w:group() w.bot[state] = true
        assert(w.env.GetDesire() == 0) w.env.Think() assert(w.bot.destination == nil)
    end)
end
test('queued combos and low-health retreat are not interrupted by waiting', function()
    local w = world() w:group() w.bot.queued = 3 assert(w.env.GetDesire() == 0)
    w.bot.queued = 0 w.bot.hp = 200 assert(w.env.GetDesire() == 0)
    w.bot.hp = 1000 w.bot.mode = 1 assert(w.env.GetDesire() == 0)
end)
test('Rupture and forced combat do not trigger movement from the wait mode', function()
    local w = world() w:group()
    for _, modifier in ipairs({'modifier_bloodseeker_rupture', 'modifier_legion_commander_duel', 'modifier_axe_berserkers_call'}) do
        w.bot.modifiers[modifier] = true assert(w.env.GetDesire() == 0)
        w.env.Think() assert(w.bot.destination == nil) w.bot.modifiers[modifier] = nil
    end
end)

for _, consider in ipairs({'ConsiderBlinkRPSkewer', 'ConsiderBlinkForSkewer', 'ConsiderBlinkRP', 'ConsiderBlinkForHornTossSkewer'}) do
    test('Magnus ' .. consider .. ' waits before queueing and resumes with support', function()
        local w = world() w:group() local x = w:heroScript('magnataur')
        x[consider] = function() return 0.8 end
        x.SkillsComplement() assert(#w.casts == 0, 'unsafe initiation was queued')
        w:ally(-100) w:ally(-200) w:advance()
        x.SkillsComplement() assert(#w.casts > 0, 'supported initiation stayed blocked')
    end)
end
for _, consider in ipairs({'ConsiderChargeOfDarkness', 'ConsiderNetherStrike'}) do
    test('Spirit Breaker ' .. consider .. ' checks destination support', function()
        local w = world() w:group(6000) local x = w:heroScript('spirit_breaker')
        x[consider] = function() return 0.8, w.bot.target end
        x.SkillsComplement() assert(#w.casts == 0)
        w:ally(5900) w:ally(6100) w:advance()
        x.SkillsComplement() assert(#w.casts == 1)
    end)
end
test('team roam yields before its high-priority creep or hero attack paths', function()
    local w = world() w:group() w.env.dofile = function() return {} end
    loadIn('mode_team_roam_generic.lua', w.env)
    assert(w.env.GetDesire() == 0)
    w.env.Think() assert(w.bot.destination == nil)
end)

print(string.format('Engagement safety regression: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
