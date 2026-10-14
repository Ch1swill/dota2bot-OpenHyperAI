local bot = GetBot()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not string.find(bot:GetUnitName(), "hero") or bot:IsIllusion() then return end

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )

local PING_RECENCY = 8        -- respond to pings within this many seconds
local ANNOUNCE_COOLDOWN = 5
local ASSEMBLE_DESIRE = BOT_MODE_DESIRE_ABSOLUTE
local ARRIVE_RADIUS = 500      -- close enough to ping location
local TARGET_RADIUS = 250
local ROSHAN_PIT_RADIUS = 600
local DEFEND_RADIUS = 1600
local DEFEND_QUIET_TIME = 15
local FOG_SEARCH_TIME = 8
local BLOCKED_WAIT_TIME = 20

local order = nil
local lastPingTime = -math.huge

local function IsAliveUnit(unit)
	return unit ~= nil and not unit:IsNull() and unit:IsAlive()
end

local function ClearOrder()
	if order ~= nil and order.combatTarget ~= nil and bot:GetTarget() == order.combatTarget then
		bot:SetTarget(nil)
	end
	order = nil
	bot.humanPingMode = nil
end

local function ResolvePing(ping)
	local nearest = nil
	local nearestKind = nil
	local nearestDistance = TARGET_RADIUS
	local function Consider(unit, kind, knownLocation)
		if IsAliveUnit(unit) and (knownLocation or unit:CanBeSeen()) then
			local distance = J.GetDistance(unit:GetLocation(), ping.location)
			if distance <= nearestDistance then
				nearest, nearestKind, nearestDistance = unit, kind, distance
			end
		end
	end

	for _, unit in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if IsAliveUnit(unit) and unit:IsHero() and not J.IsSuspiciousIllusion(unit) then Consider(unit, 'attack') end
	end
	for _, unit in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if IsAliveUnit(unit) and unit:IsHero() and not J.IsSuspiciousIllusion(unit) then Consider(unit, 'defend') end
	end
	for _, unit in ipairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)) do
		if IsAliveUnit(unit) and unit:IsBuilding() then Consider(unit, 'push') end
	end
	for _, unit in ipairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS)) do
		if IsAliveUnit(unit) and unit:IsBuilding() then Consider(unit, 'defend') end
	end
	-- Tower positions are public and static, even while they are in fog or invulnerable.
	for _, towerId in ipairs({TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3,
		TOWER_MID_1, TOWER_MID_2, TOWER_MID_3, TOWER_BOT_1, TOWER_BOT_2,
		TOWER_BOT_3, TOWER_BASE_1, TOWER_BASE_2}) do
		Consider(GetTower(GetOpposingTeam(), towerId), 'push', true)
		Consider(GetTower(GetTeam(), towerId), 'defend', true)
	end
	for _, unit in ipairs(GetUnitList(UNIT_LIST_NEUTRAL_CREEPS)) do
		if J.IsRoshan(unit) then Consider(unit, 'roshan') end
	end
	if nearest ~= nil then
		return {kind = nearestKind, target = nearest, location = nearest:GetLocation()}
	end

	-- A pit ping can request Roshan before the team has vision of the unit.
	if J.GetDistance(J.GetCurrentRoshanLocation(), ping.location) <= ROSHAN_PIT_RADIUS then
		return {kind = 'roshan', location = J.GetCurrentRoshanLocation(), nextScan = 0}
	end
	if ping.normal_ping then return {kind = 'gather', location = ping.location} end
	return nil
end

local function UpdateAssembleOrder()
	-- Read all allied humans: GetHumanPing() only returns the first human slot.
	local latestPing = nil
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(i)
		if member ~= nil and not member:IsBot() then
			local ping = member:GetMostRecentPing()
			if ping ~= nil and ping.time ~= 0 and ping.location ~= nil then
				local age = GameTime() - ping.time
				if age >= 0 and age < PING_RECENCY
				and (latestPing == nil or ping.time > latestPing.time) then
					latestPing = ping
				end
			end
		end
	end

	if latestPing ~= nil and latestPing.time > lastPingTime then
		lastPingTime = latestPing.time
		local newOrder = ResolvePing(latestPing)
		if newOrder ~= nil then
			ClearOrder()
			order = newOrder
			bot.humanPingMode = order.kind
			if bot:IsAlive() then
				J.ModeAnnounce(bot, order.kind == 'roshan' and 'say_roshan' or 'say_assemble', ANNOUNCE_COOLDOWN)
			end
		end
	end
end

local function FindDefenseTarget()
	local nearest = nil
	local nearestDistance = math.huge
	for _, enemy in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
		if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) and J.CanBeAttacked(enemy)
		and GetUnitToLocationDistance(enemy, order.location) <= DEFEND_RADIUS then
			local distance = GetUnitToLocationDistance(enemy, order.location)
			if distance < nearestDistance then nearest, nearestDistance = enemy, distance end
		end
	end
	if nearest ~= nil then return nearest end
	for _, creep in ipairs(bot:GetNearbyLaneCreeps(1600, true)) do
		if J.CanBeAttacked(creep) and GetUnitToLocationDistance(creep, order.location) <= DEFEND_RADIUS then
			local distance = GetUnitToLocationDistance(creep, order.location)
			if distance < nearestDistance then nearest, nearestDistance = creep, distance end
		end
	end
	return nearest
end

local function UpdateOrderState()
	if order == nil then return end
	if order.target ~= nil then
		if not IsAliveUnit(order.target) then ClearOrder() return end
		-- Never follow a hidden enemy's live coordinates.
		if order.target:CanBeSeen() then
			order.location = order.target:GetLocation()
			order.fogArrivedAt = nil
		elseif GetUnitToLocationDistance(bot, order.location) <= ARRIVE_RADIUS then
			order.fogArrivedAt = order.fogArrivedAt or GameTime()
			if GameTime() - order.fogArrivedAt >= FOG_SEARCH_TIME then ClearOrder() return end
		end
	end

	if order.kind == 'roshan' and order.target == nil then
		if GameTime() >= (order.nextScan or 0) then
			order.nextScan = GameTime() + 0.5
			for _, unit in ipairs(GetUnitList(UNIT_LIST_NEUTRAL_CREEPS)) do
				if J.IsRoshan(unit) and GetUnitToLocationDistance(unit, order.location) <= 1200 then
					order.target = unit
					order.location = unit:GetLocation()
					break
				end
			end
			if order.target == nil and IsLocationVisible(order.location) then ClearOrder() return end
		end
	end

	local distance = GetUnitToLocationDistance(bot, order.location)
	if order.kind == 'gather' and distance <= ARRIVE_RADIUS then ClearOrder() return end
	if order.kind == 'defend' then order.defenseTarget = nil end
	if order.kind == 'defend' and bot:IsAlive() and distance <= DEFEND_RADIUS then
		order.defenseTarget = FindDefenseTarget()
		if order.defenseTarget ~= nil then order.lastThreatAt = GameTime() end
		if distance <= ARRIVE_RADIUS then
			order.arrivedAt = order.arrivedAt or GameTime()
			if GameTime() - (order.lastThreatAt or order.arrivedAt) >= DEFEND_QUIET_TIME then
				ClearOrder()
			end
		end
	end
end

function GetDesire()
	UpdateAssembleOrder()
	if not bot:IsAlive() then return BOT_MODE_DESIRE_NONE end
	UpdateOrderState()
	if order == nil then return BOT_MODE_DESIRE_NONE end

	-- Human orders stay active across the map, including when their ping expires.
	return ASSEMBLE_DESIRE
end

function OnEnd()
	-- Keep the destination when another mode temporarily interrupts the journey.
end

function Think()
	if J.CanNotUseAction(bot) then return end
	UpdateOrderState()
	if order == nil then return end

	local target = order.target
	if order.kind == 'defend' then target = order.defenseTarget end
	local backdoored = order.kind == 'push' and target ~= nil
		and (target:HasModifier('modifier_backdoor_protection')
			or target:HasModifier('modifier_backdoor_protection_in_base')
			or target:HasModifier('modifier_backdoor_protection_active'))
	if target ~= nil and J.CanBeAttacked(target) and not backdoored then
		order.blockedAt = nil
		order.combatTarget = target
		bot:SetTarget(target)
		bot:Action_AttackUnit(target, true)
		return
	end

	-- Clear a previous combat target when the enemy disappears or defense switches.
	if order.combatTarget ~= nil and bot:GetTarget() == order.combatTarget then bot:SetTarget(nil) end
	order.combatTarget = nil
	if order.kind == 'push' then
		for _, creep in ipairs(bot:GetNearbyLaneCreeps(1600, true)) do
			if J.CanBeAttacked(creep) and GetUnitToLocationDistance(creep, order.location) <= DEFEND_RADIUS then
				order.blockedAt = nil
				bot:SetTarget(creep)
				order.combatTarget = creep
				bot:Action_AttackUnit(creep, true)
				return
			end
		end
	end
	if target ~= nil and target:CanBeSeen() and GetUnitToLocationDistance(bot, order.location) <= 1200 then
		order.blockedAt = order.blockedAt or GameTime()
		if GameTime() - order.blockedAt >= BLOCKED_WAIT_TIME then ClearOrder() return end
	else
		order.blockedAt = nil
	end
	bot:Action_MoveToLocation(order.location)
end
