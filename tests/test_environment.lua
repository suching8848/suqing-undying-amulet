-- Standalone host stubs. Load this before the mod files, then run test_undying_amulet.lua.
local Test = {}
AmuletTest = Test

local checks = 0
function Test.equal(actual, expected, description)
    checks = checks + 1
    assert(actual == expected,
        description .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

function Test.finish()
    return "PASS " .. checks .. " amulet checks"
end

local eventHandlers = {}
Events = {}
local eventNames = {
    "OnPlayerGetDamage", "OnPlayerUpdate", "OnTick", "OnTickEvenPaused", "OnZombieUpdate",
    "OnSave", "OnPostSave", "OnPlayerDeath", "OnMainMenuEnter", "OnCreatePlayer", "OnGameStart",
    "OnClothingUpdated", "OnFillInventoryObjectContextMenu", "OnGameBoot", "OnLoad", "OnPostUIDraw",
}
for _, name in ipairs(eventNames) do
    local handlers = {}
    eventHandlers[name] = handlers
    Events[name] = {
        Add = function(handler)
            handlers[#handlers + 1] = handler
        end,
        Remove = function(handler)
            for index, current in ipairs(handlers) do
                if current == handler then table.remove(handlers, index) return end
            end
        end,
    }
end

function Test.fire(name, ...)
    assert(eventHandlers[name], name)
    for _, handler in ipairs(eventHandlers[name]) do
        handler(...)
    end
end

function triggerEvent(name, ...)
    Test.fire(name, ...)
end

-- The harness runner loads these Lua modules explicitly in game dependency order.
function require(name)
    local prefix = "SuQingUndyingAmulet/"
    if string.sub(name, 1, #prefix) == prefix then
        local module = string.sub(name, #prefix + 1)
        assert(SuQingUndyingAmulet and SuQingUndyingAmulet[module], "Missing loaded module " .. name)
    end
end

Test.clock = 10000
Test.paused = false
Test.client = false
Test.server = false
Test.zombies = {}

function isClient() return Test.client end
function isServer() return Test.server end
function isGamePaused() return Test.paused end
function getTimestampMs() return Test.clock end
function getText(key, value)
    if value == nil then return key end
    return key .. ":" .. tostring(value)
end
function getPlayer() return Test.localPlayer end
function getSpecificPlayer(index)
    local player = Test.localPlayer
    return player and index == player:getPlayerNum() and player or nil
end

Test.viewports = {[0] = {left = 0, top = 0, width = 1920}}
function getPlayerScreenLeft(index) return Test.viewports[index].left end
function getPlayerScreenTop(index) return Test.viewports[index].top end
function getPlayerScreenWidth(index) return Test.viewports[index].width end

UIFont = {Medium = "Medium"}
local uiDraws = {}
local textManager = {}
function textManager:DrawStringCentre(font, x, y, text)
    uiDraws[#uiDraws + 1] = {font = font, x = x, y = y, text = text}
end
function getTextManager() return textManager end

function Test.drawUI()
    uiDraws = {}
    Test.fire("OnPostUIDraw")
    return uiDraws
end

ResourceLocation = {of = function(id) return id end}
ItemBodyLocation = {get = function(id) return id end}
local location = {setAttachmentName = function() end}
local locationGroup = {getOrCreateLocation = function() return location end}
BodyLocations = {getGroup = function() return locationGroup end}
AttachedLocations = {getGroup = function() return locationGroup end}
BodyPartType = {getDamageModifyer = function() return 1 end}
CharacterStat = setmetatable({}, {__index = function(_, name) return name end})

ISInventoryPane = {}
function ISInventoryPane.getActualItems(selection)
    local actual = {}
    local seen = {}
    local function include(item)
        if not seen[item] then
            actual[#actual + 1] = item
            seen[item] = true
        end
    end
    for _, entry in ipairs(selection) do
        if instanceof(entry, "InventoryItem") then
            include(entry)
        else
            -- The vanilla stack header duplicates the first item at index 1.
            for index = 2, #entry.items do include(entry.items[index]) end
        end
    end
    return actual
end

ISToolTip = {new = function() return {initialise = function() end} end}

function Test.inventoryOptions(selection)
    local options = {}
    local context = {}
    function context:addOption(name, target, callback, item, bag, removing)
        local option = {name = name, target = target, callback = callback, item = item, bag = bag, removing = removing}
        options[#options + 1] = option
        return option
    end
    Test.fire("OnFillInventoryObjectContextMenu", 0, context, selection)
    return options
end

ISTimedActionQueue = {}
function ISTimedActionQueue.getTimedActionQueue(player)
    if not player.timedQueue then player.timedQueue = {queue = {}} end
    return player.timedQueue
end
function ISTimedActionQueue.add(action)
    local queue = ISTimedActionQueue.getTimedActionQueue(action.character).queue
    queue[#queue + 1] = action
end

ISBaseTimedAction = {}
function ISBaseTimedAction:derive(name)
    self.__index = self
    return setmetatable({Type = name}, self)
end
function ISBaseTimedAction:new(character)
    self.__index = self
    return setmetatable({character = character, stopOnWalk = true, stopOnRun = true}, self)
end
function ISBaseTimedAction:getJobDelta() return self.testJobDelta or 0 end
function ISBaseTimedAction:setActionAnim(animation) self.animation = animation end
function ISBaseTimedAction:setAnimVariable(name, value)
    self.animVariables = self.animVariables or {}
    self.animVariables[name] = value
end
function ISBaseTimedAction:setOverrideHandModels() end
function ISBaseTimedAction:stop()
    ISTimedActionQueue.getTimedActionQueue(self.character).queue = {}
end
function ISBaseTimedAction:perform()
    local queue = ISTimedActionQueue.getTimedActionQueue(self.character).queue
    assert(queue[1] == self, "timed action completion order")
    table.remove(queue, 1)
end

function Test.queueOption(option)
    option.callback(option.target, option.item, option.bag, option.removing)
    return ISTimedActionQueue.getTimedActionQueue(option.target).queue[1]
end

function Test.finishAction(action)
    -- IsoGameCharacter performs, then completes, a successful single-player action.
    action:perform()
    return action:complete()
end

function Test.list(values)
    local list = {}
    function list:size() return #values end
    function list:get(index) return values[index + 1] end
    function list:contains(item)
        for _, value in ipairs(values) do
            if value == item then return true end
        end
        return false
    end
    return list
end

local cell = {}
function cell:getZombieList() return Test.list(Test.zombies) end
function getCell() return cell end

local nextId = 0
local newInventory
local itemMethods = {}
function itemMethods:getID() return self.id end
function itemMethods:getFullType() return self.type end
function itemMethods:getModData() return self.data end
function itemMethods:hasModData()
    for _ in pairs(self.data) do return true end
    return false
end
function itemMethods:getContainer() return self.container end
function itemMethods:isBroken() return self.condition <= 0 end
function itemMethods:setCondition(value) self.condition = value end
function itemMethods:getCondition() return self.condition end
function itemMethods:getStaticModel() return self.data.staticModel or self.model end
function itemMethods:setStaticModel(value) self.data.staticModel = value end
function itemMethods:setJobType(value) self.jobType = value end
function itemMethods:setJobDelta(value) self.jobDelta = value end
function itemMethods:IsInventoryContainer()
    return self.type == "Base.Bag" or string.sub(self.type, 1, 9) == "Base.Bag_"
end
function itemMethods:getInventory() return self.inventory end

function Test.item(fullType, id, data)
    nextId = nextId + 1
    local item = setmetatable({
        className = "InventoryItem",
        id = id or nextId,
        type = fullType,
        condition = 1,
        model = "TestModel",
        data = data or {},
    }, {__index = itemMethods})
    if item:IsInventoryContainer() then item.inventory = newInventory() end
    return item
end

function instanceItem(fullType) return Test.item(fullType) end

newInventory = function()
    local items = {}
    local list = Test.list(items)
    local inventory = {}
    function inventory:getItems() return list end
    function inventory:hasRoomFor() return not self.full end
    function inventory:getItemWithID(id)
        for _, item in ipairs(items) do
            if item:getID() == id then return item end
        end
        return nil
    end
    function inventory:getItemById(id)
        local direct = self:getItemWithID(id)
        if direct then return direct end
        for _, item in ipairs(items) do
            if item:IsInventoryContainer() then
                local nested = item:getInventory():getItemById(id)
                if nested then return nested end
            end
        end
        return nil
    end
    function inventory:AddItem(item)
        if type(item) == "string" then item = Test.item(item) end
        items[#items + 1] = item
        item.container = self
        return item
    end
    function inventory:Remove(item)
        for index, current in ipairs(items) do
            if current == item then
                table.remove(items, index)
                item.container = nil
                return
            end
        end
    end
    return inventory
end

local partMethods = {}
function partMethods:getHealth() return self.health end
function partMethods:IsInfected() return self.knox == true end
function partMethods:SetInfected(value) self.knox = value end
function partMethods:IsFakeInfected() return self.fakeInfected == true end
function partMethods:SetFakeInfected(value) self.fakeInfected = value end
function partMethods:getStiffness() return self.stiffness or 0 end
function partMethods:setStiffness(value) self.stiffness = value end
function partMethods:RestoreToFullHealth()
    self.health = 100
    self.bite = false
    self.bleeding = false
    self.fracture = false
    self.burn = false
    self.woundInfection = false
    self.knox = false
    self.fakeInfected = false
    self.stiffness = 0
end

local damageMethods = {}
function damageMethods:getBodyParts() return Test.list(self.parts) end
function damageMethods:getOverallBodyHealth() return self.health end
function damageMethods:getHealth() return self.health end
function damageMethods:setOverallBodyHealth(value) self.health = value end
function damageMethods:isInfected() return self.knox end
function damageMethods:IsInfected() return self.knox end
function damageMethods:setInfected(value) self.knox = value end
function damageMethods:setInfectionTime(value) self.infectionTime = value end
function damageMethods:setInfectionMortalityDuration(value) self.infectionMortality = value end
function damageMethods:setIsFakeInfected(value) self.fakeInfected = value end
function damageMethods:setBurntToDeath(value) self.burntToDeath = value end
function damageMethods:setIsOnFire(value) self.onFire = value end

local statMethods = {}
function statMethods:get(stat) return self.values[stat] or 0 end
function statMethods:set(stat, value) self.values[stat] = value end
function statMethods:reset(stat) self.values[stat] = 0 end

local playerMethods = {}
function playerMethods:getInventory() return self.inventory end
function playerMethods:getWornItem(location) return self.worn[location] end
function playerMethods:setWornItem(location, item) self.worn[location] = item end
function playerMethods:removeWornItem(item)
    for location, worn in pairs(self.worn) do
        if worn == item then self.worn[location] = nil return end
    end
end
function playerMethods:getClothingItem_Back() return self.backpack end
function playerMethods:getAttachedItem(location) return self.attached[location] end
function playerMethods:setAttachedItem(location, item)
    if item then
        for previous, attached in pairs(self.attached) do
            if attached == item then self.attached[previous] = nil end
        end
    end
    self.attached[location] = item
end
function playerMethods:removeAttachedItem(item)
    for location, attached in pairs(self.attached) do
        if attached == item then self.attached[location] = nil return end
    end
end
function playerMethods:getPrimaryHandItem() return self.primaryItem end
function playerMethods:setPrimaryHandItem(item) self.primaryItem = item end
function playerMethods:getSecondaryHandItem() return self.secondaryItem end
function playerMethods:setSecondaryHandItem(item) self.secondaryItem = item end
function playerMethods:getBodyDamage() return self.damage end
function playerMethods:getHealth() return self.health end
function playerMethods:setHealth(value) self.health = value end
function playerMethods:isDead() return self.dead or self.health <= 0 or self.damage.health <= 0 end
function playerMethods:isLocalPlayer() return self == Test.localPlayer end
function playerMethods:getPlayerNum() return self.playerNum or 0 end
function playerMethods:isFemale() return self.female == true end
function playerMethods:isTimedActionInstant() return self.timedActionInstant == true end
function playerMethods:reportEvent(name) self.lastEvent = name end
function playerMethods:isGodMod() return self.invulnerable end
function playerMethods:isInvulnerable() return self.invulnerable end
function playerMethods:setInvulnerable(value) self.invulnerable = value end
function playerMethods:isInvisible() return self.invisible end
function playerMethods:setInvisible(value) self.invisible = value end
function playerMethods:isGhostMode() return self.invisible end
function playerMethods:setGhostMode(value) self.invisible = value end
function playerMethods:isDeathDragDown() return self.deathDragDown end
function playerMethods:setDeathDragDown(value) self.deathDragDown = value end
function playerMethods:getHitReaction() return self.reaction end
function playerMethods:setHitReaction(value) self.reaction = value end
function playerMethods:getCurrentActionContextStateName() return self.actionState end
function playerMethods:setDefaultState() self.actionState = "idle" end
function playerMethods:setBlockMovement(value) self.blockMovement = value end
function playerMethods:setIgnoreMovement(value) self.ignoreMovement = value end
function playerMethods:getAttackedBy() return self.attacker end
function playerMethods:setAttackedBy(value) self.attacker = value end
function playerMethods:isOnKillDone() return self.killed end
function playerMethods:isOnDeathDone() return self.deathDone end
function playerMethods:getModData() return self.data end
function playerMethods:getStats() return self.stats end
function playerMethods:getSleepingPillsTaken() return self.pills end
function playerMethods:resetSleepingPillsTaken() self.pills = 0 end
function playerMethods:setCorpseSicknessRate(value) self.corpseSickness = value end
function playerMethods:setPainEffect(value) self.painEffect = value end
function playerMethods:StopBurning() self.burning = false end
function playerMethods:isBeingGrappled() return self.grappledBy ~= nil end
function playerMethods:getGrappledBy() return self.grappledBy end
function playerMethods:getVariableBoolean(name) return self.variables[name] == true end
function playerMethods:setVariable(name, value) self.variables[name] = value end
playerMethods.SetVariable = playerMethods.setVariable
function playerMethods:clearVariable(name) self.variables[name] = nil end
function playerMethods:getCell() return cell end
function playerMethods:getX() return 100 end
function playerMethods:getY() return 100 end
function playerMethods:getZ() return 0 end
function playerMethods:Say(line) self.said[#self.said + 1] = line end

function Test.player()
    local parts = {}
    for index = 1, 3 do
        parts[index] = setmetatable({health = 100}, {__index = partMethods})
    end
    local player = setmetatable({
        className = "IsoPlayer",
        inventory = newInventory(),
        worn = {},
        attached = {},
        said = {},
        variables = {},
        data = {},
        stats = setmetatable({values = {}}, {__index = statMethods}),
        damage = setmetatable({health = 100, parts = parts}, {__index = damageMethods}),
        health = 100,
        pills = 0,
        dead = false,
        invulnerable = false,
        invisible = false,
        deathDragDown = false,
        reaction = "",
        actionState = "idle",
    }, {__index = playerMethods})
    Test.localPlayer = player
    return player
end

function instanceof(object, className)
    return object and object.className == className
end

function Test.zombie(target)
    local zombie = {
        className = "IsoZombie",
        target = target,
        aggro = target,
        targetSeenTime = 2,
        grappled = target,
    }
    function zombie:getTarget() return self.target end
    function zombie:setTarget(value) self.target = value end
    function zombie:isLeadAggro(value) return self.aggro == value end
    function zombie:clearAggroList() self.aggro = nil end
    function zombie:setTargetSeenTime(value) self.targetSeenTime = value end
    function zombie:isDead() return false end
    function zombie:isGrapplingTarget(value) return self.grappled == value end
    function zombie:getGrapplingTarget() return self.grappled end
    function zombie:setDoContinueGrapple(value) self.doContinueGrapple = value end
    function zombie:setDoGrappleLetGo() self.requestedRelease = true end
    function zombie:LetGoOfGrappled()
        if self.grappled then self.grappled.grappledBy = nil end
        self.grappled = nil
    end
    function zombie:getX() return 100 end
    function zombie:getY() return 100 end
    function zombie:getZ() return 0 end
    Test.zombies[#Test.zombies + 1] = zombie
    return zombie
end

function Test.tick(milliseconds, paused)
    Test.paused = paused == true
    Test.clock = Test.clock + milliseconds
    Test.fire("OnTickEvenPaused")
    if not Test.paused then
        Test.fire("OnTick")
        if Test.localPlayer then Test.fire("OnPlayerUpdate", Test.localPlayer) end
    end
end
