-- Check support at the fight, not in a large circle around the initiator.
local M = {}
local ENEMY_RADIUS = 900
local SUPPORT_RADIUS = 1100
local SUPPORT_ARRIVAL_TIME = 1.25

local function RealHero(unit)
    return unit ~= nil and not unit:IsNull() and unit:IsAlive()
        and unit:CanBeSeen() and unit:IsHero() and not unit:IsIllusion()
        and not unit:HasModifier('modifier_arc_warden_tempest_double')
end

local function ReadyAlly(unit, team)
    return RealHero(unit) and unit:GetTeam() == team
        and unit:GetHealth() / math.max(1, unit:GetMaxHealth()) >= 0.3
        and not unit:IsStunned() and not unit:IsHexed() and not unit:IsNightmared()
        and not unit:IsInvulnerable() and unit:GetActiveMode() ~= BOT_MODE_RETREAT
        and not (unit:IsDisarmed() and unit:IsSilenced())
        and not unit:HasModifier('modifier_teleporting')
        and not unit:HasModifier('modifier_necrolyte_reapers_scythe')
end

function M.Evaluate(bot, location)
    local result = {unsafe = false, enemies = 0, readyAllies = 1}
    if not RealHero(bot) or not bot:IsBot() then return result end
    local team = bot:GetTeam()
    local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    if location == nil then
        local target = bot:GetTarget() or bot:GetAttackTarget()
        if RealHero(target) and target:GetTeam() ~= team
            and GetUnitToUnitDistance(bot, target) <= 1800 then location = target:GetLocation() end
    end
    if location == nil then
        local nearestDistance = 1800
        for _, enemy in pairs(enemies) do
            if RealHero(enemy) then
                local distance = GetUnitToUnitDistance(bot, enemy)
                if distance < nearestDistance then location = enemy:GetLocation() nearestDistance = distance end
            end
        end
    end
    if location == nil then return result end

    local now = DotaTime()
    local cached = bot.ch1BackupEvaluation
    if cached ~= nil and now >= cached.time and now - cached.time < 0.2
        and math.abs(location.x - cached.location.x) < 70
        and math.abs(location.y - cached.location.y) < 70 then return cached.result end

    result.location = location
    local enemyIds = {}
    local nearestDistance = math.huge
    for _, enemy in pairs(enemies) do
        if RealHero(enemy) and enemy:GetTeam() ~= team
            and GetUnitToLocationDistance(enemy, location) <= ENEMY_RADIUS then
            local id = enemy:GetPlayerID()
            if not enemyIds[id] then result.enemies = result.enemies + 1 enemyIds[id] = true end
            local distance = GetUnitToUnitDistance(bot, enemy)
            if distance < nearestDistance then result.nearestEnemy = enemy nearestDistance = distance end
        end
    end

    if result.enemies >= 2 then
        local allyIds = {[bot:GetPlayerID()] = true}
        local botRange = math.min(800, math.max(250, bot:GetAttackRange() + 150))
        local botArrival = math.max(0, GetUnitToLocationDistance(bot, location) - botRange)
            / math.max(1, bot:GetCurrentMovementSpeed())
        for index = 1, #GetTeamPlayers(team) do
            local ally = GetTeamMember(index)
            if ally ~= bot and ReadyAlly(ally, team) and not allyIds[ally:GetPlayerID()] then
                local distance = GetUnitToLocationDistance(ally, location)
                local fightRange = math.min(800, math.max(250, ally:GetAttackRange() + 150))
                local ready = distance <= fightRange
                -- A gathered squad can advance together; otherwise all five bots
                -- could wait outside the fight forever, each waiting for the others.
                if not ready and GetUnitToUnitDistance(bot, ally) <= 600
                    and not ally:IsRooted() and not ally:IsChanneling()
                    and not ally:IsUsingAbility() and not ally:IsCastingAbility() then
                    local arrival = math.max(0, distance - fightRange) / math.max(1, ally:GetCurrentMovementSpeed())
                    ready = arrival <= botArrival + SUPPORT_ARRIVAL_TIME
                end
                if not ready and distance <= SUPPORT_RADIUS and not ally:IsRooted()
                    and not ally:IsChanneling() and not ally:IsUsingAbility()
                    and not ally:IsCastingAbility() and ally:IsFacingLocation(location, 60) then
                    local action = ally:GetCurrentActionType()
                    local target = ally:GetAttackTarget()
                    local joining = action == BOT_ACTION_TYPE_MOVE_TO or action == BOT_ACTION_TYPE_ATTACKMOVE
                        or (RealHero(target) and target:GetTeam() ~= team)
                    ready = joining and (distance - fightRange) / math.max(1, ally:GetCurrentMovementSpeed()) <= SUPPORT_ARRIVAL_TIME
                end
                if ready then result.readyAllies = result.readyAllies + 1 allyIds[ally:GetPlayerID()] = true end
            end
        end
        result.unsafe = result.readyAllies < result.enemies
    end
    bot.ch1BackupEvaluation = {time = now, location = location, result = result}
    return result
end

function M.WaitLocation(bot, risk)
    local location = bot:GetLocation()
    if not risk.unsafe or not RealHero(risk.nearestEnemy) then return location end
    local away = location - risk.nearestEnemy:GetLocation()
    local distance = away:Length2D()
    if distance >= 1100 then return location end
    if distance < 1 then away = GetAncient(bot:GetTeam()):GetLocation() - location end
    return location + away:Normalized() * 450
end

return M
