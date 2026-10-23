local bot = GetBot()
if bot == nil or not bot:IsHero() or bot:IsIllusion() then return end
local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

local function CanWait()
    return bot:IsAlive() and not bot:IsInvulnerable() and not bot:IsChanneling()
        and not bot:IsUsingAbility() and not bot:IsCastingAbility() and bot:NumQueuedActions() == 0
        and bot:GetHealth() / math.max(1, bot:GetMaxHealth()) >= 0.35
        and bot:GetActiveMode() ~= BOT_MODE_RETREAT
        and not bot:HasModifier('modifier_bloodseeker_rupture')
        and not bot:HasModifier('modifier_legion_commander_duel')
        and not bot:HasModifier('modifier_axe_berserkers_call')
        and not bot:HasModifier('modifier_winter_wyvern_winters_curse')
end

function GetDesire()
    if not CanWait() then return BOT_MODE_DESIRE_NONE end
    if J.Engagement.Evaluate(bot).unsafe then return BOT_MODE_DESIRE_ABSOLUTE + 0.05 end
    return BOT_MODE_DESIRE_NONE
end

function OnStart()
    bot.ch1WaitingForBackup = true
    if CanWait() then bot:Action_ClearActions(false) end
end
function OnEnd() bot.ch1WaitingForBackup = nil end

function Think()
    if not CanWait() or J.CanNotUseAction(bot) then return end
    local risk = J.Engagement.Evaluate(bot)
    if not risk.unsafe then return end
    local location = J.Engagement.WaitLocation(bot, risk)
    if IsLocationPassable(location) then bot:Action_MoveToLocation(location)
    else bot:Action_ClearActions(false) end
end
