require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

SuQingUndyingAmulet = SuQingUndyingAmulet or {}
local BackpackAction = ISBaseTimedAction:derive("SuQingUndyingAmuletBackpackAction")
SuQingUndyingAmulet.BackpackAmuletAction = BackpackAction

function BackpackAction:isValid()
    if self.finished or self.item:getContainer() ~= self.source then return false end
    local equipment = SuQingUndyingAmulet.Equipment
    if self.removing then
        return equipment.canUnhang(self.character, self.item, self.bag)
    end
    return equipment.canHang(self.character, self.item, self.bag)
end

function BackpackAction:isValidStart()
    return self:isValid()
end

function BackpackAction:start()
    local key = self.removing and "IGUI_SQUA_RemovingAmulet" or "IGUI_SQUA_HangingAmulet"
    self.item:setJobType(getText(key))
    self.item:setJobDelta(0)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function BackpackAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function BackpackAction:stop()
    self.finished = true
    self.item:setJobDelta(0)
    ISBaseTimedAction.stop(self)
end

function BackpackAction:forceCancel()
    self.finished = true
end

function BackpackAction:perform()
    self.item:setJobDelta(0)
    ISBaseTimedAction.perform(self)
end

function BackpackAction:complete()
    local valid = self:isValid()
    self.finished = true
    if not valid then return false end
    local equipment = SuQingUndyingAmulet.Equipment
    if self.removing then
        return equipment.unhang(self.character, self.item, self.bag)
    end
    return equipment.hang(self.character, self.item, self.bag)
end

function BackpackAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 50
end

function BackpackAction:new(player, item, bag, removing)
    local action = ISBaseTimedAction.new(self, player)
    action.item = item
    action.bag = bag
    action.source = item:getContainer()
    action.removing = removing
    action.stopOnWalk = true
    action.stopOnRun = true
    action.useProgressBar = true
    action.maxTime = action:getDuration()
    return action
end

function BackpackAction.enqueue(player, item, bag, removing)
    if not player or not item or not bag then return end
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    for _, queued in ipairs(queue.queue) do
        if queued.Type == BackpackAction.Type then return end
    end

    local action = BackpackAction:new(player, item, bag, removing)
    if action:isValidStart() then
        ISTimedActionQueue.add(action)
    end
end

return BackpackAction
