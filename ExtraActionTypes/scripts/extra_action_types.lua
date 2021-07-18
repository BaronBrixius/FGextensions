--Skills: stealth, acrobatics vs move through space
--Skill re-drops "chain" messages when
--Maybe add a little explanation when dropping skill (e.g. "demoralize"/"bluff"/"move through threatened square")
--TODO remove negative limit on spell point usage
--TODO Momentum??
--TODO Choose initiative

local OOB_MSGTYPE_OPPOSEDSKILL = "opposedskill";

local oldGetSpellAction;
local oldApplyDamage;
local oldOnEffectActorEndTurn;
local oldCustomOnEffectAddIgnoreCheck;
local oldApplyAttack;
local oldClearCritState;
local oldAddItemToList;
local oldCompareFields;
local oldPerformAction;
local oldGetHealRoll;
local oldGetDefenseValue;
local oldOnAttack;
local oldOnMissChance;
local oldOnMirrorImage;
local oldNotifyExpire;
local oldProcessEffect;
local oldOnImageInit;

function onInit()
    -- Opposed Skills
    OptionsManager.registerOption2("TARGETEDSKILLS", true, "option_header_client", "option_label_TARGETEDSKILLS", "option_entry_cycler", { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "on" });
    ActionsManager.registerModHandler("skill", newModSkill);
    ActionsManager.registerTargetingHandler("skill", onSkillTargeting);
    ActionsManager.registerResultHandler("skill", onSkillRoll);
    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_OPPOSEDSKILL, handleOpposedSkill);

    GameSystem.actions["skill"] = { sTargeting = "all", bUseModStack = true };
    table.insert(GameSystem.targetactions, "skill");

    --Spell Action Scaling
    oldGetSpellAction = SpellManager.getSpellAction;
    SpellManager.getSpellAction = newGetSpellAction;

    -- Effect Expires At End Of Turn
    oldOnEffectActorEndTurn = EffectManager.fCustomOnEffectActorEndTurn
    EffectManager.setCustomOnEffectActorEndTurn(newOnEffectActorEndTurn)

    -- Use Target Initiative For Effect
    oldCustomOnEffectAddIgnoreCheck = EffectManager.fCustomOnEffectAddIgnoreCheck;
    EffectManager.setCustomOnEffectAddIgnoreCheck(customOnEffectAddIgnoreCheckTargetInit);

    -- Vitality
    ActionSave.applySave = applySaveStalwartAndVitality;    --also Stalwart

    oldApplyAttack = ActionAttack.applyAttack;
    ActionAttack.applyAttack = newApplyAttack;

    oldClearCritState = ActionAttack.clearCritState;
    ActionAttack.clearCritState = clearCritAndVitalityLossState;

    -- Auto Identify
    oldAddItemToList = ItemManager.addItemToList;
    ItemManager.addItemToList = newAddItemToList;
    OptionsManager.registerOption2("AUTOIDENTIFY", false, "option_header_game", "option_label_AUTOIDENTIFY", "option_entry_cycler", { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });

    oldCompareFields = ItemManager.compareFields;
    ItemManager.compareFields = newCompareFields;

    -- Temp HP Changes & Auto Concentration
    oldGetHealRoll = ActionHeal.getRoll;
    ActionHeal.getRoll = newGetHealRoll;

    oldApplyDamage = ActionDamage.applyDamage;
    ActionDamage.applyDamage = newApplyDamage;

    -- Auto Concentration
    oldPerformAction = ActionsManager.performAction;
    ActionsManager.performAction = newPerformAction;
    ActionsManager.registerResultHandler("concentration", handleConcentrationCheck);

    -- Combo Hotkeys
    OptionsManager.registerOption2("COMBOHOTKEYS", true, "option_header_client", "option_label_COMBOHOTKEYS", "option_entry_cycler", { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
    Interface.onHotkeyDrop = onHotkeyDrop;
    Interface.onHotkeyActivated = onHotkey;

    -- Scaling Miss Chance
    table.insert(DataCommon.targetableeffectcomps, "MISS");
    oldGetDefenseValue = ActorManager35E.getDefenseValue;
    ActorManager35E.getDefenseValue = getMissChanceDefenseValue;

    --Fix crit confirmation applying atk effects twice
    oldOnAttack = ActionAttack.onAttack;
    ActionAttack.onAttack = newOnAttack;
    ActionsManager.registerResultHandler("critconfirm", newOnAttack);

    oldOnMissChance = ActionAttack.onMissChance;
    ActionAttack.onMissChance = newOnMissChance;
    ActionsManager.registerResultHandler("misschance", newOnMissChance);

    -- Mirror Image insert
    if MirrorImageHandler then
        oldOnMirrorImage = MirrorImageHandler.onMirrorImage;
        MirrorImageHandler.onMirrorImage = newOnMirrorImage;
        ActionsManager.registerResultHandler("mirrorimage", newOnMirrorImage);
    end

    -- Once Per Turn Effects
    oldNotifyExpire = EffectManager.notifyExpire;
    EffectManager.notifyExpire = newNotifyExpire;

    oldProcessEffect = EffectManager.processEffect;
    EffectManager.processEffect = newProcessEffect;

    -- Auto Aura Application
    EffectManager.setCustomOnEffectAddEnd(applyNewAuraToOthers);

    -- Click On Map Clears Targets
    if UtilityManager.isClientFGU() then
        OptionsManager.registerOption2("CLICKMAPREMOVESTARGETS", true, "option_header_client", "option_label_CLICKMAPREMOVESTARGETS", "option_entry_cycler", { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
        oldOnImageInit = ImageManager.onImageInit;
        ImageManager.onImageInit = newOnImageInit;
    end
end

function applyNewAuraToOthers(nodeTargetEffect, rNewEffect)
    if not EffectManagerAURA or not string.find(rNewEffect.sName, "^AURA:") then
        return;
    end

    local nodeCT = nodeTargetEffect.getParent().getParent();
    local ctEntries = CombatManager.getSortedCombatantList();
    for _, node in pairs(ctEntries) do
        if node ~= nodeCT then
            EffectManagerAURA.checkAuraApplicationAndAddOrRemove(node, nodeCT, nodeTargetEffect);
        end
    end

end

function newOnAttack(rSource, rTarget, rRoll)
    if rRoll.sType == "critconfirm" then   -- remove [EFFECTS +X] tag as it was applying a second time to crit confirmations
        rRoll.sDesc = rRoll.sDesc:gsub("%[" .. Interface.getString("effects_tag") .. " %+%d-%] ", "")
    end

    oldOnAttack(rSource, rTarget, rRoll);
end

function newAddItemToList(vList, sClass, vSource, bTransferAll, nTransferCount)
    local nodeNew = oldAddItemToList(vList, sClass, vSource, bTransferAll, nTransferCount);

    if User.isHost() and OptionsManager.getOption("AUTOIDENTIFY"):lower() == "on" and ItemManager.getItemSourceType(DB.createNode(vList)) == "partysheet" then
        DB.setValue(nodeNew, "isidentified", "number", 1);
    end

    return nodeNew;
end

function newCompareFields(node1, node2, bTop)
    if User.isHost() and OptionsManager.getOption("AUTOIDENTIFY"):lower() == "on" and ItemManager.getItemSourceType(node2) == "partysheet" then
        DB.setValue(node2, "isidentified", "number", 1);
    end

    return oldCompareFields(node1, node2, bTop);
end

function newOnEffectActorEndTurn(nodeActor, nodeEffect)
    if oldOnEffectActorEndTurn and oldOnEffectActorEndTurn(nodeActor, nodeEffect) then
        return true;
    end

    -- Delayed Damage Pool
    local sEffectLabel = DB.getValue(nodeEffect, "label", "");
    if string.find(sEffectLabel, "Delayed:", 1, true) then
        local nCurrPoolDamage = tonumber(string.match(sEffectLabel, "Delayed: (%-?%d+)/%d+"));
        if nCurrPoolDamage > 0 then
            local sDamage = "[DAMAGE] Delayed Damage Pool [TYPE: spell";
            if string.find(sEffectLabel, "nonlethal") or string.find(sEffectLabel, " nl") or string.find(sEffectLabel, " endur") then
                sDamage = sDamage .. ", nonlethal";
            end
            sDamage = sDamage .. " (" .. nCurrPoolDamage ..")]";

            oldApplyDamage(nodeActor, nodeActor, false, "damage", sDamage, nCurrPoolDamage);
            DB.setValue(nodeEffect, "label", "string", sEffectLabel:gsub("Delayed: %d+", "Delayed: 0"));
        end
    end

    -- alternate version that directly manipulates hp values rather than generating a fake onDamage instance, might need to swap to it after testing
        --DB.setValue(nodeEffect, "label", "string", sEffectLabel:gsub("Delayed: %-?%d+", "Delayed: 0"));
        --local nodeActor = ActorManager.getCreatureNode(rActor);
        --
        --if string.find(sEffectLabel, " nonlethal") or string.find(sEffectLabel, " nl") then
        --    DB.setValue(nodeActor, "hp.nonlethal", "number", DB.getValue(nodeActor, "hp.nonlethal", 0) + nCurrPoolDamage);
        --else
        --    local nCurrTempHealth = DB.getValue(nodeActor, "hp.temporary", 0);
        --    local nTempHealthToDamage = math.min(nCurrPoolDamage, nCurrTempHealth);
        --    DB.setValue(nodeActor, "hp.temporary", "number", nCurrTempHealth - nTempHealthToDamage);
        --
        --    nCurrPoolDamage = nCurrPoolDamage - nTempHealthToDamage;
        --    DB.setValue(nodeActor, "hp.wounds", "number", DB.getValue(nodeActor, "hp.wounds", 0) + nCurrPoolDamage);
        --end

    --If an effect's duration is less than 1, expire it (e.g. set duration as 1.5 for it to last 1 round but expire at end of turn)
    local nDuration = DB.getValue(nodeEffect, "duration");
    if nDuration > 0 and nDuration < 1 then
        EffectManager.expireEffect(nodeActor, nodeEffect);
        return true;
    end

    return false;
end

function newApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)
    if string.match(sDamage, "%[TYPE: delayed") then    -- directly manipulate delayed damage pool. no validation, just let users go nuts
        for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rTarget), "effects")) do
            local sEffectLabel = DB.getValue(nodeEffect, "label", "");
            if string.find(sEffectLabel, "^Delayed:") then
                local nCurrPoolDamage = tonumber(string.match(sEffectLabel, "Delayed: (%d+)/%d+"));
                local sNewEffectLabel = sEffectLabel:gsub("Delayed: %-?%d+", "Delayed: " .. (nCurrPoolDamage + nTotal));
                DB.setValue(nodeEffect, "label", "string", sNewEffectLabel);
                break;
            end
        end
        return;
    end

    local nHealthBeforeAttack, nTempHealthBeforeAttack = getTotalHP(rTarget);

    if ActorManager35E.isCreatureType(rTarget, "undead") then
        sRollType, sDamage, nTotal = applyUndeadEnergyInversion(rSource, rTarget, bSecret, sRollType, sDamage, nTotal);
    end

    if sDamage:match("%[TEMP%]") then
        nTotal = applyTempHPChanges(nTotal, rTarget, sDamage)
    end

    oldApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal);

    local nHealthAfterAttack, nTempHealthAfterAttack = getTotalHP(rTarget);
    local nHealthLost = (nHealthBeforeAttack + nTempHealthBeforeAttack) - (nHealthAfterAttack + nTempHealthAfterAttack);
    if nHealthLost > 0 then
        if string.find(sDamage, "Ongoing", 1, true) then
            --todo this isn't supposed to roll if effect just expired
            nHealthLost = math.max(1, math.floor(nHealthLost / 2))
        elseif wasHitByAttackOrFailedSave(rTarget) then
            setVitalityLossState(rTarget, false);
            removeVitalityEffects(rTarget);
        end

        for _, rEffect in ipairs(getConcentrationEffects(rTarget)) do
            forceConcentrationCheck(rTarget, rEffect, nHealthLost)
        end
    end

    applyDelayedDamagePool(nTotal, nHealthLost, nTempHealthBeforeAttack - nTempHealthAfterAttack, rTarget, sRollType, sDamage)
end

function applyUndeadEnergyInversion(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)
    if sRollType == "heal" then
        local sNewDamage = sDamage:gsub("%[HEAL", "[DAMAGE") .." [TYPE: positive, spell (" .. nTotal .. ")]";
        if ActionAttack.isCrit(rSource, rTarget) or ModifierStack.getModifierKey("DMG_CRIT") or Input.isShiftPressed() then
            sNewDamage = sNewDamage:gsub("%[TYPE", "[CRITICAL] [TYPE") .. " [TYPE: positive, spell, critical (" .. nTotal .. ")]";
            nTotal = nTotal * 2;
        end
        return "spdamage", sNewDamage, nTotal;
    end

    if sRollType:find("damage") and sDamage:find("negative", 1, 1) then
        local nNegativeDamage = 0;
        local nOtherDamage = 0;
        for sDamageType in sDamage:gmatch("%[TYPE: ([^%]]+)%]") do
            local nDmgTypeTotal = tonumber(sDamageType:match(".-(%d+)%)")) or 0;

            if sDamageType:find("negative", 1, 1) then
                nNegativeDamage = nNegativeDamage + nDmgTypeTotal;
            else
                nOtherDamage = nOtherDamage + nDmgTypeTotal;
            end
        end

        if nOtherDamage > 0 then
            newApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage:gsub("%[TYPE[^%]]-negative.-%)%]", ""), nOtherDamage)
        end

        if nNegativeDamage > 0 then
            if sDamage:find("[CRITICAL]",1,1) then
                nNegativeDamage = nNegativeDamage / 2;
            end
            return "heal", sDamage:gsub("%[DAMAGE", "[HEAL"):gsub("%[TYPE.*", ""), nNegativeDamage;
        end
    end

    return sRollType, sDamage, nTotal;
end

function getTotalHP(rActor) --todo make this work for NPCs if I care
    local nodeTarget = ActorManager.getCreatureNode(rActor);
    return DB.getValue(nodeTarget, "hp.total", 0) - DB.getValue(nodeTarget, "hp.wounds", 0),
           DB.getValue(nodeTarget, "hp.temporary", 0);
end

function applyTempHPChanges(nTotal, rTarget, sDamage)
    local sTargetType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
    if sTargetType ~= "pc" and sTargetType ~= "ct" then
        return ;
    end

    local nTempHP, nWounds;
    if sTargetType == "pc" then
        nTempHP = DB.getValue(nodeTarget, "hp.temporary", 0);
        nWounds = DB.getValue(nodeTarget, "hp.wounds", 0);
    else
        nTempHP = DB.getValue(nodeTarget, "hptemp", 0);
        nWounds = DB.getValue(nodeTarget, "wounds", 0);
    end

    if sDamage:match("%[PAINKILLER%]") then --painkiller heals an amount of nonlethal equal to the max invigorate value
        DB.setValue(nodeTarget, "hp.nonlethal", "number", math.max(0, DB.getValue(nodeTarget, "hp.nonlethal", 0) - nTotal));
    end

    --Invigorate cannot raise a target's total (temp + current) hit points above their max hit points
    if sDamage:find("[INVIGORATE]", 1, 1) or sDamage:find("[PAINKILLER]", 1, 1) then
        nTotal = math.min(nTotal, nWounds);
    end

    if not sDamage:match("%[STACKING%]") then
        nTotal = math.max(nTotal - nTempHP, 0);
    end
    return nTotal;
end

function applyDelayedDamagePool(nTotal, nHealthLost, nTempHealthLost, rTarget, sRollType, sDamage)
    if string.match(sDamage, "%[TEMP%]") or nTotal == 0 then
        return;
    end

    local rDelayedDamagePoolEffect, nCurrPoolDamage, nTotalPool;
    for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rTarget), "effects")) do
        local sEffectLabel = DB.getValue(nodeEffect, "label", "");
        if string.find(sEffectLabel, "^Delayed:") then

            nCurrPoolDamage, nTotalPool = string.match(sEffectLabel, "Delayed: (%-?%d+)/(%d+)");
            nCurrPoolDamage = tonumber(nCurrPoolDamage);
            nTotalPool = tonumber(nTotalPool);
            rDelayedDamagePoolEffect = nodeEffect;
            break;
        end
    end
    if not rDelayedDamagePoolEffect then
        return;
    end

    if sRollType == "heal" then
        nHealthLost = nHealthLost * -1;
        if nHealthLost == nTotal or nCurrPoolDamage == 0 then
            return;
        end

        local nOverheal = nTotal - nHealthLost;
        local nDelayedDamageToHeal = math.min(nOverheal, tonumber(nCurrPoolDamage));
        local sNewEffectLabel = DB.getValue(rDelayedDamagePoolEffect, "label"):gsub("Delayed: %-?%d+", "Delayed: " .. (nCurrPoolDamage - nDelayedDamageToHeal));
        DB.setValue(rDelayedDamagePoolEffect, "label", "string", sNewEffectLabel);
    elseif sRollType:find("damage")  then
        if nCurrPoolDamage == nTotalPool then
            return;
        end

        local nodeTarget = ActorManager.getCreatureNode(rTarget);

        local nHealthInPool = tonumber(nTotalPool) - tonumber(nCurrPoolDamage);
        local nDamageToDelay = math.min(nHealthInPool, nHealthLost);

        local sNewEffectLabel = DB.getValue(rDelayedDamagePoolEffect, "label"):gsub("Delayed: %-?%d+", "Delayed: " .. (nCurrPoolDamage + nDamageToDelay));
        DB.setValue(rDelayedDamagePoolEffect, "label", "string", sNewEffectLabel);

        local nHealthToRestore = math.min(nHealthLost - nTempHealthLost, nDamageToDelay);
        DB.setValue(nodeTarget, "hp.wounds", "number", DB.getValue(nodeTarget, "hp.wounds", 0) - nHealthToRestore);

        nDamageToDelay = nDamageToDelay - nHealthToRestore;

        local nTempHealthToRestore = math.min(nTempHealthLost, nDamageToDelay);
        DB.setValue(nodeTarget, "hp.temporary", "number", DB.getValue(nodeTarget, "hp.temporary", 0) + nTempHealthToRestore);
    end
end

function newGetSpellAction(rActor, nodeAction, sSubRoll)
    local rAction = oldGetSpellAction(rActor, nodeAction, sSubRoll);

    if rAction.type ~= "cast" then
        return rAction;
    end

    local sBase = DB.getValue(nodeAction, "attackbabreplace", "");
    if sBase == "cl" then
        rAction.modifier = rAction.modifier - ActorManager35E.getAbilityScore(rActor, "bab") + DB.getValue(nodeAction, ".......cl", "");
    end

    local sStat = DB.getValue(nodeAction, "attackstatreplace", "");
    if sStat ~= "" and rAction.stat ~= sStat then
        rAction.modifier = rAction.modifier - ActorManager35E.getAbilityBonus(rActor, rAction.stat) + ActorManager35E.getAbilityBonus(rActor, sStat);
        rAction.stat = sStat;
    end

    return rAction;
end

function newGetHealRoll(rActor, rAction)
    local rRoll = oldGetHealRoll(rActor, rAction);
    if rAction.type == "heal" and rAction.subtype == "temp" and rAction.meta then
        if rAction.meta == "invigorate" then
            rRoll.sDesc = rRoll.sDesc .. " [INVIGORATE]";
        elseif rAction.meta == "painkiller" then
            rRoll.sDesc = rRoll.sDesc .. " [PAINKILLER]";
        elseif rAction.meta == "stacking" then
            rRoll.sDesc = rRoll.sDesc .. " [STACKING]";
        end
    end
    return rRoll;
end

local skillTargeting = {
    acrobatics = {desc = "Move Through Threatened Square", beatBy = true,
                  dcCalc = function(rSource, rTarget)
                      local nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance = ActorManager35E.getDefenseValue(rSource, rTarget, {sType = "grapple", sDesc = ""});
                      return nDefenseVal, nDefEffectsBonus
                  end},
    bluff = {desc = "Feint", beatBy = true,
             dcCalc = function(rSource, rTarget)
                 local nDefenseVal = 10 + ActorManager35E.getAbilityScore(rTarget, "bab") + ActorManager35E.getAbilityBonus(rTarget, "wisdom")
                 local nDefEffectsBonus = EffectManager35E.getEffectsBonus(rTarget, {"WIS"}, true, nil, rSource) - EffectManager35E.getEffectsBonus(rTarget, {"NLVL"}, true, nil, rSource);
                 return nDefenseVal, nDefEffectsBonus
             end},
    intimidate = {desc = "Demoralize", beatBy = true,
                  dcCalc = function(rSource, rTarget)
                      local nDefenseVal = 10 + ActorManager35E.getAbilityScore(rTarget, "lev") + ActorManager35E.getAbilityBonus(rTarget, "wisdom")
                      local nDefEffectsBonus = EffectManager35E.getEffectsBonus(rTarget, {"WIS"}, true, nil, rSource) - EffectManager35E.getEffectsBonus(rTarget, {"NLVL"}, true, nil, rSource);
                      return nDefenseVal, nDefEffectsBonus
                  end},
    escapeartist = {desc = "Escape Grapple", beatBy = false,
          dcCalc = function(rSource, rTarget)
              local nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance = ActorManager35E.getDefenseValue(rSource, rTarget, {sType = "grapple", sDesc = ""});
              return nDefenseVal, nDefEffectsBonus
          end},
    heal = {desc = "Medical Training", beatBy = false, icon = "roll_heal",
            dcCalc = function(rSource, rTarget)
                return 15, 0
            end}
}

function newGetSkillRoll(rActor, sSkillName, nSkillMod, sSkillStat, sExtra)
    local rRoll = oldGetSkillRoll(rActor, sSkillName, nSkillMod, sSkillStat, sExtra);
    rRoll.sSkillName = sSkillName;
    return rRoll;
end

function onSkillTargeting(rSource, aTargeting, rRolls)
    --Debug.chat('onskilltargeting', rSource, aTargeting, rRolls)
    if OptionsManager.isOption("TARGETEDSKILLS", "off") then
        return nil;
    end

    for _,rRoll in pairs(rRolls) do
        local sSkillName = rRoll.sDesc:match("%[SKILL%] ([^%[]+)"):lower():gsub("%s+", "")
        if skillTargeting[sSkillName] then    --if at least one skill has targeting info, then do target calcs
            return ActionAttack.onTargeting(rSource, aTargeting, rRolls);   --targeting logic is the same for skills as for attacks
        end
    end
    return nil;
end

function newModSkill(rSource, rTarget, rRoll)   --skill targeting would require an obnoxious number of overrides before it would work with targeted effects, so we just remove the targeting on the effects we want to use while calculating and put it back later
    --modSkill doesn't return anything at the time of writing, but return its value just in case it's added
    if not rTarget then
        return ActionSkill.modSkill(rSource, rTarget, rRoll)
    end

    local aSourceTargetedEffects = clearTargetedEffects(rSource, rTarget);
    local aTargetTargetedEffects = clearTargetedEffects(rTarget, rSource);

    local returnValue = ActionSkill.modSkill(rSource, rTarget, rRoll)

    restoreTargetedEffects(aSourceTargetedEffects)
    restoreTargetedEffects(aTargetTargetedEffects)

    return returnValue;
end


function clearTargetedEffects(rSource, rTarget)
    local aTargetedEffects = {};

    for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rSource), "effects")) do
        for _, nodeTarget in pairs(DB.getChildren(nodeEffect, "targets")) do
            if DB.getValue(nodeTarget, "noderef", "") == rTarget.sCTNode then
                aTargetedEffects[nodeEffect] = EffectManager.getEffectTargets(nodeEffect)
                DB.deleteChild(nodeEffect, "targets")
                break;
            end
        end
    end

    return aTargetedEffects;
end

function restoreTargetedEffects(aTargetedEffects)
    for effectNode, aEffectTargets in pairs(aTargetedEffects) do
        local nodeTargetList = DB.createChild(effectNode, "targets");
        for _,nodeTarget in pairs(aEffectTargets) do
            local nodeNewTarget = nodeTargetList.createChild();
            if nodeNewTarget then
                DB.setValue(nodeNewTarget, "noderef", "string", nodeTarget);
            end
        end
    end
end

function onSkillRoll(rSource, rTarget, rRoll)
    ActionSkill.onRoll(rSource, rTarget, rRoll)
    if not rTarget then
        return
    end

    local sSkillName = rRoll.sDesc:match("%[SKILL%] ([^%[]+)"):lower():gsub("%s+", "")
    local nDefenseVal, nDefEffectsBonus = skillTargeting[sSkillName].dcCalc(rSource, rTarget)
    local nTotal = ActionsManager.total(rRoll);

    local sResults = getOpposedSkillResult(nTotal, nDefenseVal + (nDefEffectsBonus or 0), nDefEffectsBonus or 0, skillTargeting[sSkillName].beatBy)

    notifyOpposedSkill(rSource, rTarget, rRoll.bTower, sSkillName, rRoll.sDesc, nTotal, sResults)
end

function getOpposedSkillResult(nTotal, nTargetDC, nDefEffectsBonus, beatBy)
    local aMessages = {};

    if nDefEffectsBonus ~= 0 then
        local sFormat = "[" .. Interface.getString("effects_def_tag") .. " %+d]";
        table.insert(aMessages, string.format(sFormat, nDefEffectsBonus));
    end

    if nTotal >= nTargetDC then
        table.insert(aMessages, "[SUCCESS]");
        if beatBy then
            table.insert(aMessages, "BEAT BY " .. math.max(0, math.floor((nTotal - nTargetDC) / 5) * 5) .. "+");
        end
    else
        table.insert(aMessages, "[FAILURE]");
    end

    return table.concat(aMessages, " ");
end

function notifyOpposedSkill(rSource, rTarget, bSecret, sSkillName, sDesc, nTotal, sResults)
    if not rTarget then
        return;
    end

    local msgOOB = {};
    msgOOB.type = OOB_MSGTYPE_OPPOSEDSKILL;

    if bSecret then
        msgOOB.nSecret = 1;
    else
        msgOOB.nSecret = 0;
    end
    msgOOB.sSkillName = sSkillName;
    msgOOB.nTotal = nTotal;
    msgOOB.sDesc = sDesc;
    msgOOB.sResults = sResults;

    msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
    msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);

    Comm.deliverOOBMessage(msgOOB, "");
end

function handleOpposedSkill(msgOOB)
    local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
    local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
    local nTotal = tonumber(msgOOB.nTotal) or 0;
    applyOpposedSkill(rSource, rTarget, (tonumber(msgOOB.nSecret) == 1), msgOOB.sSkillName, msgOOB.sDesc, nTotal, msgOOB.sResults);
end

function applyOpposedSkill(rSource, rTarget, bSecret, sSkillName, sDesc, nTotal, sResults)
    if not rTarget then
        return;
    end

    local msgShort = {font = "msgfont"};
    local msgLong = {font = "msgfont"};

    local sSkillDesc = skillTargeting[sSkillName].desc;
    msgShort.text = sSkillDesc .. " ->";
    msgLong.text = sSkillDesc .. " [" .. nTotal .. "] ->";

    if sSkillName == "heal" and not useMedicalTraining(rSource, rTarget, nTotal) then   --if source can't use medical training, then no need to describe success/failure
        return;
    end

    local sTargetName = ActorManager.getDisplayName(rTarget);
    msgShort.text = msgShort.text .. " [at " .. sTargetName .. "]";
    msgLong.text = msgLong.text .. " [at " .. sTargetName .. "]";

    if sResults ~= "" then
        msgLong.text = msgLong.text .. " " .. sResults;
    end

    msgShort.icon = "roll_attack";
    if string.match(sResults, "SUCCESS%]") then
        msgLong.icon = "roll_attack_hit";
    elseif string.match(sResults, "FAILURE%]") then
        msgLong.icon = "roll_attack_miss";
    else
        msgLong.icon = "roll_attack";
    end

    ActionsManager.outputResult(bSecret, rSource, rTarget, msgLong, msgShort);
end

function useMedicalTraining(rSource, rTarget, nTotal)
    local sNodeType, nodeActor = ActorManager.getTypeAndNode(rSource);
    if sNodeType ~= "pc" then
        return false;
    end

    local nHealAmount = nTotal - 14;

    local scholarLevel = 0;
    for _,class in pairs(nodeActor.getChild("classes").getChildren()) do
        if class.getChild("name").getValue():lower():find("scholar", 1, 1) then --fixme better way to identify valid users if/when it comes up in another campaign
            scholarLevel = class.getChild("level").getValue();
            break;
        end
    end
    if scholarLevel == 0 then
        return false;
    elseif scholarLevel >= 9 then
        nHealAmount = nHealAmount * 3;
    elseif scholarLevel >= 5 then
        nHealAmount = nHealAmount * 2;
    end

    local nTimesUsed = 0;
    for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rTarget), "effects")) do
        if DB.getValue(nodeEffect, "source_name", nil) == rSource.sCTNode then
            nTimesUsed = tonumber(string.match(DB.getValue(nodeEffect, "label", ""), "(%d+) Healer's Kit Use")) or 0;
            if nTimesUsed > 0 then
                break;
            end
        end
    end
    if nTimesUsed >= math.max(DB.getValue(nodeActor, "abilities.intelligence.bonusmodifier", 0), 1) then
        ChatManager.Message("Healer's Kit Use [TARGET HAS BEEN HEALED TOO MANY TIMES.]", true, rSource);
        return false;
    end

    EffectManager.notifyApply({ sName = "STACK: Healer's Kit Use", sSource = rSource.sCTNode or "" , nDuration = 14400}, ActorManager.getCTNodeName(rTarget));
    if nHealAmount > 0 then
        newApplyDamage(rSource, rTarget, false, "heal", "[HEAL] Healer's Kit Use", nHealAmount)
    end
    return true;
end

function customOnEffectAddIgnoreCheckTargetInit(nodeCT, rNewEffect)
    if string.find(rNewEffect.sName, "^TINIT;") then
        --set initiative to target's instead of current and remove label
        rNewEffect.nInit = DB.getValue(nodeCT, "initresult");
        rNewEffect.sName = StringManager.trim(rNewEffect.sName:gsub("TINIT;", ""));
    end

    --based on copypasted default dupe check
    local nodeEffectsList = nodeCT.createChild("effects");
    for _, v in pairs(nodeEffectsList.getChildren()) do
        if (DB.getValue(v, "label", "") == rNewEffect.sName)
                and (DB.getValue(v, "init", 0) == rNewEffect.nInit)
                and DB.getValue(v, "targets.id-00001.noderef", nil) == rNewEffect.sTarget   --added effect target to dupe check
                --and (DB.getValue(v, "duration", 0) == rNewEffect.nDuration)   -- still a dupe even if the duration is different
            then
            local nOriginalEffectDuration = DB.getValue(v, "duration", 0);   --removed duration needing to be identical to count as dupe, now updates old effect to refreshed duration
            if nOriginalEffectDuration > 0 and (nOriginalEffectDuration < rNewEffect.nDuration or rNewEffect.nDuration == 0) then
                DB.setValue(v, "duration", "number", rNewEffect.nDuration);
                return "Effect ['" .. rNewEffect.sName .. "'] -> [EXTENDING DURATION]"
            end
            return "Effect ['" .. rNewEffect.sName .. "'] -> [ALREADY EXISTS]"
        end
    end

    --compatibility
    if oldCustomOnEffectAddIgnoreCheck then
        return oldCustomOnEffectAddIgnoreCheck(nodeCT, rNewEffect);
    end
    return nil;
end

local aVitalityLossState = {};

function applySaveStalwartAndVitality(rSource, rOrigin, rAction, sUser)
    local msgShort = { font = "msgfont" };
    local msgLong = { font = "msgfont" };

    msgShort.text = "Save";
    msgLong.text = "Save [" .. rAction.nTotal .. "]";
    if rAction.nTarget then
        msgLong.text = msgLong.text .. "[vs. DC " .. rAction.nTarget .. "]";
    end
    msgShort.text = msgShort.text .. " ->";
    msgLong.text = msgLong.text .. " ->";
    if rSource then
        msgShort.text = msgShort.text .. " [for " .. ActorManager.getDisplayName(rSource) .. "]";
        msgLong.text = msgLong.text .. " [for " .. ActorManager.getDisplayName(rSource) .. "]";
    end
    if rOrigin then
        msgShort.text = msgShort.text .. " [vs " .. ActorManager.getDisplayName(rOrigin) .. "]";
        msgLong.text = msgLong.text .. " [vs " .. ActorManager.getDisplayName(rOrigin) .. "]";
    end

    msgShort.icon = "roll_cast";

    local sAttack = "";
    local bHalfMatch = false;
    if rAction.sSaveDesc then
        sAttack = rAction.sSaveDesc:match("%[SAVE VS[^]]*%] ([^[]+)") or "";
        bHalfMatch = (rAction.sSaveDesc:match("%[HALF ON SAVE%]") ~= nil);
    end
    rAction.sResult = "";

    if rAction.sSaveResult == "autosuccess" or rAction.sSaveResult == "success" then
        if rAction.sSaveResult == "autosuccess" then
            msgLong.text = msgLong.text .. " [AUTOMATIC SUCCESS]";
        else
            msgLong.text = msgLong.text .. " [SUCCESS]";
        end

        if rSource then
            local bHalfDamage = bHalfMatch;
            local bAvoidDamage = false;
            if bHalfDamage then
                local sSave = rAction.sDesc:match("%[SAVE%] (%w+)");
                if sSave then
                    sSave = sSave:lower();
                end
                if sSave == "reflex" then
                    if EffectManager35E.hasEffectCondition(rSource, "Improved Evasion") then
                        bAvoidDamage = true;
                        msgLong.text = msgLong.text .. " [IMPROVED EVASION]";
                    elseif EffectManager35E.hasEffectCondition(rSource, "Evasion") then
                        bAvoidDamage = true;
                        msgLong.text = msgLong.text .. " [EVASION]";
                    end
                elseif sSave == "fortitude" or sSave == "will" then
                    if EffectManager35E.hasEffectCondition(rSource, "Stalwart") then
                        bAvoidDamage = true;
                        msgLong.text = msgLong.text .. " [STALWART]";
                    end
                end
            end

            if bAvoidDamage then
                rAction.sResult = "none";
                rAction.bRemoveOnMiss = false;
            elseif bHalfDamage then
                rAction.sResult = "half_success";
                rAction.bRemoveOnMiss = false;
            end

            if rOrigin and rAction.bRemoveOnMiss then
                TargetingManager.removeTarget(ActorManager.getCTNodeName(rOrigin), ActorManager.getCTNodeName(rSource));
            end
        end
    else
        if rAction.sSaveResult == "autofailure" then
            msgLong.text = msgLong.text .. " [AUTOMATIC FAILURE]";
        else
            msgLong.text = msgLong.text .. " [FAILURE]";
        end

        if rSource then
            local bHalfDamage = false;
            if bHalfMatch then
                local sSave = rAction.sDesc:match("%[SAVE%] (%w+)");
                if sSave then
                    sSave = sSave:lower();
                end
                if sSave == "reflex" then
                    if EffectManager35E.hasEffectCondition(rSource, "Improved Evasion") then
                        bHalfDamage = true;
                        msgLong.text = msgLong.text .. " [IMPROVED EVASION]";
                    end
                end
            end

            if bHalfDamage then
                rAction.sResult = "half_failure";
            end
        end
    end

    ActionsManager.outputResult(rAction.bSecret, rSource, rOrigin, msgLong, msgShort);

    if rSource and rOrigin then
        ActionDamage.setDamageState(rOrigin, rSource, StringManager.trim(sAttack), rAction.sResult);

        local bSaveFailed = rAction.sSaveResult == "autofailure" or rAction.sSaveResult == "failure";
        setVitalityLossState(rSource, bSaveFailed);
    end
end

function newApplyAttack(rSource, rTarget, bSecret, sAttackType, sDesc, nTotal, sResults)
    if sResults:find("HIT", 1, 1) and not sResults:find("MISS CHANCE", 1, 1)
        and not (MirrorImageHandler and MirrorImageHandler.getMirrorImageCount(rTarget) > 0) then
        applyOnHitEffects(rSource, rTarget);
    end

    oldApplyAttack(rSource, rTarget, bSecret, sAttackType, sDesc, nTotal, sResults);
end

function newOnMissChance(rSource, rTarget, rRoll)
    local rMessage = ActionsManager.createActionMessage(rSource, rRoll);

    local nTotal = ActionsManager.total(rRoll);
    local nMissChance = tonumber(string.match(rMessage.text, "%[MISS CHANCE (%d+)%%%]")) or 0;
    if nTotal <= nMissChance then
        rMessage.text = rMessage.text .. " [MISS]";
        if rTarget then
            rMessage.icon = "roll_attack_miss";
            ActionAttack.clearCritState(rSource, rTarget);
        else
            rMessage.icon = "roll_attack";
        end
    else
        local nMirrorImageCount = 0;
        if MirrorImageHandler then
            nMirrorImageCount = MirrorImageHandler.getMirrorImageCount(rTarget);
        end
        if nMirrorImageCount > 0 then
            local rMirrorImageRoll = MirrorImageHandler.getMirrorImageRoll(nMirrorImageCount, rRoll.sDesc);
            ActionsManager.roll(rSource, rTarget, rMirrorImageRoll);
        else
            applyOnHitEffects(rSource, rTarget);
        end

        rMessage.text = rMessage.text .. " [HIT]";
        if rTarget then
            rMessage.icon = "roll_attack_hit";
        else
            rMessage.icon = "roll_attack";
        end
    end

    Comm.deliverChatMessage(rMessage);
end

function applyOnHitEffects(rSource, rTarget)
    setVitalityLossState(rTarget, true);
    applyResolveMandate(rSource, rTarget);
end

function clearCritAndVitalityLossState(rSource, rTarget)
    setVitalityLossState(rTarget, false);
    oldClearCritState(rSource, rTarget);
end

function getConcentrationEffects(rTarget)
    local aConcentrationEffects = {};

    for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rTarget), "effects")) do
        if string.find(DB.getValue(nodeEffect, "label", ""):lower(), "concentration:", 1, true) then
            table.insert(aConcentrationEffects, nodeEffect);
        end
    end

    return aConcentrationEffects;
end

function removeVitalityEffects(rTarget)
    for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rTarget), "effects")) do
        if string.find(DB.getValue(nodeEffect, "label", ""):lower(), "^vitality;") then
            EffectManager.expireEffect(rTarget, nodeEffect, 0);
        end
    end
end

function wasHitByAttackOrFailedSave(rVitalActor)
    local sVitalCT = ActorManager.getCreatureNodeName(rVitalActor);
    if sVitalCT == "" then
        return ;
    end
    return aVitalityLossState[sVitalCT];
end

function setVitalityLossState(rVitalActor, bVitalityLossState)
    local sVitalCT = ActorManager.getCreatureNodeName(rVitalActor);
    if sVitalCT == "" then
        return ;
    end
    aVitalityLossState[sVitalCT] = bVitalityLossState;
end

function applyResolveMandate(rSource, rTarget)
    for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rSource), "effects")) do
        if string.find(DB.getValue(nodeEffect, "label", ""), "Resolve: ", 1, true) then
            local sMandatePartnerName = string.gsub(DB.getValue(nodeEffect, "label", ""), "Resolve: ", "");
            for _,nodeCT in pairs(CombatManager.getCombatantNodes()) do
                if (DB.getValue(nodeCT, "name", "") == sMandatePartnerName) then
                    local rResolveEffect = { sName = "TINIT; AC: 4 morale; SAVE: 4 morale", nDuration = 1.5, sTarget = rTarget.sCTNode};
                    EffectManager.addEffect(nodeEffect.getOwner(), "", nodeCT, rResolveEffect, true);
                    break;
                end
            end
        end
    end
end

local nConcentrationDC;
local nConcentrationEffect;
function forceConcentrationCheck(rActor, rConcentrationEffect, nMiscModifier)
    for _, sEffectComp in ipairs(EffectManager.parseEffect(DB.getValue(rConcentrationEffect, "label", ""))) do
        local rEffectComp = EffectManager35E.parseEffectComp(sEffectComp);
        for _, rCreatureSpellset in pairs(DB.getChildren(ActorManager.getCreatureNode(rActor), "spellset")) do
            if (rEffectComp.remainder[1] == DB.getValue(rCreatureSpellset, "label", "")) then
                nConcentrationDC = 10 + rEffectComp.mod + nMiscModifier;
                nConcentrationEffect = rConcentrationEffect;
                GameSystem.performConcentrationCheck(nil, rActor, rCreatureSpellset);
            end
        end
    end
end

function newPerformAction(draginfo, rActor, rRoll)
    if rRoll.sType == "concentration" and nConcentrationDC then
        rRoll.nTarget = nConcentrationDC;
        nConcentrationDC = nil;
    end

    oldPerformAction(draginfo, rActor, rRoll)
end

function handleConcentrationCheck(rSource, rTarget, rRoll)
    local rMessage = ActionsManager.createActionMessage(rSource, rRoll);

    if rRoll.nTarget then
        local nTotal = ActionsManager.total(rRoll);
        local nTargetDC = tonumber(rRoll.nTarget) or 0;

        rMessage.text = rMessage.text .. " (vs. DC " .. nTargetDC .. ")";
        if nTotal >= nTargetDC then
            rMessage.text = rMessage.text .. " [SUCCESS]";
        else
            rMessage.text = rMessage.text .. " [FAILURE]";
            EffectManager.expireEffect(rSource, nConcentrationEffect, 0);
        end
        nConcentrationEffect = nil;
    end

    Comm.deliverChatMessage(rMessage);
end

local oldDraginfo = { };

function onHotkey(draginfo)
    if #oldDraginfo > 0 then
        oldDraginfo = { };
    end
end

function onHotkeyDrop(draginfo)
    if OptionsManager.getOption("COMBOHOTKEYS"):lower() ~= "on" then
        return ;
    end

    table.insert(oldDraginfo, { draginfo.getSlotType(), draginfo.getNumberData(), draginfo.getStringData() });

    for i = 1, #oldDraginfo do
        draginfo.setSlot(i);

        draginfo.setSlotType(oldDraginfo[i][1]);
        draginfo.setNumberData(oldDraginfo[i][2]);
        draginfo.setStringData(oldDraginfo[i][3]);
    end
end

function getMissChanceDefenseValue(rAttacker, rDefender, rRoll)
    local nDefense, nAttackEffectMod, nDefenseEffectMod, nMissChance = oldGetDefenseValue(rAttacker, rDefender, rRoll);

    local aAttackFilter = {};
    if sAttackType == "M" then
        table.insert(aAttackFilter, "melee");
    elseif sAttackType == "R" then
        table.insert(aAttackFilter, "ranged");
    end
    if bOpportunity then
        table.insert(aAttackFilter, "opportunity");
    end

    local aMissEffects = EffectManager35E.getEffectsBonusByType(rDefender, {"MISS"}, true, aAttackFilter, rAttacker);

    for _,v in pairs(aMissEffects) do
        if nMissChance == 20 then       -- stacks with fog CONC
            nMissChance = math.max(v.mod, nMissChance) + (math.min(v.mod, nMissChance) / 2);
        else
            nMissChance = math.max(v.mod, nMissChance);
        end
    end

    if nMissChance > 95 then
        nMissChance = 95;
    end

    return nDefense, nAttackEffectMod, nDefenseEffectMod, nMissChance;
end

function newOnMirrorImage(rSource, rTarget, rRoll)
    if rRoll.aDice[1].result > MirrorImageHandler.getMirrorImageHitPercent(tonumber(rRoll.sDesc:match("(%d+) MIRROR IMAGES"))) then
        applyOnHitEffects(rSource, rTarget);
    end

    oldOnMirrorImage(rSource, rTarget, rRoll);
end

function newNotifyExpire(varEffect, nMatch, bImmediate)
    if type(varEffect) == "databasenode" then
        if DB.getValue(varEffect, "label", ""):lower():find("^turn;") then
            DB.setValue(varEffect, "isactive", "number", 0);
            return;
        end

        varEffect = varEffect.getPath();
    elseif type(varEffect) ~= "string" then
        return;
    end

    oldNotifyExpire(varEffect, nMatch, bImmediate);
end

function newProcessEffect(nodeActor, nodeEffect, nCurrentInit, nNewInit, bProcessSpecialStart, bProcessSpecialEnd)
    if bProcessSpecialStart and DB.getValue(nodeEffect, "label", ""):lower():find("^turn;") then
        DB.setValue(nodeEffect, "isactive", "number", 1);
    end

    oldProcessEffect(nodeActor, nodeEffect, nCurrentInit, nNewInit, bProcessSpecialStart, bProcessSpecialEnd);
end


local tokenHovered = false;

function newOnImageInit(cImage)
    oldOnImageInit(cImage)

    if OptionsManager.getOption("CLICKMAPREMOVESTARGETS"):lower() == "off" then
        Token.onHover = nil;
        cImage.onHoverUpdate = nil;
        return;
    end

    Token.onHover = function(tokenMap, bOver)
        tokenHovered = bOver;
    end

    -- an imagecontrol is unable to receive real mouse click events, a hoverUpdate event with zero movement is assumed to have been a click instead
    cImage.onHoverUpdate = function(x, y)
        if cImage.getCursorMode() == nil then   -- only need to look for these events in "normal" cursor mode (e.g. not drawing/mask modes)
            if x == cImage.lastX and y == cImage.lastY and not Input.isControlPressed() and not Input.isShiftPressed() and not Input.isAltPressed() and not tokenHovered then
                cImage.clearSelectedTokens();
            else
                cImage.lastX = x;
                cImage.lastY = y;
            end
        end
    end
end