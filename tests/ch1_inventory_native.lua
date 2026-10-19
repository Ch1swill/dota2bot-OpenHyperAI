-- Manual native test: copy into the addon as ch1_inventory/native_test.lua, then
-- script_reload_code ch1_inventory/native_test after a human picks a hero.
-- Destructive fixture: replaces test hero inventory and kills/respawns that hero.
if Ch1BackpackProbe then return end
Ch1BackpackProbe = {step=0,ticks=0}
local p=Ch1BackpackProbe
local function trace(s) print('[Ch1BackpackProbe] ' .. s) end
local function place(hero,name,slot)
    local old=hero:GetItemInSlot(slot)
    if old then hero:RemoveItem(old) end
    local item=hero:AddItemByName(name)
    for i=0,16 do if hero:GetItemInSlot(i)==item then if i~=slot then hero:SwapItems(i,slot) end break end end
    assert(hero:GetItemInSlot(slot)==item, 'could not place '..name)
    return item
end
local thinker=SpawnEntityFromTableSynchronous('info_target',{targetname='ch1_backpack_full_probe'})
trace('full fixture loaded')
thinker:SetContextThink('Ch1BackpackProbe',function()
    local ok,err=pcall(function()
        p.ticks=p.ticks+1
        local hero=PlayerResource:GetSelectedHeroEntity(0)
        if hero==nil then assert(p.ticks<100,'human hero never selected') return end
        if not hero:HasModifier('modifier_ch1_human_backpack') then
            assert(p.ticks<100,'custom addon did not enable the human backpack') return
        end
        p.step=p.step+1
        if p.step==1 then
            p.hero=hero
            trace('auto-enabled human='..hero:GetUnitName()..' fake='..tostring(PlayerResource:IsFakeClient(0)))
            p.bots=0
            for team=2,3 do
                for i=0,PlayerResource:GetPlayerCountForTeam(team)-1 do
                    local id=PlayerResource:GetNthPlayerIDOnTeam(team,i)
                    local other=PlayerResource:GetSelectedHeroEntity(id)
                    if PlayerResource:IsFakeClient(id) and other then
                        p.bots=p.bots+1
                        assert(not other:HasModifier('modifier_ch1_human_backpack'),'bot received nine slots')
                    end
                end
            end
            assert(p.bots>0,'bot exclusion not exercised')
            trace('excluded bots='..p.bots)
            for slot=0,16 do local item=hero:GetItemInSlot(slot) if item then hero:RemoveItem(item) end end
            for i=0,5 do place(hero,'item_branches',i) end
            p.baseInt=hero:GetBaseIntellect()+6
            p.reaver=place(hero,'item_reaver',6)
            p.phase=place(hero,'item_phase_boots',7)
            p.staff=place(hero,'item_mystic_staff',8)
        elseif p.step==3 then
            trace('nine-slot intellect='..hero:GetIntellect(false)..' expected='..(p.baseInt+25))
            assert(hero:GetIntellect(false)==p.baseInt+25,'backpack passive absent')
            p.phase:EndCooldown() hero:CastAbilityNoTarget(p.phase,0)
        elseif p.step==5 then
            assert(hero:HasModifier('modifier_item_phase_boots_active'),'slot 7 phase boots did not cast')
            trace('slot7 phase boots cast')
            hero:SwapItems(8,0)
        elseif p.step==7 then
            trace('after swap intellect='..hero:GetIntellect(false)..' expected='..(p.baseInt+25))
            assert(hero:GetIntellect(false)==p.baseInt+25,'swap duplicates or loses item attributes')
            hero:RemoveItem(p.staff)
        elseif p.step==9 then
            assert(hero:GetIntellect(false)==p.baseInt,'sold item leaves attributes behind')
            trace('sold passive removed')
            p.ghost=place(hero,'item_ghost',6)
            p.bkb=place(hero,'item_black_king_bar',8)
        elseif p.step==11 then
            p.ghost:EndCooldown() hero:CastAbilityNoTarget(p.ghost,0)
        elseif p.step==13 then
            assert(hero:HasModifier('modifier_ghost_state'),'slot 6 ghost scepter did not cast')
            trace('slot6 ghost scepter cast')
            p.bkb:EndCooldown() hero:CastAbilityNoTarget(p.bkb,0)
        elseif p.step==15 then
            assert(hero:HasModifier('modifier_black_king_bar_immune'),'slot 8 BKB did not cast')
            trace('slot8 BKB cast')
            p.manager=hero:FindModifierByName('modifier_ch1_human_backpack')
            hero:ForceKill(false)
        elseif p.step==17 then
            assert(hero:HasModifier('modifier_ch1_human_backpack'),'death removes backpack permission')
            hero:RespawnHero(false,false)
        elseif p.step==19 then
            assert(hero:IsAlive() and hero:HasModifier('modifier_ch1_human_backpack'),'respawn loses backpack permission')
            assert(not p.manager:IsNull(),'respawn replaced persistent modifier')
            trace('PASS native addon integration: human-only, three active backpack slots, attributes, swap, sale, death and respawn')
            UTIL_Remove(thinker)
        end
    end)
    if not ok then trace('FAIL '..tostring(err)) UTIL_Remove(thinker) return nil end
    if p.step>=19 then return nil end
    return 0.5
end,0.5)
