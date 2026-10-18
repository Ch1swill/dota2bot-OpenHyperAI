-- Run: lua tests/human_backpack_regression.lua [bots-directory]
local root = (arg and arg[1]) or 'bots'
local passed, failed = 0, 0
local function test(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1 print('PASS ' .. name)
    else failed = failed + 1 print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function load(path, env)
    if setfenv then local chunk = assert(loadfile(path)) setfenv(chunk, env) return chunk() end
    return assert(loadfile(path, 't', env))()
end
local function world(options)
    local opt = options or {}
    local w = {heroes={}, links=0, calculations=0, state=5, customize=opt.customize or {Enable=true}}
    local env = setmetatable({
        IsServer=function() return opt.server ~= false end,
        IsDedicatedServer=function() return opt.dedicated or false end,
        GetMapName=function() return opt.map or 'dota' end,
        MODIFIER_STATE_CAN_USE_BACKPACK_ITEMS=opt.unsupported and nil or 60,
        MODIFIER_ATTRIBUTE_MULTIPLE=2, LUA_MODIFIER_MOTION_NONE=0,
        DOTA_TEAM_GOODGUYS=2, DOTA_TEAM_BADGUYS=3,
        DOTA_GAMERULES_STATE_POST_GAME=8, DOTA_GAMERULES_STATE_DISCONNECT=9,
        bit={band=function(a,b) return a == b and a or 0 end},
        class=function(t) return t end,
        print=function() end,
        GameRules={State_Get=function() return w.state end},
        LinkLuaModifier=function(_,path)
            assert(loadfile(root .. '/' .. path:sub(6)), 'linked modifier file cannot be loaded')
            w.links=w.links+1
        end,
        SpawnEntityFromTableSynchronous=function()
            local t = {SetContextThink=function(self, _, callback) self.tick=callback end}
            w.thinker=t return t
        end,
        UTIL_Remove=function(e) e.removed=true end,
    }, {__index=_G})
    if opt.unsupported then env.MODIFIER_STATE_CAN_USE_BACKPACK_ITEMS=nil end
    env._G=env
    env.PlayerResource={
        IsValidPlayerID=function(_,id) return w.heroes[id] ~= nil end,
        IsFakeClient=function(_,id) return w.heroes[id].fake end,
        GetSelectedHeroEntity=function(_,id) return w.heroes[id] end,
        GetPlayerCountForTeam=function(_,team)
            local n=0 for _,h in pairs(w.heroes) do if h.team==team then n=n+1 end end return n
        end,
        GetNthPlayerIDOnTeam=function(_,team,index)
            local ids={} for id,h in pairs(w.heroes) do if h.team==team then table.insert(ids,id) end end
            table.sort(ids) return ids[index+1]
        end,
    }
    env.require=function() return w.customize end
    local manager=load(root .. '/FretBots/HumanBackpack.lua',env)
    env.require=function() return manager end
    load(root .. '/FretBots/modifiers/modifier_ch1_human_backpack.lua',env)
    env.require=function() return w.customize end
    w.env,w.manager=env,manager
    function w:hero(id,fake,team)
        local h={id=id,fake=fake or false,team=team or 2,real=true,slots={},modifiers={}}
        function h:IsNull() return self.null or false end
        function h:IsRealHero() return self.real end
        function h:IsIllusion() return self.illusion or false end
        function h:GetPlayerOwnerID() return self.id end
        function h:GetTeamNumber() return self.team end
        function h:GetItemInSlot(slot) return self.slots[slot] end
        function h:FindAllModifiersByName(name)
            local found={}
            for _,m in ipairs(self.modifiers) do if not m.null and m.name==name then table.insert(found,m) end end
            return found
        end
        function h:HasModifier(name) return #self:FindAllModifiersByName(name)>0 end
        function h:CalculateStatBonus() w.calculations=w.calculations+1 end
        function h:AddNewModifier(_,item,name)
            local m={name=name,item=item,hero=self}
            function m:IsNull() return self.null or false end
            function m:GetAbility() return self.item end
            function m:GetAttributes() return self.item and self.item.attributes or 0 end
            function m:GetParent() return self.hero end
            function m:StartIntervalThink(interval) self.interval=interval end
            function m:Destroy()
                if self.null then return end
                self.null=true
                if self.OnDestroy then self:OnDestroy() end
            end
            if name==manager.modifierName then setmetatable(m,{__index=env.modifier_ch1_human_backpack}) end
            table.insert(self.modifiers,m)
            if m.OnCreated then m:OnCreated() end
            return m
        end
        w.heroes[id]=h return h
    end
    function w:item(hero,slot,name,attributes)
        local item={name=name or 'modifier_item_test',attributes=attributes or 2,refreshes=0}
        function item:IsNull() return self.null or false end
        function item:IsMuted() return self.muted or false end
        function item:GetIntrinsicModifierName() return self.name end
        function item:RefreshIntrinsicModifier()
            self.refreshes=self.refreshes+1
            for _,m in ipairs(hero.modifiers) do if m.item==self then m:Destroy() end end
            for s=0,5 do if hero.slots[s]==self then hero:AddNewModifier(hero,self,self.name,{}) break end end
        end
        hero.slots[slot]=item return item
    end
    function w:apply(hero) manager.Apply(hero) return hero:FindAllModifiersByName(manager.modifierName)[1] end
    function w:count(hero,item)
        local n=0 for _,m in ipairs(hero.modifiers) do if not m.null and m.item==item then n=n+1 end end return n
    end
    return w
end

test('only the selected human hero on either playing team is eligible', function()
    local w=world() local human=w:hero(0) local enemyHuman=w:hero(1,false,3) local bot=w:hero(2,true)
    assert(w.manager.IsEligible(human) and w.manager.IsEligible(enemyHuman))
    assert(not w.manager.IsEligible(bot))
    w.heroes[0]=nil assert(not w.manager.IsEligible(human), 'unassigned hero accepted')
end)
test('illusions, summons, spectators, invalid owners and null heroes are rejected', function()
    local w=world() local h=w:hero(0)
    h.illusion=true assert(not w.manager.IsEligible(h)) h.illusion=false
    h.real=false assert(not w.manager.IsEligible(h)) h.real=true
    h.team=1 assert(not w.manager.IsEligible(h)) h.team=2
    h.id=-1 assert(not w.manager.IsEligible(h)) h.id=0
    h.null=true assert(not w.manager.IsEligible(h)) assert(not w.manager.IsEligible(nil))
end)
test('all three backpack slots receive their own native intrinsic once', function()
    local w=world() local h=w:hero(0) local items={}
    for slot=6,8 do items[slot]=w:item(h,slot,'modifier_item_test_'..slot) end
    local m=w:apply(h) for i=1,20 do m:OnIntervalThink() end
    for _,item in pairs(items) do assert(w:count(h,item)==1, 'missing or duplicated passive') end
    assert(m:CheckState()[60] and not m:IsPurgable() and not m:RemoveOnDeath())
    assert(not m:AllowIllusionDuplicate())
end)
test('main, stash, neutral and teleport items do not receive extra intrinsics', function()
    local w=world() local h=w:hero(0)
    for _,slot in ipairs({0,5,9,14,15,16}) do w:item(h,slot) end
    local m=w:apply(h) assert(next(m.provided)==nil)
end)
test('repeated application does not create duplicate manager modifiers', function()
    local w=world() local h=w:hero(0) local first=w:apply(h)
    assert(w:apply(h)==first and #h:FindAllModifiersByName(w.manager.modifierName)==1)
end)
test('moving a backpack item into the main inventory leaves one native effect', function()
    local w=world() local h=w:hero(0) local item=w:item(h,6) local m=w:apply(h)
    h.slots[0],h.slots[6]=item,nil m:OnIntervalThink()
    assert(w:count(h,item)==1 and item.refreshes==1 and m.provided[item]==nil)
end)
test('a native inventory refresh before polling does not duplicate main-slot stats', function()
    local w=world() local h=w:hero(0) local item=w:item(h,6) local m=w:apply(h)
    h.slots[0],h.slots[6]=item,nil item:RefreshIntrinsicModifier() m:OnIntervalThink()
    assert(w:count(h,item)==1 and m.provided[item]==nil)
end)
test('moving an item to stash or dropping it removes its extra passive', function()
    for _,slot in ipairs({9,14}) do
        local w=world() local h=w:hero(0) local item=w:item(h,6) local m=w:apply(h)
        h.slots[slot],h.slots[6]=item,nil m:OnIntervalThink() assert(w:count(h,item)==0)
    end
end)
test('selling or consuming an item removes its extra passive', function()
    local w=world() local h=w:hero(0) local item=w:item(h,8) local m=w:apply(h)
    h.slots[8],item.null=nil,true m:OnIntervalThink() assert(w:count(h,item)==0)
end)
test('backpack movement preserves one effect and a replacement gets its own', function()
    local w=world() local h=w:hero(0) local first=w:item(h,6) local m=w:apply(h)
    h.slots[6],h.slots[7]=nil,first m:OnIntervalThink() assert(w:count(h,first)==1)
    local second=w:item(h,7) m:OnIntervalThink()
    assert(w:count(h,first)==0 and w:count(h,second)==1)
end)
test('engine-removed passives are restored without stacking', function()
    local w=world() local h=w:hero(0) local item=w:item(h,6) local m=w:apply(h)
    m.provided[item]:Destroy() m:OnIntervalThink() assert(w:count(h,item)==1)
end)
test('an intrinsic supplied by another system is left alone', function()
    local w=world() local h=w:hero(0) local item=w:item(h,6)
    local existing=h:AddNewModifier(h,item,item.name,{}) local m=w:apply(h)
    assert(w:count(h,item)==1 and m.provided[item]==nil) m:Destroy() assert(not existing.null)
end)
test('native non-stacking effects are not stolen from another item', function()
    local w=world() local h=w:hero(0) local main=w:item(h,0,'unique',0)
    local existing=h:AddNewModifier(h,main,main.name,{}) local pack=w:item(h,6,'unique',0)
    local m=w:apply(h) assert(w:count(h,main)==1 and w:count(h,pack)==0)
    m:Destroy() assert(not existing.null)
end)
test('muted items lose their provided passive and regain it when unmuted', function()
    local w=world() local h=w:hero(0) local item=w:item(h,6) local m=w:apply(h)
    item.muted=true m:OnIntervalThink() assert(w:count(h,item)==0)
    item.muted=false m:OnIntervalThink() assert(w:count(h,item)==1)
end)
test('items without intrinsic passives still keep the active backpack state', function()
    local w=world() local h=w:hero(0) local item=w:item(h,6,'') local m=w:apply(h)
    assert(w:count(h,item)==0 and m:CheckState()[60])
end)
test('destroying the manager removes only its own effects', function()
    local w=world() local h=w:hero(0) local pack=w:item(h,6) local main=w:item(h,0,'main')
    local existing=h:AddNewModifier(h,main,main.name,{}) local m=w:apply(h) m:Destroy()
    assert(w:count(h,pack)==0 and not existing.null)
end)
test('changing a hero into a bot removes the privilege and provided passives', function()
    local w=world() local h=w:hero(0) local item=w:item(h,6) local m=w:apply(h)
    h.fake=true m:OnIntervalThink() assert(m.null and w:count(h,item)==0)
end)
test('startup polls late human heroes, ignores bots and stops at postgame', function()
    local w=world() w.manager.Start() assert(w.thinker and w.links==1)
    local h=w:hero(0) local bot=w:hero(1,true) local enemy=w:hero(2,false,3)
    assert(w.thinker.tick()==0.5)
    assert(h:HasModifier(w.manager.modifierName) and enemy:HasModifier(w.manager.modifierName))
    assert(not bot:HasModifier(w.manager.modifierName))
    local first=w.thinker w.manager.Start() assert(w.thinker==first and w.links==1)
    w.state=8 assert(w.thinker.tick()==nil and w.thinker.removed)
end)
test('opt out and disabled customization do not change a game', function()
    for _,customize in ipairs({{Enable=true,Human_Backpack_Active=false},{Enable=false}}) do
        local w=world({customize=customize}) w.manager.Start() assert(w.thinker==nil)
    end
end)
test('clients, dedicated servers, custom maps and unsupported engines are untouched', function()
    for _,opt in ipairs({{server=false},{dedicated=true},{map='demo_hero'},{unsupported=true}}) do
        local w=world(opt) w.manager.Start() assert(w.thinker==nil)
    end
end)
print(string.format('Human backpack regression: %d passed, %d failed',passed,failed))
if failed>0 then os.exit(1) end
