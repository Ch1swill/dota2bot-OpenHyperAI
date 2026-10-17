-- Runs in the local server VScript VM, rather than the restricted bot VM.
local M = {}
if type(IsServer) ~= 'function' or not IsServer()
or (type(IsDedicatedServer) == 'function' and IsDedicatedServer())
or type(ListenToGameEvent) ~= 'function' or type(SendToServerConsole) ~= 'function' then
	return M
end

local state = _G.Ch1FretBotsAutostart
if state == nil then
	state = {listeners = {}, sent = false, stopped = false}
	_G.Ch1FretBotsAutostart = state
end
if state.sent or state.stopped then return M end

local function Stop()
	for _, listener in ipairs(state.listeners) do
		if type(StopListeningToGameEvent) == 'function' then StopListeningToGameEvent(listener) end
	end
	state.listeners = {}
	state.stopped = true
end

local function HasBots()
	if PlayerResource == nil then return false end
	-- Use the same bot Steam-ID convention as FretBots/DataTables.lua.
	local botSteamId = PlayerResource:GetSteamID(100)
	for team = DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS do
		for index = 0, PlayerResource:GetPlayerCountForTeam(team) - 1 do
			local id = PlayerResource:GetNthPlayerIDOnTeam(team, index)
			if id ~= nil and id >= 0 and PlayerResource:GetSteamID(id) == botSteamId then return true end
		end
	end
	return false
end

local function IsEnabled()
	if GetScriptDirectory == nil then GetScriptDirectory = function() return 'bots' end end
	local ok, customize = pcall(require, 'bots.FunLib.custom_loader')
	if not ok then
		print('[OHA.Ch1] FretBots autostart could not load bot settings: ' .. tostring(customize))
		return false
	end
	return customize.Fretbots == nil or customize.Fretbots.Auto_Start ~= false
end

local TryStart
local function StartPolling()
	if state.polling or type(SpawnEntityFromTableSynchronous) ~= 'function' then return end
	-- Standard Dota games have no custom-game mode entity. Use the same independent
	-- info_target thinker as FretBots/Timers.lua, after the map reaches hero selection.
	local entity = SpawnEntityFromTableSynchronous('info_target', {targetname = 'ch1_fretbots_autostart_thinker'})
	if entity == nil or type(entity.SetContextThink) ~= 'function' then return end
	state.polling = true
	entity:SetContextThink('Ch1FretBotsAutostart', function()
		if not state.sent and not state.stopped then TryStart() end
		if state.sent or state.stopped then
			state.polling = false
			if type(UTIL_Remove) == 'function' then UTIL_Remove(entity) end
			return nil
		end
		return 0.5
	end, 0.5)
end

TryStart = function()
	if state.sent or state.stopped or GameRules == nil then return end
	local gameState = GameRules:State_Get()
	-- State IDs are not chronological: map loading and player draft use larger IDs.
	if gameState == DOTA_GAMERULES_STATE_POST_GAME
	or gameState == DOTA_GAMERULES_STATE_DISCONNECT then Stop() return end
	-- Bot slots can be added after both hero selection and the first hero-spawn event.
	-- Those inserts do not reliably produce another event; keep checking until ready.
	if gameState < DOTA_GAMERULES_STATE_HERO_SELECTION then return end
	if gameState == DOTA_GAMERULES_STATE_PLAYER_DRAFT then return end
	-- GC-created local lobbies keep the "start" host map while streaming Dota.
	-- Direct console games use "dota"; both are standard bot-game entry points.
	if type(GetMapName) == 'function' then
		local map = GetMapName()
		if map ~= 'dota' and map ~= 'start' then Stop() return end
	end
	if Flags ~= nil and Flags.isFretBotsInitialized then state.sent = true Stop() return end
	StartPolling()
	if not HasBots() then return end
	if not IsEnabled() then Stop() return end

	-- Latch before dispatch: console processing or a script reload can be reentrant.
	state.sent = true
	local ok, err = pcall(SendToServerConsole, 'sv_cheats 1; script_reload_code bots/fretbots')
	if ok then
		print('[OHA.Ch1] Starting FretBots automatically for this local bot game.')
		Stop()
	else
		state.sent = false
		if not state.failureLogged then
			print('[OHA.Ch1] FretBots autostart dispatch failed: ' .. tostring(err))
			state.failureLogged = true
		end
	end
end

if #state.listeners == 0 then
	table.insert(state.listeners, ListenToGameEvent('game_rules_state_change', TryStart, nil))
	-- Player slots may not be populated at the first hero-selection state event.
	table.insert(state.listeners, ListenToGameEvent('dota_on_hero_finish_spawn', TryStart, nil))
end
TryStart()
return M
