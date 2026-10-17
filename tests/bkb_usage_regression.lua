-- Run from the repository root: lua tests/bkb_usage_regression.lua [bots-directory]
local sourceRoot = (arg and arg[1]) or 'bots'
local passed, failed = 0, 0
local function test(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1 print('PASS ' .. name)
    else failed = failed + 1 print('FAIL ' .. name .. ': ' .. tostring(err)) end
end

local function world()
    local w = {now = 100, enemies = 0, modifiers = {}, items = {}, casts = {}, going = false}
    local bot = {lastItemFrameProcessTime = 0}
    function bot:GetUnitName() return 'npc_dota_hero_axe' end
    function bot:IsInvulnerable() return w.invulnerable or false end
    function bot:IsHero() return true end
    function bot:IsIllusion() return false end
    function bot:IsAlive() return not w.dead end
    function bot:IsMuted() return w.muted or false end
    function bot:IsHexed() return w.hexed or false end
    function bot:IsStunned() return w.stunned or false end
    function bot:IsChanneling() return w.channeling or false end
    function bot:IsUsingAbility() return w.using or false end
    function bot:IsCastingAbility() return w.casting or false end
    function bot:IsInvisible() return w.invisible or false end
    function bot:IsMagicImmune() return w.immune or false end
    function bot:IsRooted() return w.rooted or false end
    function bot:IsSilenced() return w.silenced or false end
    function bot:NumQueuedActions() return w.queued or 0 end
    function bot:HasModifier(name) return w.modifiers[name] or false end
    function bot:GetMana() return 500 end
    function bot:GetItemInSlot(slot) return w.items[slot] end
    function bot:GetLocation() return {x = 0, y = 0, z = 0} end
    function bot:GetNearbyTowers() return {} end
    function bot:GetActiveMode() return w.mode or 0 end
    function bot:WasRecentlyDamagedByAnyHero() return w.damaged or false end
    function bot:Action_UseAbility(item) table.insert(w.casts, item:GetName()) end
    function bot:Action_UseAbilityOnLocation(item) self:Action_UseAbility(item) end
    local jmz = {
        IsStaleARDMHero = function() return false, bot, bot:GetUnitName() end,
        GetNearbyHeroes = function() return w.enemies > 0 and {w.target or {}} or {} end,
        GetProperTarget = function() return w.target end,
        GetEnemyCount = function() return w.enemies end,
        IsGoingOnSomeone = function() return w.going end,
        IsRetreating = function() return w.retreating or false end,
        IsValidHero = function(t) return t ~= nil and t.hero end,
        IsSuspiciousIllusion = function(t) return t.illusion or false end,
        IsInRange = function(_, t, radius) return t.distance <= radius end,
        IsNotAttackProjectileIncoming = function() return w.projectile or false end,
        IsWillBeCastUnitTargetSpell = function() return w.unitSpell or false end,
        IsWillBeCastPointSpell = function() return w.pointSpell or false end,
        IsItemAvailable = function() return nil end,
        IsNoItemIllution = function() return false end,
        CanCastAbility = function(item) return item ~= nil and item.ready end,
        SetReportMotive = function() end,
        Item = {IsSpecifiedItem = function() return false end},
    }
    local env = setmetatable({
        GetBot = function() return bot end,
        GetTeam = function() return 2 end,
        GetScriptDirectory = function() return 'bots' end,
        DotaTime = function() return w.now end,
        Vector = function(x, y, z) return {x = x, y = y, z = z} end,
        RandomInt = function(a) return a end,
        BOT_MODE_NONE = 0, BOT_ACTION_DESIRE_NONE = 0, BOT_ACTION_DESIRE_HIGH = 0.8,
        dofile = function() return {} end,
        require = function(path)
            if path == 'bots/FunLib/jmz_func' then return jmz end
            if path == 'bots/Customize/general' then return {Enable = true, ThinkLess = 1} end
            return {}
        end,
    }, {__index = _G})
    local chunk, err
    if setfenv then
        chunk, err = loadfile(sourceRoot .. '/ability_item_usage_generic.lua')
        if chunk then setfenv(chunk, env) end
    else chunk, err = loadfile(sourceRoot .. '/ability_item_usage_generic.lua', 't', env) end
    assert(chunk, err)
    w.x, w.bot = chunk(), bot
    function w:item(name, slot, ready)
        local item = {ready = ready ~= false}
        function item:GetName() return name end
        self.items[slot] = item
        return item
    end
    w.bkb = w:item('item_black_king_bar', 0)
    function w:think() self.x.ItemUsageThink() end
    function w:expectBkb() self:think() assert(self.casts[1] == 'item_black_king_bar', 'ready BKB was not used') end
    function w:expectNoCast() self:think() assert(#self.casts == 0, 'an item was used unexpectedly') end
    return w
end

test('pushing bot responds to an incoming spell projectile', function()
    local w = world() w.mode = 9 w.projectile = true w.enemies = 1 w:expectBkb()
end)
test('projectile defense does not require the caster to remain visible nearby', function()
    local w = world() w.projectile = true w:expectBkb()
end)
test('ground-ping movement responds to a targeted spell outside melee range', function()
    local w = world() w.mode = 14 w.unitSpell = true w.enemies = 1 w:expectBkb()
end)
test('tower defense responds to an area spell without attack mode', function()
    local w = world() w.mode = 12 w.pointSpell = true w.enemies = 1 w:expectBkb()
end)
test('Lotus reflection does not suppress BKB in a fight', function()
    local w = world() w.enemies = 3 w.going = true w.unitSpell = true
    w.modifiers.modifier_item_lotus_orb_active = true w:expectBkb()
end)
test('spell shield does not suppress BKB against area spells', function()
    local w = world() w.enemies = 3 w.going = true w.pointSpell = true
    w.modifiers.modifier_antimage_spell_shield = true w:expectBkb()
end)
test('close engagement against two real enemies activates BKB', function()
    local w = world() w.enemies = 2 w.going = true w.target = {hero = true, distance = 700} w:expectBkb()
end)
test('recent damage from a group activates BKB even while farming', function()
    local w = world() w.enemies = 2 w.damaged = true w:expectBkb()
end)
test('uncontested travel does not consume BKB', function() world():expectNoCast() end)
test('nearby enemies without commitment or damage do not consume BKB', function()
    local w = world() w.enemies = 3 w:expectNoCast()
end)
test('a distant target does not consume BKB during approach', function()
    local w = world() w.enemies = 2 w.going = true w.target = {hero = true, distance = 1400} w:expectNoCast()
end)
test('an illusion target does not cause proactive BKB', function()
    local w = world() w.enemies = 2 w.going = true w.target = {hero = true, distance = 300, illusion = true} w:expectNoCast()
end)
test('root can be dispelled during defense with a nearby enemy', function()
    local w = world() w.enemies = 1 w.rooted = true w:expectBkb()
end)
test('Mask of Madness silence alone does not consume BKB', function()
    local w = world() w.enemies = 2 w.silenced = true
    w.modifiers.modifier_item_mask_of_madness_berserk = true w:expectNoCast()
end)
test('BKB wins over ordinary items in every inventory position', function()
    for bkbSlot = 0, 5 do
        local w = world() w.projectile = true w.enemies = 1 w.going = true
        for slot = 0, 5 do w:item('item_test_offense', slot) end
        w.items[bkbSlot] = w.bkb
        w.x.ConsiderItemDesire.item_test_offense = function() return 0.8, nil, 'none' end
        w:expectBkb() assert(#w.casts == 1, 'multiple actions were issued in one think')
    end
end)
test('an ordinary item still runs when BKB has no reason to activate', function()
    local w = world() w:item('item_test_offense', 5)
    w.x.ConsiderItemDesire.item_test_offense = function() return 0.8, nil, 'none' end
    w:think() assert(w.casts[1] == 'item_test_offense')
end)
test('BKB on cooldown does not block other items', function()
    local w = world() w.bkb.ready = false w.projectile = true w:item('item_test_offense', 5)
    w.x.ConsiderItemDesire.item_test_offense = function() return 0.8, nil, 'none' end
    w:think() assert(w.casts[1] == 'item_test_offense')
end)
test('BKB in the backpack is not cast', function()
    local w = world() w.items[0] = nil w.items[6] = w.bkb w.projectile = true w:expectNoCast()
end)
test('recently swapped BKB keeps the inventory cooldown guard', function()
    local w = world() w.items[0] = nil w.items[6] = w.bkb w:think()
    w.items[6] = nil w.items[0] = w.bkb w.projectile = true w.now = w.now + 0.3 w:expectNoCast()
    w.now = w.now + 6.1 w:expectBkb()
end)
for _, condition in ipairs({'dead', 'muted', 'hexed', 'stunned', 'channeling', 'using', 'casting', 'invisible', 'immune'}) do
    test(condition .. ' bot does not interrupt its state to use BKB', function()
        local w = world() w[condition] = true w.projectile = true w:expectNoCast()
    end)
end
test('queued ability combos are preserved', function()
    local w = world() w.queued = 2 w.projectile = true w:expectNoCast()
end)
test('Dazzle projection does not consume BKB', function()
    local w = world() w.modifiers.modifier_dazzle_nothl_projection_soul_debuff = true
    w.projectile = true w:expectNoCast()
end)

print(string.format('BKB usage regression: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
