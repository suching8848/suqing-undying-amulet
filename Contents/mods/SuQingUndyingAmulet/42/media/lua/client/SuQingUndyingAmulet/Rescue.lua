require "SuQingUndyingAmulet/Equipment"

local Equipment = SuQingUndyingAmulet.Equipment
local Rescue = {}
SuQingUndyingAmulet.Rescue = Rescue

local TRIGGER_HEALTH = 1
local PROTECTION_MS = 3000
local SAVE_MARKER = "SuQingUndyingAmuletProtection"
local protectedPlayers = {}
local activating = {}

local function healWounds(player, damage)
    local parts = damage:getBodyParts()
    for index = 0, parts:size() - 1 do
        local part = parts:get(index)
        -- The part-level helper heals wounds and leaves its thermal node
        -- intact. Keep its separate Knox flags and exercise stiffness.
        local infected = part:IsInfected()
        local fakeInfected = part:IsFakeInfected()
        local stiffness = part:getStiffness()
        part:RestoreToFullHealth()
        if infected then
            part:SetInfected(true)
        end
        if fakeInfected then
            part:SetFakeInfected(true)
        end
        if stiffness ~= 0 then
            part:setStiffness(stiffness)
        end
    end
    damage:setOverallBodyHealth(100)
    player:setHealth(100)
end

local function notify(player, key)
    if HaloTextHelper then
        HaloTextHelper.addText(player, getText(key), " ", 198, 153, 255)
    end
end

local function getActionState(player)
    return string.lower(player:getCurrentActionContextStateName() or "")
end

local function isDragDown(player, actionState)
    return player:isDeathDragDown() or player:getHitReaction() == "EndDeath"
        or (actionState or getActionState(player)) == "hitreaction-enddeath"
end

local function releaseZombieGrapple(player)
    if not (player.getGrappledBy and player.isBeingGrappled and player:isBeingGrappled()) then
        return
    end
    local grappler = player:getGrappledBy()
    if grappler and instanceof(grappler, "IsoZombie") then
        if grappler.LetGoOfGrappled then
            grappler:LetGoOfGrappled("SuQingUndyingAmulet")
        elseif grappler.setDoGrappleLetGo then
            grappler:setDoGrappleLetGo()
        end
    end
end

local function forgetTarget(zombie, player)
    local target = zombie:getTarget()
    if target == player or (not target and zombie:isLeadAggro(player)) then
        zombie:setTarget(nil)
        zombie:setTargetSeenTime(0)
        zombie:clearAggroList()
    end
end

local function clearZombieControl(player)
    releaseZombieGrapple(player)
    local attacker = player:getAttackedBy()
    local actionState = getActionState(player)
    local dragDown = isDragDown(player, actionState)
    local zombieAttacker = attacker and instanceof(attacker, "IsoZombie")
    local bitten = actionState == "hitreaction-bite" or actionState == "hitreaction-crawlerbite"
    if zombieAttacker then
        forgetTarget(attacker, player)
    end
    if dragDown or bitten or zombieAttacker then
        -- PlayerHitReactionState ignores its queued Death event when the
        -- attacker is cleared. Only unlock movement for that zombie reaction.
        player:setAttackedBy(nil)
        if dragDown or bitten or player:getHitReaction() ~= "" then
            player:setDeathDragDown(false)
            player:setHitReaction("")
            player:setBlockMovement(false)
            player:setIgnoreMovement(false)
        end
        if actionState == "hitreaction-enddeath" or bitten or (actionState == "hitreaction" and zombieAttacker) then
            -- A running EndDeath action would otherwise only leave via the
            -- on-ground transition. Restrict the reset to zombie reactions.
            player:setDefaultState()
        end
    end
end

local function clearZombieTargets(player)
    local cell = player:getCell()
    local zombies = cell and cell:getZombieList()
    if zombies then
        for index = 0, zombies:size() - 1 do
            forgetTarget(zombies:get(index), player)
        end
    end
end

local function applyFlags(player, protection)
    if protection.ownsGhostMode and not player:isGhostMode() then
        -- Covers player writes that can bypass the world OnSave callback.
        player:getModData()[SAVE_MARKER] = { ownsGhostMode = true }
        player:setGhostMode(true, true)
    end
end

local function releaseFlags(player, protection)
    if protection.ownsGhostMode then
        player:setGhostMode(false, true)
    end
end

local function endProtection(player, showNotice)
    local protection = protectedPlayers[player]
    if not protection then
        return
    end
    protectedPlayers[player] = nil
    releaseFlags(player, protection)
    player:getModData()[SAVE_MARKER] = nil
    if showNotice then
        notify(player, "IGUI_SuQingUndyingAmulet_ProtectionEnded")
    end
end

local function takeProtection(player)
    local protection = {
        ownsGhostMode = not player:isGhostMode(),
        remaining = PROTECTION_MS,
        lastTimestamp = getTimestampMs(),
        wasPaused = isGamePaused(),
    }
    protectedPlayers[player] = protection
    applyFlags(player, protection)
    clearZombieControl(player)
    clearZombieTargets(player)
end

local function isLocalCharacter(player)
    return not isClient() and not isServer() and player
        and instanceof(player, "IsoPlayer") and player:isLocalPlayer()
end

-- Many OnPlayerGetDamage events fire after part damage but before the game
-- updates total health. Read the parts without forcing an early recalculation.
local function pendingHealth(player, damage)
    local parts = damage:getBodyParts()
    local injury = 0
    for index = 0, parts:size() - 1 do
        injury = injury + (100 - parts:get(index):getHealth()) * BodyPartType.getDamageModifyer(index)
    end
    local pills = player:getSleepingPillsTaken()
    if pills >= 10 then
        injury = injury + (pills >= 12 and 100 or (pills - 9) * 40)
    end
    return 100 - injury
end

local function protectHealth(player, inspectPendingDamage)
    if player:isDead() or player:isOnKillDone() or player:isOnDeathDone() then
        return
    end
    local damage = player:getBodyDamage()
    if damage and (damage:getOverallBodyHealth() < 100 or player:getHealth() < 100
        or (inspectPendingDamage and pendingHealth(player, damage) < 100)) then
        healWounds(player, damage)
    end
end

local function tryRescue(player, inspectPendingDamage)
    if not isLocalCharacter(player) or activating[player] or protectedPlayers[player]
        or player:isDead() or player:isOnKillDone() or player:isOnDeathDone() then
        return
    end
    local damage = player:getBodyDamage()
    if not damage then
        return
    end
    local trigger = isDragDown(player) or damage:getOverallBodyHealth() <= TRIGGER_HEALTH
    if not trigger and not inspectPendingDamage then
        return
    end
    local amulet = Equipment.findActive(player)
    if not amulet or (not trigger and pendingHealth(player, damage) > TRIGGER_HEALTH) then
        return
    end
    activating[player] = true
    local ok, result = pcall(function()
        if Equipment.consume(player, amulet) then
            healWounds(player, damage)
            takeProtection(player)
            return true
        end
        return false
    end)
    activating[player] = nil
    if not ok then
        endProtection(player, false)
        error(result)
    elseif result then
        notify(player, "IGUI_SuQingUndyingAmulet_Activated")
    end
end

local function updateProtection(player, protection)
    local paused = isGamePaused()
    local timestamp = getTimestampMs()
    if not paused and not protection.wasPaused and not protection.suspended then
        protection.remaining = protection.remaining - math.max(0, timestamp - protection.lastTimestamp)
    end
    protection.suspended = false
    protection.lastTimestamp = timestamp
    protection.wasPaused = paused
    local dead = player:isDead()
    if protection.remaining <= 0 or dead then
        endProtection(player, not dead)
    else
        applyFlags(player, protection)
        protectHealth(player, false)
    end
end

local function onCharacterChange(player, inspectPendingDamage)
    local protection = protectedPlayers[player]
    if protection then
        if protection.suspended then
            updateProtection(player, protection)
        end
        if protectedPlayers[player] then
            clearZombieControl(player)
            protectHealth(player, inspectPendingDamage)
        end
        return
    end
    tryRescue(player, inspectPendingDamage)
end

local function onDamage(player)
    onCharacterChange(player, true)
end

local function onPlayerUpdate(player)
    onCharacterChange(player, false)
end

local function onTickEvenPaused()
    for player, protection in pairs(protectedPlayers) do
        updateProtection(player, protection)
    end
end

local function onPostUIDraw()
    for player, protection in pairs(protectedPlayers) do
        local playerNum = player:getPlayerNum()
        if protection.remaining > 0 and getSpecificPlayer(playerNum) == player then
            local seconds = math.ceil(protection.remaining / 1000)
            local label = getText("IGUI_SuQingUndyingAmulet_Countdown", tostring(seconds))
            local x = getPlayerScreenLeft(playerNum) + getPlayerScreenWidth(playerNum) / 2
            local y = getPlayerScreenTop(playerNum) + 72
            local text = getTextManager()
            text:DrawStringCentre(UIFont.Medium, x + 1, y + 1, label, 0.04, 0.02, 0.07, 0.9)
            text:DrawStringCentre(UIFont.Medium, x, y, label, 0.91, 0.82, 1, 1)
        end
    end
end

local function onSave()
    for player, protection in pairs(protectedPlayers) do
        -- Keep our temporary Ghost Mode out of normal world saves. Ignore time
        -- spent serializing and reapply on the first callback after the save.
        protection.suspended = true
        releaseFlags(player, protection)
        player:getModData()[SAVE_MARKER] = nil
    end
end

local function onPostSave()
    for player, protection in pairs(protectedPlayers) do
        if protection.suspended then
            updateProtection(player, protection)
        end
    end
end

local function onCreatePlayer(_, player)
    if not isLocalCharacter(player) then
        return
    end
    local data = player:getModData()
    local marker = data[SAVE_MARKER]
    if marker and not protectedPlayers[player] then
        releaseFlags(player, marker)
        -- Version 0.2 used the game's full God Mode during protection.
        if marker.ownsGodMode then
            player:setInvulnerable(false)
        end
        if marker.survival then
            local stats = player:getStats()
            for name, value in pairs(marker.survival) do
                stats:set(CharacterStat[name], value)
            end
        end
        data[SAVE_MARKER] = nil
    end
end

local function onMainMenu()
    for player in pairs(protectedPlayers) do
        endProtection(player, false)
    end
end

local function onDeath(player)
    endProtection(player, false)
end

Events.OnPlayerGetDamage.Add(onDamage)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnTickEvenPaused.Add(onTickEvenPaused)
Events.OnPostUIDraw.Add(onPostUIDraw)
Events.OnSave.Add(onSave)
Events.OnPostSave.Add(onPostSave)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnMainMenuEnter.Add(onMainMenu)
Events.OnPlayerDeath.Add(onDeath)

return Rescue

