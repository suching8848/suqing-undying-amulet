-- Load this fixture, then the mod's Loot.lua, then call RunAmuletLootTests().
local amulet = "SuQingUndyingAmulet.UndyingAmulet"
local onMerge, onFill
local client, server = false, false
local stockCrate = { procedural = true, procList = { { name = "ArmyStorageOutfit", min = 0, max = 99 } } }
local stockDisplay = { procedural = true, procList = { { name = "JewelryGold", min = 1, max = 99 } } }
local stock = {
    armystorage = { militarycrate = stockCrate },
    jewelrystore = { displaycase = stockDisplay },
}
Distributions = { stock }
Events = {
    OnPreDistributionMerge = { Add = function(callback) onMerge = callback end },
    OnFillContainer = { Add = function(callback) onFill = callback end },
}

function require(name) assert(name == "Items/Distributions") end
function isClient() return client end
function isServer() return server end

local rolled, poolUnavailable
ItemPickerJava = {}
function ItemPickerJava.getItemContainer(room, tier, procedural, junk)
    assert(procedural == "" and junk == false)
    local pools = Distributions[1][room]
    if pools and not poolUnavailable then return pools[tier] end
end
function ItemPickerJava.rollItem(pool, container, allowNested, player, stockRoom)
    assert(not allowNested and player == nil and stockRoom == nil)
    rolled = pool
    container.calls = container.calls + 1
end

function RunAmuletLootTests()
    local checks = 0
    local function equal(actual, expected, description)
        checks = checks + 1
        assert(actual == expected, description)
    end
    local function newContainer(hasItem)
        return {
            calls = 0,
            containsWithModule = function(_, itemType)
                assert(itemType == amulet)
                return hasItem == true
            end,
        }
    end

    equal(type(onMerge), "function", "the mod subscribes before native distribution merge")
    equal(type(onFill), "function", "the mod subscribes to native container fills")
    local container = newContainer()
    onFill("armystorage", "militarycrate", container)
    equal(container.calls, 0, "no roll before the private pool exists")

    onMerge()
    local pools = stock.suqingundyingamulet_loot
    onMerge()
    equal(stock.suqingundyingamulet_loot, pools, "a repeated merge does not add or replace the pool")
    equal(stock.armystorage.militarycrate, stockCrate, "stock military procedural table is kept")
    equal(stock.jewelrystore.displaycase, stockDisplay, "stock jewelry procedural table is kept")
    equal(stockCrate.procList[1].name, "ArmyStorageOutfit", "stock military quota key is kept")
    equal(stockDisplay.procList[1].min, 1, "stock jewelry quota is kept")

    onFill("armystorage", "militarycrate", container)
    equal(container.calls, 1, "a military camp crate receives one native bonus roll")
    equal(rolled, pools.military, "the crate uses the dedicated low-weight pool")
    equal(rolled.rolls, 1, "military bonus has one roll")
    equal(#rolled.items, 2, "military bonus has one exact item-weight pair")
    equal(rolled.items[1], amulet, "military bonus rolls the intact amulet")
    equal(rolled.items[2], 1.25, "military base item weight")
    equal(rolled.ignoreZombieDensity, true, "military bonus does not rise with zombie density")

    for _, site in ipairs({
        { "jewelrystore", "displaycase" },
        { "jewelrystorage", "locker" },
        { "jewelrystorage", "filingcabinet" },
        { "jewelrystorage", "metal_shelves" },
    }) do
        container = newContainer()
        onFill(site[1], site[2], container)
        equal(container.calls, 1, "jewelry display or stock container gets one bonus roll")
        equal(rolled, pools.jewelry, "jewelry uses its dedicated higher-weight pool")
    end
    equal(rolled.rolls, 1, "jewelry bonus has one roll")
    equal(#rolled.items, 2, "jewelry bonus has one exact item-weight pair")
    equal(rolled.items[1], amulet, "jewelry bonus rolls the intact amulet")
    equal(rolled.items[2], 2 * pools.military.items[2], "jewelry base weight is twice the military weight")
    equal(rolled.ignoreZombieDensity, true, "jewelry bonus does not rise with zombie density")

    for _, site in ipairs({
        { "armystorage", "militarylocker" },
        { "armysurplus", "militarycrate" },
        { "jewelrystore", "cashregister" },
        { "jewelrystorage", "desk" },
        { "bedroom", "displaycase" },
        { "bedroom", "locker" },
        { "warehouse", "crate" },
        { "all", "militarycrate" },
    }) do
        container = newContainer()
        onFill(site[1], site[2], container)
        equal(container.calls, 0, "other rooms and containers are not affected")
    end

    local existing = newContainer(true)
    onFill("jewelrystore", "displaycase", existing)
    equal(existing.calls, 0, "a container with an intact amulet does not get a second one")
    container = newContainer()
    poolUnavailable = true
    onFill("armystorage", "militarycrate", container)
    equal(container.calls, 0, "an unavailable native pool safely skips")
    poolUnavailable = false
    client = true
    onFill("armystorage", "militarycrate", container)
    equal(container.calls, 0, "multiplayer client does not roll this single-player item")
    client = false
    server = true
    onFill("armystorage", "militarycrate", container)
    equal(container.calls, 0, "server does not roll this single-player item")
    server = false
    return "PASS " .. checks .. " loot checks"
end
