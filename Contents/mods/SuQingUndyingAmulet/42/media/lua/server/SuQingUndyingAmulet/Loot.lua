require "Items/Distributions"

local itemType = "SuQingUndyingAmulet.UndyingAmulet"
local supplement = "suqingundyingamulet_loot"
local destinations = {
    armystorage = { militarycrate = "military" },
    jewelrystore = { displaycase = "jewelry" },
    jewelrystorage = { filingcabinet = "jewelry", locker = "jewelry", metal_shelves = "jewelry" },
}

local function registerLoot()
    local distribution = Distributions and Distributions[1]
    if not distribution or distribution[supplement] then return end

    -- Register independent pools so stock procedural lists and room quotas stay intact.
    distribution[supplement] = {
        military = { rolls = 1, ignoreZombieDensity = true, items = { itemType, 1.25 } },
        jewelry = { rolls = 1, ignoreZombieDensity = true, items = { itemType, 2.5 } },
    }
end

local function fillContainer(roomName, containerType, container)
    local room = destinations[roomName]
    local poolName = room and room[containerType]
    if not poolName or not container or isClient() or isServer() then return end
    if container:containsWithModule(itemType) then return end

    local pool = ItemPickerJava.getItemContainer(supplement, poolName, "", false)
    if pool then
        ItemPickerJava.rollItem(pool, container, false, nil, nil)
    end
end

Events.OnPreDistributionMerge.Add(registerLoot)
Events.OnFillContainer.Add(fillContainer)
