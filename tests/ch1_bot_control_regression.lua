local sourceRoot=(arg and arg[1]) or 'addons/ch1_inventory_lab'
local control=dofile(sourceRoot..'/scripts/vscripts/ch1_inventory/bot_control.lua')
local passed,failed=0,0
DOTA_UNIT_ORDER_GLYPH=1001
DOTA_UNIT_ORDER_RADAR=1002
DOTA_UNIT_ORDER_PING_ABILITY=1003
local function test(name,run)
    local ok,err=pcall(run)
    if ok then passed=passed+1; print('PASS '..name)
    else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
end
local slots={[0]=false,[1]=true,[5]=true,[9]=true,[10]=false}
GameRules={Ch1InventoryLabActive=true}
PlayerResource={
    IsValidPlayerID=function(_,id) return slots[id]~=nil end,
    IsFakeClient=function(_,id) return slots[id] end,
}
local entities={}
local function unit(index,owner,null)
    entities[index]={IsNull=function() return null or false end,GetPlayerOwnerID=function() return owner end}
end
unit(100,0); unit(101,1); unit(105,5); unit(109,9); unit(110,10)
unit(300,0); unit(301,0); unit(305,5); unit(306,5)
unit(200,-1); unit(201,1,true)
EntIndexToHScript=function(index) return entities[index] end
local function allow(issuer,units,orderType)
    return control.AllowOrder({issuer_player_id_const=issuer,units=units,order_type=orderType})
end
test('initializing a bot removes inherited human controllers and keeps its own AI',function()
    for _,owner in ipairs({1,5,9}) do
        local controllers={[0]=true,[10]=true,[owner]=true}
        local hero={
            SetControllableByAllPlayers=function(_,enabled) assert(enabled==false) end,
            SetControllableByPlayer=function(_,id,skipAdjust)
                assert(skipAdjust==true)
                if id==-1 then controllers={} else controllers[id]=true end
            end,
        }
        control.ConfigureHero(hero,owner)
        assert(controllers[owner] and not controllers[0] and not controllers[10])
        local count=0
        for _ in pairs(controllers) do count=count+1 end
        assert(count==1,'A different player still controls the bot')
    end
end)
test('human cannot move or cast with allied or enemy bot units',function()
    for _,orderType in ipairs({1,4,5,6,8,9,10}) do
        for _,index in ipairs({101,105,109}) do
            assert(not allow(0,{['0']=index},orderType))
        end
    end
end)
test('own hero courier and summons remain controllable',function()
    for _,orderType in ipairs({1,4,5,6,8,9,10}) do
        assert(allow(0,{['0']=100,['1']=300,['2']=301},orderType))
    end
end)
test('bot couriers and summons cannot be commanded by a human',function()
    assert(not allow(0,{['0']=305},1))
    assert(not allow(0,{['0']=306},8))
end)
test('legitimate sharing between real humans is preserved',function()
    assert(allow(0,{['0']=110},1))
end)
test('glyph scan and ability pings remain usable while inspecting a bot',function()
    for _,orderType in ipairs({DOTA_UNIT_ORDER_GLYPH,DOTA_UNIT_ORDER_RADAR,DOTA_UNIT_ORDER_PING_ABILITY}) do
        assert(allow(0,{['0']=105},orderType))
    end
end)
test('bot-issued commands remain allowed for both teams',function()
    for _,issuer in ipairs({1,5,9}) do
        assert(allow(issuer,{['0']=101,['1']=105,['2']=109},1))
    end
end)
test('server and non-player orders are unaffected',function()
    assert(allow(-1,{['0']=101},1))
    assert(allow(nil,{['0']=105},1))
end)
test('mixed selection cannot smuggle a command to a bot',function()
    assert(not allow(0,{['0']=100,['1']=105},1))
end)
test('empty orders unowned and deleted units do not block unrelated actions',function()
    assert(allow(0,{},1))
    assert(allow(0,{['0']=200,['1']=201,['2']=999},1))
    assert(control.AllowOrder({issuer_player_id_const=0}))
end)
test('numeric string issuer and entity ids are accepted',function()
    assert(not allow('0',{['0']='105'},1))
end)
test('protection is scoped to the active addon',function()
    GameRules.Ch1InventoryLabActive=false
    assert(allow(0,{['0']=105},1))
    GameRules.Ch1InventoryLabActive=true
end)
print(string.format('Ch1 bot control regression: %d passed, %d failed',passed,failed))
if failed>0 then os.exit(1) end
