-- Exercise the actual equipment and rescue modules through their game event handlers.
local Test = AmuletTest
local Equipment = SuQingUndyingAmulet.Equipment
local Locations = SuQingUndyingAmulet.EquipmentLocations
local equal = Test.equal

local chargedType = "SuQingUndyingAmulet.UndyingAmulet"
local brokenType = "SuQingUndyingAmulet.BrokenUndyingAmulet"
local protectionKey = "SuQingUndyingAmuletProtection"

local function newPlayer()
    Test.fire("OnMainMenuEnter")
    Test.zombies = {}
    Test.client = false
    Test.server = false
    Test.paused = false
    return Test.player()
end

local function addWorn(player)
    local amulet = player:getInventory():AddItem(chargedType)
    player:setWornItem(Locations.getPendant(), amulet)
    return amulet
end

local function addBackpack(player, fullType)
    local bag = player:getInventory():AddItem(fullType or "Base.Bag")
    player.backpack = bag
    return bag
end

local function countType(inventory, fullType)
    local count = 0
    local items = inventory:getItems()
    for index = 0, items:size() - 1 do
        if items:get(index):getFullType() == fullType then count = count + 1 end
    end
    return count
end

local function damageEvent(player)
    Test.fire("OnPlayerGetDamage", player, "BITE", 1)
end

local function isProtected(player, expected, description, godModeBefore)
    equal(player:isInvulnerable(), godModeBefore == true, description .. " / existing God Mode")
    equal(player:isGhostMode(), expected, description .. " / ghost mode")
end

-- At 1 HP the wearable breaks and the player recovers; above 1 HP it stays equipped.
do
    local player = newPlayer()
    local amulet = addWorn(player)
    player.damage.health = 1.01
    Test.fire("OnPlayerUpdate", player)
    equal(Equipment.findActive(player), amulet, "above threshold retains the active amulet")
    isProtected(player, false, "above threshold")

    player.health = 42
    player.damage.health = 1
    player.damage.knox = true
    player.damage.fakeInfected = true
    player.damage.infectionTime = 5
    player.damage.infectionMortality = 7
    player.damage.hasACold = true
    player.damage.coldStrength = 17
    player.damage.onFire = true
    player.burning = true
    player.fireKillRate = 8
    player.fireSpreadProbability = 12
    player.pills = 8
    player.corpseSickness = 40
    player.betaEffect = 0.8
    player.depressEffect = 0.6
    player.sleepingTabletEffect = 0.3
    player.reduceInfectionPower = 0.7
    player.painEffect = 0.4
    local statuses = {
        [CharacterStat.HUNGER] = 35,
        [CharacterStat.FATIGUE] = 0.4,
        [CharacterStat.FOOD_SICKNESS] = 24,
        [CharacterStat.POISON] = 18,
        [CharacterStat.SICKNESS] = 12,
        [CharacterStat.PAIN] = 22,
        [CharacterStat.ZOMBIE_FEVER] = 10,
        [CharacterStat.ZOMBIE_INFECTION] = 15,
    }
    for stat, value in pairs(statuses) do player.stats:set(stat, value) end
    for _, part in ipairs(player.damage.parts) do
        part.health = 25
        part.bite = true
        part.bleeding = true
        part.fracture = true
        part.burn = true
        part.woundInfection = true
        part.knox = true
        part.fakeInfected = true
        part.stiffness = 4
    end

    damageEvent(player)
    equal(player.health, 100, "restores character health")
    equal(player.damage.health, 100, "restores aggregate body health")
    equal(player.damage.knox, true, "healing preserves Knox infection")
    equal(player.damage.fakeInfected, true, "healing preserves fake infection")
    equal(player.damage.infectionTime, 5, "healing preserves the infection timer")
    equal(player.damage.infectionMortality, 7, "healing preserves the mortality timer")
    equal(player.damage.hasACold, true, "healing preserves a cold")
    equal(player.damage.coldStrength, 17, "healing preserves cold intensity")
    equal(player.corpseSickness, 40, "healing preserves corpse sickness")
    equal(player.painEffect, 0.4, "healing preserves medication pain effect")
    equal(player.burning, true, "healing leaves the character's fire state alone")
    equal(player.damage.onFire, true, "healing leaves the body's fire flag alone")
    equal(player.pills, 8, "healing preserves recorded medication dose")
    for stat, value in pairs(statuses) do
        equal(player.stats:get(stat), value, "healing preserves " .. stat)
    end
    for _, part in ipairs(player.damage.parts) do
        equal(part.health, 100, "restores part health")
        equal(part.bite, false, "treats bite")
        equal(part.bleeding, false, "treats bleeding")
        equal(part.fracture, false, "treats fracture")
        equal(part.burn, false, "treats burn")
        equal(part.woundInfection, false, "treats wound infection")
        equal(part.knox, true, "healing preserves part-level Knox infection")
        equal(part.fakeInfected, true, "healing preserves part-level fake infection")
        equal(part.stiffness, 4, "healing preserves muscle stiffness")
    end
    equal(player:getWornItem(Locations.getPendant()), nil, "worn amulet is unequipped")
    equal(amulet:getContainer(), nil, "charged amulet is removed")
    equal(countType(player:getInventory(), brokenType), 1, "one broken amulet is retained")
    isProtected(player, true, "successful rescue")

    local replacement = addWorn(player)
    player.damage.health = 0.5
    player.damage.parts[2].health = 25
    player.damage.parts[2].bleeding = true
    damageEvent(player)
    Test.fire("OnPlayerUpdate", player)
    equal(Equipment.findActive(player), replacement, "active protection does not consume a second amulet")
    equal(countType(player:getInventory(), brokenType), 1, "rescue fires once during protection")
    equal(player.damage.health, 100, "protection cancels new body damage")
    equal(player.damage.parts[2].bleeding, false, "protection cancels bleeding from a new hit")

    -- A frame gap advances wall-clock time, but a pause does not spend protection.
    Test.tick(700)
    Test.tick(1000, true)
    Test.tick(3600000, true)
    -- Simulate ordinary changes in needs, medication and infection while protected.
    for stat, value in pairs(statuses) do player.stats:set(stat, value + 1) end
    player.damage.infectionTime = 6
    player.damage.coldStrength = 18
    player.fireKillRate = 9
    player.damage.parts[1].stiffness = 5
    player.pills = 9
    player.corpseSickness = 41
    player.betaEffect = 0.7
    player.depressEffect = 0.5
    player.sleepingTabletEffect = 0.2
    player.reduceInfectionPower = 0.6
    player.painEffect = 0.3
    Test.tick(0)
    for stat, value in pairs(statuses) do
        equal(player.stats:get(stat), value + 1, "protection leaves ongoing " .. stat .. " updates in effect")
    end
    Test.tick(2299)
    isProtected(player, true, "2,999 milliseconds of play")
    Test.tick(1)
    isProtected(player, false, "3,000 milliseconds of play")
    equal(player.damage.knox, true, "Knox infection survives protection cleanup")
    equal(player.damage.infectionTime, 6, "infection time can still advance")
    equal(player.damage.hasACold, true, "cold state survives protection")
    equal(player.damage.coldStrength, 18, "cold intensity can still advance")
    equal(player.damage.parts[1].knox, true, "part-level Knox flag survives protection")
    equal(player.damage.parts[1].stiffness, 5, "muscle stiffness can still change")
    equal(player.pills, 9, "sleeping-pill count can still change")
    equal(player.corpseSickness, 41, "corpse sickness can still change")
    equal(player.betaEffect, 0.7, "beta blocker effect can still change")
    equal(player.depressEffect, 0.5, "antidepressant effect can still change")
    equal(player.sleepingTabletEffect, 0.2, "sleeping tablet effect can still change")
    equal(player.reduceInfectionPower, 0.6, "infection treatment effect can still change")
    equal(player.painEffect, 0.3, "medication pain effect can still change")
    equal(player.damage.onFire, true, "body fire is neither reset nor extinguished")
    equal(player.burning, true, "player fire is neither reset nor extinguished")
    equal(player.fireKillRate, 9, "fire damage rate can still change")
    equal(player.fireSpreadProbability, 12, "fire spread rate stays intact")
end

-- Native damage events can precede total-health recomputation.
do
    local player = newPlayer()
    local amulet = addWorn(player)
    player.damage.parts[1].health = 1.5
    damageEvent(player)
    equal(Equipment.findActive(player), amulet, "pending health above 1 does not trigger")
    player.damage.parts[1].health = 0.75
    damageEvent(player)
    isProtected(player, true, "pending part damage crossing 1 triggers")
    equal(countType(player:getInventory(), brokenType), 1, "pending damage consumes only one item")
end

do
    local player = newPlayer()
    player.damage.health = 0.8
    local offline = player:getInventory():AddItem(chargedType)
    Test.fire("OnPlayerUpdate", player)
    equal(offline:getContainer(), player:getInventory(), "an unmounted amulet is not consumed")
    isProtected(player, false, "an unmounted amulet does not protect")
    player:setWornItem(Locations.getPendant(), offline)
    Test.client = true
    damageEvent(player)
    isProtected(player, false, "multiplayer clients do not receive rescue")
    Test.client = false
    Test.server = true
    damageEvent(player)
    isProtected(player, false, "servers do not execute single-player rescue")
    Test.server = false
    player.health = 0
    damageEvent(player)
    Test.fire("OnPlayerUpdate", player)
    equal(player.health, 0, "already-dead player is not resurrected")
    equal(Equipment.findActive(player), offline, "no amulet is consumed after death")
    isProtected(player, false, "no active effect after death")

    player.health = 100
    player.killed = true
    damageEvent(player)
    equal(Equipment.findActive(player), offline, "completed native kill does not trigger a rescue")
end

-- A pending execution can arm the shield even at high health.
do
    local player = newPlayer()
    addWorn(player)
    local aggressor = Test.zombie(player)
    local otherTarget = {}
    local bystander = Test.zombie(otherTarget)
    local tracking = Test.zombie(player)
    tracking.target = nil
    player.grappledBy = aggressor
    player.attacker = aggressor
    player.deathDragDown = true
    player.reaction = "EndDeath"
    player.blockMovement = true
    player.ignoreMovement = true

    Test.fire("OnPlayerUpdate", player)
    isProtected(player, true, "pending drag-down at full health")
    equal(countType(player:getInventory(), brokenType), 1, "pending execution breaks the amulet")
    equal(player.attacker, nil, "clears the attacker for queued execution")
    equal(player.deathDragDown, false, "cancels pending drag-down")
    equal(player.reaction, "", "clears zombie hit reaction")
    equal(player.blockMovement, false, "unblocks movement")
    equal(player.ignoreMovement, false, "restores movement inputs")
    equal(player.grappledBy, nil, "ends the zombie grapple")
    equal(aggressor.target, nil, "clears the aggressor's target")
    equal(aggressor.aggro, nil, "clears the aggressor's aggro")
    equal(aggressor.targetSeenTime, 0, "clears the aggressor's sight timer")
    equal(tracking.aggro, nil, "clears a stale aggro lead even without a current target")
    equal(bystander.target, otherTarget, "leaves another target intact")
    equal(bystander.aggro, otherTarget, "leaves another target's aggro intact")

    player.attacker = aggressor
    player.reaction = "Bite"
    player.blockMovement = true
    damageEvent(player)
    equal(player.attacker, nil, "blocks queued bite from old aggro during protection")
    equal(player.blockMovement, false, "a stale hit cannot re-stun a protected player")
    equal(countType(player:getInventory(), brokenType), 1, "stale hit does not consume another item")
end

-- The EndDeath action itself is sufficient even if obsolete flags were reset.
do
    local player = newPlayer()
    addWorn(player)
    player.actionState = "hitreaction-endDeath"
    player.ignoreMovement = true
    player.blockMovement = true
    Test.fire("OnPlayerUpdate", player)
    isProtected(player, true, "active EndDeath action with no drag-down flag")
    equal(player.actionState, "idle", "leaves the pending execution action")
    equal(player.ignoreMovement, false, "releases control before the pending death animation ends")

    player.actionState = "hitreaction-crawlerBite"
    player.ignoreMovement = true
    Test.fire("OnPlayerUpdate", player)
    equal(player.actionState, "idle", "exits a queued crawler bite during protection")
    equal(player.ignoreMovement, false, "queued crawler bite cannot hold movement")

    player.actionState = "climbfence"
    Test.fire("OnPlayerUpdate", player)
    equal(player.actionState, "climbfence", "protection leaves unrelated action states alone")
end

-- Saving temporarily clears owned flags, and the next active tick re-arms protection.
do
    local player = newPlayer()
    addWorn(player)
    player.damage.health = 1
    Test.fire("OnPlayerUpdate", player)
    isProtected(player, true, "low-health player-update fallback")
    local savedMarker = player:getModData()[protectionKey]
    equal(type(savedMarker), "table", "direct player saves can identify transient flags")
    equal(savedMarker.ownsGhostMode, true, "direct player saves identify the owned ghost flag")
    equal(savedMarker.ownsGodMode, nil, "a new save never claims native God Mode")
    Test.fire("OnSave")
    isProtected(player, false, "save excludes temporary flags")
    equal(player:getModData()[protectionKey], nil, "standard world saves omit transient marker")
    Test.tick(50)
    isProtected(player, true, "protection resumes on next tick")
    Test.fire("OnMainMenuEnter")
    isProtected(player, false, "leaving world cleans up flags")
    Test.tick(100)
    isProtected(player, false, "temporary flags do not return in menu")

    local loaded = newPlayer()
    loaded:getModData()[protectionKey] = savedMarker
    loaded.invulnerable = true
    loaded.invisible = true
    Test.fire("OnCreatePlayer", 0, loaded)
    isProtected(loaded, false, "loading clears owned ghost flag and preserves independent God Mode", true)
    equal(loaded:getModData()[protectionKey], nil, "loading clears the save marker")

    local legacy = newPlayer()
    legacy:getModData()[protectionKey] = {
        ownsGhostMode = true,
        ownsGodMode = true,
        survival = { HUNGER = 31, THIRST = 25 },
    }
    legacy.invulnerable = true
    legacy.invisible = true
    Test.fire("OnCreatePlayer", 0, legacy)
    isProtected(legacy, false, "loading version 0.2 clears its owned temporary flags")
    equal(legacy:getStats():get(CharacterStat.HUNGER), 31, "old direct save restores captured hunger")
    equal(legacy:getStats():get(CharacterStat.THIRST), 25, "old direct save restores captured thirst")

    player = newPlayer()
    addWorn(player)
    player.damage.health = 1
    damageEvent(player)
    Test.fire("OnSave")
    Test.clock = Test.clock + 5000
    Test.fire("OnPostSave")
    isProtected(player, true, "post-save event resumes protection before the next tick")
    Test.tick(2999)
    isProtected(player, true, "save time did not consume protection")
    Test.tick(1)
    isProtected(player, false, "protection ends exactly after active duration")

    player = newPlayer()
    addWorn(player)
    player.invulnerable = true
    player.invisible = true
    player.damage.health = 1
    damageEvent(player)
    Test.fire("OnSave")
    isProtected(player, true, "pre-existing native flags survive saving", true)
    Test.fire("OnPostSave")
    Test.tick(3000)
    isProtected(player, true, "pre-existing native flags survive protection cleanup", true)
end

do
    local player = newPlayer()
    addWorn(player)
    player.damage.health = 1
    damageEvent(player)
    for _ = 1, 59 do Test.tick(50) end
    isProtected(player, true, "59 short frames at 20 fps")
    Test.tick(50)
    isProtected(player, false, "60 short frames at 20 fps")
end

local function expectCountdown(seconds, viewport, label)
    local draws = Test.drawUI()
    if not seconds then
        equal(#draws, 0, label)
        return
    end

    local x = viewport.left + viewport.width / 2
    local y = viewport.top + 72
    local message = "IGUI_SuQingUndyingAmulet_Countdown:" .. seconds
    for _, draw in ipairs(draws) do
        if draw.x == x and draw.y == y then
            equal(draw.text, message, label)
            equal(draw.font, UIFont.Medium, "countdown uses the viewport's medium HUD font")
            return
        end
    end
    equal(false, true, label .. " draws the label at the player's viewport centre")
end

do
    local player = newPlayer()
    player.playerNum = 1
    local viewport = {left = 960, top = 24, width = 960}
    Test.viewports[1] = viewport
    addWorn(player)
    expectCountdown(nil, viewport, "wearing a ready amulet does not draw a countdown")
    player.damage.health = 1
    damageEvent(player)
    expectCountdown(3, viewport, "rescue draws a localized 3 at the owning viewport")
    Test.tick(999)
    expectCountdown(3, viewport, "999 elapsed ms still draws 3")
    Test.tick(1)
    expectCountdown(2, viewport, "1000 elapsed ms draws 2")

    Test.tick(2500, true)
    expectCountdown(2, viewport, "pause freezes the countdown")
    expectCountdown(2, viewport, "drawing more paused frames does not spend protection")
    Test.tick(0)
    Test.tick(999)
    expectCountdown(2, viewport, "1999 elapsed play ms still draws 2 after pause")
    Test.tick(1)
    expectCountdown(1, viewport, "2000 elapsed play ms draws 1")
    Test.tick(999)
    expectCountdown(1, viewport, "2999 elapsed play ms still draws 1")
    Test.tick(1)
    expectCountdown(nil, viewport, "expiry removes the countdown instead of displaying zero")

    player = newPlayer()
    addWorn(player)
    player.damage.health = 1
    damageEvent(player)
    expectCountdown(3, Test.viewports[0], "the ordinary viewport displays a new protection")
    player.dead = true
    Test.fire("OnPlayerDeath", player)
    expectCountdown(nil, Test.viewports[0], "death removes the countdown immediately")

    player = newPlayer()
    addWorn(player)
    player.damage.health = 1
    damageEvent(player)
    Test.fire("OnMainMenuEnter")
    expectCountdown(nil, Test.viewports[0], "returning to the main menu removes the countdown")

    player = newPlayer()
    addWorn(player)
    player.damage.health = 1
    damageEvent(player)
    Test.player()
    expectCountdown(nil, Test.viewports[0], "a replaced character does not draw over the new viewport owner")
end

-- The amulet follows the specific backpack and persists via both item IDs.
do
    local player = newPlayer()
    local bag = addBackpack(player)
    local first = player:getInventory():AddItem(chargedType)
    local spare = player:getInventory():AddItem(chargedType)
    equal(Equipment.hang(player, first), true, "mounts a carried amulet")
    equal(first:getContainer(), bag:getInventory(), "the mounted object travels with the bag")
    equal(Equipment.findActive(player), first, "a hung amulet protects when the bag is worn")
    equal(player:getAttachedItem(Locations.backpack), first, "model tracks the current bag")
    equal(Equipment.hang(player, spare), false, "a used mount rejects a second amulet")

    player.backpack = nil
    Equipment.syncAttachment(player)
    equal(Equipment.findActive(player), nil, "removing the bag disarms the amulet")
    equal(player:getAttachedItem(Locations.backpack), nil, "removing the bag clears its model")
    addBackpack(player)
    equal(Equipment.findActive(player), nil, "switching bags does not transfer the amulet")
    player.backpack = bag
    Equipment.syncAttachment(player)
    equal(Equipment.findActive(player), first, "re-equipping the original bag restores protection")

    local reloadedBag = Test.item("Base.Bag", bag:getID(), bag:getModData())
    local reloadedFirst = Test.item(chargedType, first:getID(), first:getModData())
    local reloaded = newPlayer()
    reloaded:getInventory():AddItem(reloadedBag)
    reloadedBag:getInventory():AddItem(reloadedFirst)
    reloaded.backpack = reloadedBag
    equal(Equipment.findActive(reloaded), reloadedFirst, "loaded IDs recover the mount without runtime state")
    Equipment.syncAttachment(reloaded)
    equal(reloaded:getAttachedItem(Locations.backpack), reloadedFirst, "reload rebuilds the bag attachment")
    equal(Equipment.unhang(reloaded, reloadedFirst), true, "unmount transfers from bag to carried inventory")
    equal(reloadedFirst:getContainer(), reloaded:getInventory(), "the unmounted amulet is carried")
    equal(Equipment.findActive(reloaded), nil, "unmount disarms without breaking the item")

    equal(Equipment.hang(reloaded, reloadedFirst), true, "unmounted amulet can be remounted")
    reloaded.damage.health = 1
    damageEvent(reloaded)
    equal(countType(reloadedBag:getInventory(), brokenType), 1, "bag rescue leaves one broken amulet in the bag")
    equal(countType(reloaded:getInventory(), brokenType), 0, "bag rescue does not duplicate broken amulets")
    equal(Equipment.findActive(reloaded), nil, "consumption clears the mounted item")
    equal(reloaded:getAttachedItem(Locations.backpack), nil, "consumption clears the mounted model")
end

do
    local player = newPlayer()
    local bag = addBackpack(player)
    local amulet = player:getInventory():AddItem(chargedType)
    bag:getInventory().full = true
    equal(Equipment.hang(player, amulet), false, "mounting a full backpack safely fails")
    equal(amulet:getContainer(), player:getInventory(), "mount failure preserves the carried amulet")

    bag:getInventory().full = false
    equal(Equipment.hang(player, amulet), true, "mounting succeeds when room is available")
    player:getInventory():Remove(bag)
    equal(Equipment.findActive(player), nil, "stale equipped pointer cannot rescue using a lost bag")
    player:getInventory():AddItem(bag)
    bag:getInventory():Remove(amulet)
    player:getInventory():AddItem(amulet)
    Equipment.syncAttachment(player)
    equal(Equipment.findActive(player), nil, "moving a mounted item directly clears the mount")
    equal(player:getAttachedItem(Locations.backpack), nil, "direct transfer clears the bag model")
end

local hangText = "ContextMenu_SQUA_HangOnBackpack"
local removeText = "ContextMenu_SQUA_RemoveFromBackpack"

local function namedOption(options, name)
    for _, option in ipairs(options) do
        if option.name == name then return option end
    end
end

local function collapsedStack(...)
    local items = {...}
    table.insert(items, 1, items[1])
    return {items = items}
end

local function startAction(option)
    local action = Test.queueOption(option)
    equal(action:isValidStart(), true, "queued action is valid at start")
    action:start()
    return action
end

-- Right-clicking a vanilla collapsed row expands to several selected items.
do
    local player = newPlayer()
    local bag = addBackpack(player)
    local inventory = player:getInventory()
    local first = inventory:AddItem(chargedType)
    local second = inventory:AddItem(chargedType)
    local third = inventory:AddItem(chargedType)

    local options = Test.inventoryOptions({collapsedStack(first, second, third)})
    equal(#options, 1, "collapsed charged stack exposes exactly one action")
    local hang = options[1]
    equal(hang.name, hangText, "collapsed charged stack exposes Hang on backpack")
    equal(hang.item, first, "the first eligible item is selected")
    local action = startAction(hang)
    equal(action.maxTime > 1, true, "mounting uses a timed action")
    equal(action.animation, "Loot", "mounting uses the native rummage animation")
    equal(action.useProgressBar, true, "mounting shows the native progress bar")
    equal(action.stopOnWalk, true, "walking cancels an action in progress")
    equal(action.stopOnRun, true, "running cancels an action in progress")
    Test.queueOption(hang)
    equal(#ISTimedActionQueue.getTimedActionQueue(player).queue, 1, "repeated click does not queue another mount")
    equal(first:getContainer(), inventory, "starting the action does not move the item")
    equal(Equipment.findActive(player), nil, "starting the action does not activate the amulet")
    action.testJobDelta = 0.5
    action:update()
    equal(first.jobDelta, 0.5, "item progress follows the native action progress")
    equal(first:getContainer(), inventory, "partial progress does not move the item")
    equal(Test.finishAction(action), true, "collapsed stack action mounts the selected item on completion")
    equal(first.jobDelta, 0, "completion clears the native item progress")
    equal(action:complete(), false, "a completed mount cannot commit a second time")
    equal(Equipment.findActive(player), first, "the mounted item activates the amulet")
    equal(countType(bag:getInventory(), chargedType), 1, "only one amulet moves to the bag")
    equal(second:getContainer(), inventory, "the second amulet stays carried")
    equal(third:getContainer(), inventory, "the third amulet stays carried")

    options = Test.inventoryOptions({collapsedStack(second, third)})
    equal(#options, 1, "a full mount exposes one disabled action")
    equal(options[1].notAvailable, true, "a second mount cannot be used")
    equal(options[1].toolTip.description, "ContextMenu_SQUA_AlreadyHung", "occupied mount explanation")

    options = Test.inventoryOptions({collapsedStack(second, first, third), third})
    equal(#options, 1, "including the hung item exposes one action even with duplicate selection")
    local remove = options[1]
    equal(remove.name, removeText, "the hung item is offered for removal")
    equal(remove.item, first, "a later hung item takes precedence over loose amulets")
    action = startAction(remove)
    equal(Equipment.findActive(player), first, "pending removal keeps the mounted amulet active")
    equal(Test.finishAction(action), true, "group removal unmounts that amulet on completion")
    equal(countType(inventory, chargedType), 3, "all three charged amulets return to or stay in inventory")
    equal(countType(bag:getInventory(), chargedType), 0, "group removal leaves the backpack mount empty")

    equal(Test.inventoryOptions({first})[1].name, hangText, "single amulet still exposes Hang on backpack")
    equal(#Test.inventoryOptions({first, inventory:AddItem(brokenType)}), 0, "mixed intact and broken selection has no action")
    equal(#Test.inventoryOptions({collapsedStack(first, second), inventory:AddItem("Base.Nails")}), 0,
        "stack plus unrelated item has no amulet action")
end

do
    local player = newPlayer()
    local bag = addBackpack(player)
    local worn = addWorn(player)
    local loose = player:getInventory():AddItem(chargedType)
    local foreign = Test.item(chargedType)

    local hang = namedOption(Test.inventoryOptions({collapsedStack(foreign, worn, loose)}), hangText)
    equal(hang.item, loose, "batch selection chooses a loose owned amulet before the worn one")
    equal(Test.finishAction(startAction(hang)), true, "batch action mounts only the loose owned amulet")
    equal(player:getWornItem(Locations.getPendant()), worn, "the worn amulet stays equipped")
    equal(loose:getContainer(), bag:getInventory(), "the loose amulet moved to the bag")
    equal(foreign:getContainer(), nil, "the action leaves the unowned item alone")
    equal(Test.inventoryOptions({loose})[1].name, removeText, "single hung item still exposes removal")
end

do
    local player = newPlayer()
    local bag = addBackpack(player)
    local inventory = player:getInventory()
    local amulet = inventory:AddItem(chargedType)

    local hang = Test.inventoryOptions({amulet})[1]
    local action = startAction(hang)
    action.testJobDelta = 0.25
    action:update()
    action:stop()
    equal(amulet.jobDelta, 0, "cancelling resets progress")
    equal(amulet:getContainer(), inventory, "cancelling never moves the amulet")
    equal(Equipment.findActive(player), nil, "cancelling never mounts the amulet")

    action = startAction(hang)
    local otherBag = addBackpack(player)
    equal(action:isValid(), false, "swapping backpacks invalidates pending mount")
    equal(action:complete(), false, "stale mount cannot commit on the wrong bag")
    action:stop()
    equal(countType(otherBag:getInventory(), chargedType), 0, "new bag is not modified")
    player.backpack = bag

    action = startAction(hang)
    inventory:Remove(amulet)
    bag:getInventory():AddItem(amulet)
    equal(action:isValid(), false, "transferring the item invalidates a pending mount")
    equal(action:complete(), false, "stale mount cannot commit after an item transfer")
    action:stop()
    equal(Equipment.findActive(player), nil, "an item transferred to the bag remains unmounted")
    bag:getInventory():Remove(amulet)
    inventory:AddItem(amulet)

    action = startAction(hang)
    bag:getInventory().full = true
    equal(action:isValid(), false, "a full backpack invalidates pending mount")
    equal(action:complete(), false, "stale mount cannot commit into a full backpack")
    action:stop()
    equal(amulet:getContainer(), inventory, "the full backpack leaves the item in inventory")
    bag:getInventory().full = false

    equal(Test.finishAction(startAction(hang)), true, "the valid mount can be retried")
    local remove = Test.inventoryOptions({amulet})[1]
    action = startAction(remove)
    action:stop()
    equal(Equipment.findActive(player), amulet, "cancelling removal keeps the amulet mounted")
    equal(amulet:getContainer(), bag:getInventory(), "cancelling removal leaves the item in the bag")

    action = startAction(remove)
    inventory.full = true
    equal(action:isValid(), false, "a full inventory invalidates pending removal")
    equal(action:complete(), false, "stale removal cannot commit into a full inventory")
    action:stop()
    equal(Equipment.findActive(player), amulet, "invalid removal keeps the mounted amulet active")
    inventory.full = false

    action = startAction(remove)
    player.damage.health = 1
    damageEvent(player)
    equal(action:isValid(), false, "rescue consumption invalidates pending removal")
    equal(action:complete(), false, "removal cannot recreate the expended amulet")
    action:stop()
    equal(countType(bag:getInventory(), brokenType), 1, "rescue consumes the mounted amulet exactly once")
    equal(countType(inventory, chargedType), 0, "cancelling stale removal does not duplicate the amulet")
end

-- A stock bag uses its matching mounted model only while visibly attached.
do
    local cases = {
        {"Base.Bag_Schoolbag", "AmuletMountedSmall"},
        {"Base.Bag_Schoolbag", "AmuletMountedSmallFemale", true},
        {"Base.Bag_NormalHikingBag", "AmuletMountedHiking"},
        {"Base.Bag_BigHikingBag_Travel", "AmuletMountedBigHiking"},
        {"Base.Bag_ALICEpack_Army", "AmuletMountedMilitary"},
        {"Base.Bag_SurvivorBag", "AmuletMountedMilitary"},
    }
    for _, case in ipairs(cases) do
        local player = newPlayer()
        player.female = case[3]
        local bag = addBackpack(player, case[1])
        local amulet = player:getInventory():AddItem(chargedType)
        local neutralModel = amulet:getStaticModel()
        local expected = "SuQingUndyingAmulet." .. case[2]
        equal(Equipment.hang(player, amulet), true, "mounts on " .. case[1])
        equal(amulet:getStaticModel(), expected, "picks the model for " .. case[1])
        equal(player:getAttachedItem(Locations.backpack), amulet, "mount refreshes the attachment")

        player.backpack = nil
        Equipment.syncAttachment(player)
        equal(amulet:getStaticModel(), neutralModel, "taking the bag off clears the temporary model")
        player.backpack = bag
        Equipment.syncAttachment(player)
        equal(amulet:getStaticModel(), expected, "wearing the bag again restores its model")
        equal(Equipment.unhang(player, amulet), true, "unmount succeeds for " .. case[1])
        equal(amulet:getStaticModel(), neutralModel, "unmounting returns the item's declared model")
    end
end

do
    local player = newPlayer()
    addBackpack(player, "Base.Bag_UnknownModStyle")
    local amulet = player:getInventory():AddItem(chargedType)
    local neutralModel = amulet:getStaticModel()
    equal(Equipment.hang(player, amulet), true, "an unknown bag still accepts an amulet")
    equal(amulet:getStaticModel(), neutralModel, "an unknown bag uses the unmodified model")
end

do
    local player = newPlayer()
    local bag = addBackpack(player, "Base.Bag_Schoolbag")
    local amulet = player:getInventory():AddItem(chargedType)
    local neutralModel = amulet:getStaticModel()
    equal(Equipment.hang(player, amulet), true, "prepares a mounted model for native transfer")
    bag:getInventory():Remove(amulet)
    -- Vanilla transfer can clear the attached item before the mod's next update.
    player:setAttachedItem(Locations.backpack, nil)
    Equipment.syncAttachment(player)
    equal(Equipment.findActive(player), nil, "a directly dropped amulet stops protecting")
    equal(amulet:getStaticModel(), neutralModel, "a native detach does not leave the mounted model on the item")
end

do
    local player = newPlayer()
    local worn = addWorn(player)
    local spare = player:getInventory():AddItem(chargedType)
    local declaredModel = worn:getStaticModel()
    Test.fire("OnPlayerUpdate", player)
    local attachments = 0
    for _ in pairs(player.attached) do attachments = attachments + 1 end
    equal(attachments, 0, "wearing the amulet creates no native attachment")
    equal(worn:getStaticModel(), declaredModel, "wearing leaves the declared backpack model available")
    equal(Equipment.findActive(player), worn, "the invisible worn amulet protects")
    equal(#Test.inventoryOptions({worn}), 0, "a worn item offers no custom visibility action")
    equal(#Test.inventoryOptions({collapsedStack(spare, worn)}), 0, "a grouped worn item offers no visibility action")
end

do
    local player = newPlayer()
    local inventory = player:getInventory()
    local worn = addWorn(player)
    local carried = inventory:AddItem(chargedType)
    local otherModel = inventory:AddItem(chargedType)
    local declaredModel = "SuQingUndyingAmulet.AmuletMounted"
    worn.model = declaredModel
    carried.model = declaredModel
    worn:setStaticModel("SuQingUndyingAmulet.AmuletChest_F")
    carried:setStaticModel("SuQingUndyingAmulet.AmuletChest_M")
    otherModel:setStaticModel("OtherMod.CustomPendant")

    Test.fire("OnCreatePlayer", 0, player)
    equal(worn:getStaticModel(), declaredModel, "load clears the legacy override on a worn amulet")
    equal(carried:getStaticModel(), declaredModel, "load clears the legacy override on a carried amulet")
    equal(otherModel:getStaticModel(), "OtherMod.CustomPendant", "load preserves another mod's override")
    equal(Equipment.findActive(player), worn, "a migrated worn amulet keeps protecting")
    local attachments = 0
    for _ in pairs(player.attached) do attachments = attachments + 1 end
    equal(attachments, 0, "migrating the old worn model creates no attachment")

    worn:setStaticModel("SuQingUndyingAmulet.AmuletChest_M")
    Test.fire("OnPlayerUpdate", player)
    equal(worn:getStaticModel(), declaredModel, "the currently worn amulet also strips a legacy override on update")
    worn:setStaticModel("OtherMod.CustomPendant")
    Test.fire("OnPlayerUpdate", player)
    equal(worn:getStaticModel(), "OtherMod.CustomPendant", "worn-item updates preserve another mod's override")
end

do
    local player = newPlayer()
    player.female = true
    local bag = addBackpack(player, "Base.Bag_Schoolbag")
    local worn = addWorn(player)
    local mounted = player:getInventory():AddItem(chargedType)
    equal(Equipment.hang(player, mounted), true, "another amulet can hang while one is worn")
    local attachments = 0
    for _, item in pairs(player.attached) do
        attachments = attachments + 1
        equal(item, mounted, "only the backpack amulet is visually attached")
    end
    equal(attachments, 1, "only one native attachment exists while both are equipped")
    equal(player:getAttachedItem(Locations.backpack), mounted, "the backpack amulet has a native attachment")
    equal(mounted:getStaticModel(), "SuQingUndyingAmulet.AmuletMountedSmallFemale", "the backpack retains its fitted model")
    local options = Test.inventoryOptions({worn})
    equal(#options, 1, "a worn amulet with a backpack offers only the backpack action")
    equal(options[1].name, hangText, "the visibility action is absent with a backpack")
    player.damage.health = 1
    damageEvent(player)
    equal(countType(player:getInventory(), brokenType), 1, "hidden worn amulet is consumed first")
    equal(countType(bag:getInventory(), chargedType), 1, "the other mount is not consumed")
    equal(player:getAttachedItem(Locations.backpack), mounted, "rescue leaves the independent backpack model")
    equal(Equipment.findActive(player), mounted, "the other amulet remains equipped")
end

-- The engine can give a player a group different from the registered Human group.
do
    local player = newPlayer()
    local group = Test.resetPlayerAttachmentGroup(player)
    damageEvent(player)
    Test.fire("OnPlayerUpdate", player)
    equal(group:getLocation(Locations.backpack), nil, "empty players need no custom attachment location")

    local bag = addBackpack(player, "Base.Bag_Schoolbag")
    local amulet = player:getInventory():AddItem(chargedType)
    equal(Equipment.hang(player, amulet), true, "mounting can register the slot on the actual group")
    equal(group:getLocation(Locations.backpack).name, "backpack_left", "registration uses the original model anchor")
    equal(player:getAttachedItem(Locations.backpack), amulet, "the new group shows the backpack model")

    group = Test.resetPlayerAttachmentGroup(player)
    equal(Equipment.findActive(player), amulet, "the saved mount protects before its model is restored")
    equal(group:getLocation(Locations.backpack), nil, "finding an active amulet leaves rendering to the update")
    Test.fire("OnPlayerUpdate", player)
    equal(player:getAttachedItem(Locations.backpack), amulet, "the update restores the model from the saved mount")

    group = Test.resetPlayerAttachmentGroup(player)
    player.damage.health = 1
    damageEvent(player)
    equal(player.damage.health, 100, "the backpack amulet still rescues with the slot missing")
    equal(countType(bag:getInventory(), brokenType), 1, "the rescue leaves one broken amulet in the backpack")
    equal(group:getLocation(Locations.backpack), nil, "consuming the only mount need not recreate the location")
    isProtected(player, true, "missing model slot does not prevent the protection window")
end

do
    local player = newPlayer()
    Test.resetPlayerAttachmentGroup(player)
    addWorn(player)
    player.damage.health = 1
    damageEvent(player)
    equal(player.damage.health, 100, "the worn pendant can rescue with the backpack location missing")
    equal(countType(player:getInventory(), brokenType), 1, "the worn pendant is consumed exactly once")
    isProtected(player, true, "wearing a pendant does not depend on backpack locations")
end

return Test.finish()
