local M={}

-- Keep the fake client's own controller, without the custom-game all-player flag.
function M.ConfigureHero(hero, playerID)
    hero:SetControllableByAllPlayers(false)
    -- The second argument skips position adjustment; it is not an allow/deny flag.
    -- Adding the bot owner alone leaves any previous human controller bits intact.
    hero:SetControllableByPlayer(-1, true)
    hero:SetControllableByPlayer(playerID, true)
end

function M.AllowOrder(order)
    if not GameRules.Ch1InventoryLabActive then return true end
    -- Team actions and ability pings do not command the inspected unit.
    if order.order_type~=nil and (order.order_type==DOTA_UNIT_ORDER_GLYPH
        or order.order_type==DOTA_UNIT_ORDER_RADAR
        or order.order_type==DOTA_UNIT_ORDER_PING_ABILITY) then return true end
    local issuer=tonumber(order.issuer_player_id_const)
    -- AI and server-generated orders must continue to run normally.
    if issuer==nil or not PlayerResource:IsValidPlayerID(issuer)
        or PlayerResource:IsFakeClient(issuer) then return true end
    for _,index in pairs(order.units or {}) do
        local unit=EntIndexToHScript(tonumber(index))
        if unit~=nil and not unit:IsNull() then
            local owner=unit:GetPlayerOwnerID()
            if PlayerResource:IsValidPlayerID(owner) and PlayerResource:IsFakeClient(owner) then
                return false
            end
        end
    end
    return true
end

return M
