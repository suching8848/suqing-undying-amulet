local locationId = "suqing_undying_amulet:pendant"

if not ItemBodyLocation.get(ResourceLocation.of(locationId)) then
    ItemBodyLocation.register(locationId)
end
