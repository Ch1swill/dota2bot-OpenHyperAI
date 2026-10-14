local bot = GetBot()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not string.find(bot:GetUnitName(), "hero") or bot:IsIllusion() then return end

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )

local PING_RECENCY = 8        -- respond to pings within this many seconds
local ANNOUNCE_COOLDOWN = 5
local ASSEMBLE_DESIRE = BOT_MODE_DESIRE_ABSOLUTE
local ARRIVE_RADIUS = 500      -- close enough to ping location

local assembleLoc = nil
local lastPingTime = -math.huge

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
		if latestPing.normal_ping then
			assembleLoc = latestPing.location
			if bot:IsAlive() and GetUnitToLocationDistance(bot, assembleLoc) > ARRIVE_RADIUS then
				J.ModeAnnounce(bot, 'say_assemble', ANNOUNCE_COOLDOWN)
			end
		end
	end
end

function GetDesire()
	UpdateAssembleOrder()
	if not bot:IsAlive() or assembleLoc == nil then return BOT_MODE_DESIRE_NONE end

	if GetUnitToLocationDistance(bot, assembleLoc) <= ARRIVE_RADIUS then
		assembleLoc = nil
		return BOT_MODE_DESIRE_NONE
	end

	-- A ground-ping order stays active across the map until arrival or a new ping.
	return ASSEMBLE_DESIRE
end

function OnEnd()
	-- Keep the destination when another mode temporarily interrupts the journey.
end

function Think()
	if J.CanNotUseAction(bot) then return end
	if assembleLoc == nil then return end

	local dist = GetUnitToLocationDistance(bot, assembleLoc)
	if dist <= ARRIVE_RADIUS then
		assembleLoc = nil
		return
	end

	bot:Action_MoveToLocation(assembleLoc)
end
