SuQingUndyingAmulet = SuQingUndyingAmulet or {}
local Locations = {}
SuQingUndyingAmulet.EquipmentLocations = Locations

local pendantId = "suqing_undying_amulet:pendant"
Locations.backpack = "SuQingUndyingAmulet Backpack"

function Locations.getPendant()
    return ItemBodyLocation.get(ResourceLocation.of(pendantId))
end

function Locations.registerBackpack(group)
    group:getOrCreateLocation(Locations.backpack):setAttachmentName("backpack_left")
end

BodyLocations.getGroup("Human"):getOrCreateLocation(Locations.getPendant())
Locations.registerBackpack(AttachedLocations.getGroup("Human"))

return Locations
