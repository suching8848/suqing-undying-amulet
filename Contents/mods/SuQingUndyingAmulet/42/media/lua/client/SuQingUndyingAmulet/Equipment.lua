require "SuQingUndyingAmulet/EquipmentLocations"
require "SuQingUndyingAmulet/BackpackAmuletAction"

local Locations = SuQingUndyingAmulet.EquipmentLocations
local BackpackAction = SuQingUndyingAmulet.BackpackAmuletAction
local Equipment = {}
SuQingUndyingAmulet.Equipment = Equipment

local amuletType = "SuQingUndyingAmulet.UndyingAmulet"
local brokenType = "SuQingUndyingAmulet.BrokenUndyingAmulet"
local bagItemKey = "SuQingUndyingAmuletItemId"
local amuletBagKey = "SuQingUndyingAmuletBackpackId"

local mountModelPrefix = "SuQingUndyingAmulet.AmuletMounted"
local previousMounts = {}
local retiredChestModels = {
    ["SuQingUndyingAmulet.AmuletChest_M"] = true,
    ["SuQingUndyingAmulet.AmuletChest_F"] = true,
}
local fittedMounts = {
    ["Base.Bag_Schoolbag"] = "Small",
    ["Base.Bag_Schoolbag_Kids"] = "Small",
    ["Base.Bag_Schoolbag_Medical"] = "Small",
    ["Base.Bag_Schoolbag_Patches"] = "Small",
    ["Base.Bag_Schoolbag_Travel"] = "Small",
    ["Base.Bag_NormalHikingBag"] = "Hiking",
    ["Base.Bag_HikingBag_Travel"] = "Hiking",
    ["Base.Bag_BigHikingBag"] = "BigHiking",
    ["Base.Bag_BigHikingBag_Travel"] = "BigHiking",
    ["Base.Bag_ALICEpack"] = "Military",
    ["Base.Bag_ALICEpack_Army"] = "Military",
    ["Base.Bag_ALICEpack_DesertCamo"] = "Military",
    ["Base.Bag_SurvivorBag"] = "Military",
}
local fittedModels = {}
for _, fit in pairs(fittedMounts) do
    local model = mountModelPrefix .. fit
    fittedModels[model] = true
    fittedModels[model .. "Female"] = true
end

local function isSinglePlayer()
    return not isClient() and not isServer()
end

local function owns(container, item)
    return container ~= nil and item ~= nil and item:getContainer() == container
        and container:getItems():contains(item)
end

local function isCharged(item)
    return item ~= nil and item:getFullType() == amuletType and not item:isBroken()
end

local function wornBackpack(player)
    local bag = player:getClothingItem_Back()
    if owns(player:getInventory(), bag) and bag:IsInventoryContainer() then
        return bag
    end
end

local function hungAmulet(bag, attached)
    if not bag or not bag:hasModData() then return end
    local id = bag:getModData()[bagItemKey]
    if type(id) ~= "number" then return end
    local inventory = bag:getInventory()
    local item = attached
    if not item or item:getID() ~= id or not owns(inventory, item) then
        item = inventory:getItemWithID(id)
    end
    if owns(inventory, item) and isCharged(item) and item:hasModData()
        and item:getModData()[amuletBagKey] == bag:getID() then
        return item
    end
end

local function clearOldChestModel(item)
    if not item or item:getFullType() ~= amuletType or not item:hasModData() then return end
    local data = item:getModData()
    if retiredChestModels[data.staticModel] then
        -- Older saves store the worn model as a native item override.
        data.staticModel = nil
    end
end

local function clearMountFit(item)
    if item:getFullType() ~= amuletType or not item:hasModData() then return false end
    local data = item:getModData()
    if not (fittedModels[data.staticModel] or retiredChestModels[data.staticModel]) then return false end

    -- The native setter stores its override in this field. Clearing it returns
    -- the item to the model declared in its script.
    data.staticModel = nil
    return true
end

local function applyMountFit(player, item, bag)
    local fit = fittedMounts[bag:getFullType()]
    if not fit then return clearMountFit(item) end

    local model = mountModelPrefix .. fit .. (player:isFemale() and "Female" or "")
    if item:getStaticModel() == model then return false end

    item:setStaticModel(model)
    return true
end

function Equipment.syncAttachment(player)
    if not player or not isSinglePlayer() then return end
    clearOldChestModel(player:getWornItem(Locations.getPendant()))
    local attached = player:getAttachedItem(Locations.backpack)
    local bag = wornBackpack(player)
    local item = hungAmulet(bag, attached)

    -- Direct transfers out of a worn bag cancel its mount. Removing the whole
    -- bag preserves the binding between the bag and the item it still contains.
    if not item and bag and bag:hasModData() then
        local data = bag:getModData()
        if data[bagItemKey] ~= nil then data[bagItemKey] = nil end
    end
    -- Native transfers can clear the attachment before this update runs.
    local previous = previousMounts[player]
    if previous and previous ~= item then
        clearMountFit(previous)
    end
    if attached and attached ~= item and attached ~= previous then
        clearMountFit(attached)
    end
    local modelChanged = item and applyMountFit(player, item, bag)
    previousMounts[player] = item
    if item ~= attached or modelChanged then
        player:setAttachedItem(Locations.backpack, item)
    end
end

function Equipment.findActive(player)
    if not player or not isSinglePlayer() then return end
    local worn = player:getWornItem(Locations.getPendant())
    if owns(player:getInventory(), worn) and isCharged(worn) then
        return worn
    end
    return hungAmulet(wornBackpack(player), player:getAttachedItem(Locations.backpack))
end

local function moveItem(item, source, destination)
    if source == destination then return true end
    if destination:getItemWithID(item:getID()) then return false end

    source:Remove(item)
    if owns(source, item) then return false end

    destination:AddItem(item)
    if owns(destination, item) then return true end

    source:AddItem(item)
    return false
end

local function clearMount(bag, item)
    if bag and bag:hasModData() then
        local bagData = bag:getModData()
        if bagData[bagItemKey] == item:getID() then
            bagData[bagItemKey] = nil
        end
    end
    if item:hasModData() then
        item:getModData()[amuletBagKey] = nil
    end
end

local function hangContainers(player, item, expectedBag)
    if not player or not isSinglePlayer() or not isCharged(item) then return end
    local bag = wornBackpack(player)
    if not bag or (expectedBag and bag ~= expectedBag) or hungAmulet(bag) then return end

    local inventory = player:getInventory()
    local destination = bag:getInventory()
    local source = item:getContainer()
    if (source ~= inventory and source ~= destination) or not owns(source, item) then return end
    if source ~= destination and not destination:hasRoomFor(player, item) then return end
    return source, destination, bag
end

function Equipment.canHang(player, item, expectedBag)
    return hangContainers(player, item, expectedBag) ~= nil
end

function Equipment.hang(player, item, expectedBag)
    local source, destination, bag = hangContainers(player, item, expectedBag)
    if not source or not moveItem(item, source, destination) then return false end

    if player:getWornItem(Locations.getPendant()) == item then
        player:removeWornItem(item)
    end
    item:getModData()[amuletBagKey] = bag:getID()
    bag:getModData()[bagItemKey] = item:getID()
    Equipment.syncAttachment(player)
    return true
end

local function unhangContainers(player, item, expectedBag)
    if not player or not isSinglePlayer() or not item then return end
    local bag = wornBackpack(player)
    if not bag or (expectedBag and bag ~= expectedBag) or hungAmulet(bag) ~= item then return end

    local inventory = player:getInventory()
    if not inventory:hasRoomFor(player, item) then return end
    return bag:getInventory(), inventory, bag
end

function Equipment.canUnhang(player, item, expectedBag)
    return unhangContainers(player, item, expectedBag) ~= nil
end

function Equipment.unhang(player, item, expectedBag)
    local source, destination, bag = unhangContainers(player, item, expectedBag)
    if not source or not moveItem(item, source, destination) then return false end

    clearMount(bag, item)
    Equipment.syncAttachment(player)
    return true
end

function Equipment.consume(player, item)
    if not item or Equipment.findActive(player) ~= item then return false end
    local owner = item:getContainer()
    local broken = instanceItem(brokenType)
    if not broken or owner:getItemWithID(broken:getID()) then return false end

    owner:AddItem(broken)
    if not owns(owner, broken) then return false end

    owner:Remove(item)
    if owns(owner, item) then
        owner:Remove(broken)
        return false
    end

    if player:getWornItem(Locations.getPendant()) == item then
        player:removeWornItem(item)
    end
    clearMount(wornBackpack(player), item)
    Equipment.syncAttachment(player)
    return true
end

local function addUnavailable(context, text, reason)
    local option = context:addOption(getText(text))
    option.notAvailable = true
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = getText(reason)
    option.toolTip = tooltip
end

local function addInventoryOptions(playerIndex, context, selection)
    if not isSinglePlayer() then return end
    local items = ISInventoryPane.getActualItems(selection)
    if #items == 0 then return end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    local bag = wornBackpack(player)
    if not bag then return end

    local inventory = player:getInventory()
    local destination = bag:getInventory()
    local worn = player:getWornItem(Locations.getPendant())
    local attached = hungAmulet(bag)
    local selectedAttached, selectedLoose, selectedWorn
    -- A collapsed inventory row expands to every real item in that stack.
    -- Prefer an unmounted spare so hanging from a stack leaves a worn pendant in place.
    for _, candidate in ipairs(items) do
        if not isCharged(candidate) then return end
        if candidate == attached then
            selectedAttached = candidate
        elseif owns(inventory, candidate) or owns(destination, candidate) then
            if candidate == worn then
                selectedWorn = candidate
            else
                selectedLoose = selectedLoose or candidate
            end
        end
    end
    local item = selectedAttached or selectedLoose or selectedWorn
    if not item then return end

    if item == attached then
        if inventory:hasRoomFor(player, item) then
            context:addOption(getText("ContextMenu_SQUA_RemoveFromBackpack"), player, BackpackAction.enqueue, item, bag, true)
        end
    elseif attached then
        addUnavailable(context, "ContextMenu_SQUA_HangOnBackpack", "ContextMenu_SQUA_AlreadyHung")
    elseif owns(inventory, item) and not destination:hasRoomFor(player, item) then
        addUnavailable(context, "ContextMenu_SQUA_HangOnBackpack", "ContextMenu_SQUA_BackpackFull")
    else
        context:addOption(getText("ContextMenu_SQUA_HangOnBackpack"), player, BackpackAction.enqueue, item, bag, false)
    end
end

local function onCreatePlayer(_, player)
    if not player or not isSinglePlayer() then return end
    local inventory = player:getInventory():getItems()
    for index = 0, inventory:size() - 1 do
        clearOldChestModel(inventory:get(index))
    end
end

if Events then
    Events.OnFillInventoryObjectContextMenu.Add(addInventoryOptions)
    Events.OnCreatePlayer.Add(onCreatePlayer)
    Events.OnPlayerUpdate.Add(Equipment.syncAttachment)
    Events.OnMainMenuEnter.Add(function() previousMounts = {} end)
end

return Equipment
