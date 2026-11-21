SuQingUndyingAmulet = SuQingUndyingAmulet or {}
local Locations = {}
SuQingUndyingAmulet.EquipmentLocations = Locations

local pendantId = "suqing_undying_amulet:pendant"
Locations.backpack = "SuQingUndyingAmulet Backpack"

function Locations.getPendant()
    return ItemBodyLocation.get(ResourceLocation.of(pendantId))
end

BodyLocations.getGroup("Human"):getOrCreateLocation(Locations.getPendant())
AttachedLocations.getGroup("Human"):getOrCreateLocation(Locations.backpack):setAttachmentName("backpack_left")

return Locations
