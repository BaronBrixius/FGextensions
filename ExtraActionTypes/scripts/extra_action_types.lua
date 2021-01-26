-- TODO FHEAL temp health
-- TODO mirror image give to Aaron

local oldOnSpellAction;
local oldGetActionAttackText;
local oldApplyDamage;
local oldOnEffectActorStartTurn;
local oldOnEffectEndTurn;
local oldCustomOnEffectAddIgnoreCheck;
local oldApplyAttack;
local oldClearCritState;
local oldAddItemToList;
local oldPerformAction;

function onInit()
    -- Demoralize
    ActionsManager.registerTargetingHandler("demoralize", onSkillTargeting);
    ActionsManager.registerModHandler("demoralize", ActionSkill.modSkill);
    ActionsManager.registerResultHandler("demoralize", onDemoralizeRoll);

    GameSystem.actions["demoralize"] = { sTargeting = "all", bUseModStack = true };
    table.insert(GameSystem.targetactions, "demoralize");

    oldOnSpellAction = SpellManager.onSpellAction;
    SpellManager.onSpellAction = newOnSpellActionDemoralize;

    oldGetActionAttackText = SpellManager.getActionAttackText;
    SpellManager.getActionAttackText = getActionDemoralizeText;

    -- Effect Expires At End Of Turn
    oldOnEffectEndTurn = EffectManager.fCustomOnEffectEndTurn
    EffectManager.setCustomOnEffectEndTurn(newOnEffectEndTurn)

    -- Use Target Initiative For Effect
    oldCustomOnEffectAddIgnoreCheck = EffectManager.fCustomOnEffectAddIgnoreCheck;
    EffectManager.setCustomOnEffectAddIgnoreCheck(useTargetsInitIfLabelled);

    -- Vitality
    ActionSave.applySave = applySaveStalwartAndVitality;    --also Stalwart

    oldApplyAttack = ActionAttack.applyAttack;
    ActionAttack.applyAttack = applyAttackAndSetVitalityLossState;

    oldClearCritState = ActionAttack.clearCritState;
    ActionAttack.clearCritState = clearCritAndVitalityLossState;

    -- Auto Identify
    oldAddItemToList = ItemManager.addItemToList;
    ItemManager.addItemToList = newAddItemToList;
    OptionsManager.registerOption2("AUTOIDENTIFY", false, "option_header_game", "option_label_AUTOIDENTIFY", "option_entry_cycler", { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });

    -- Temp HP Changes & Auto Concentration
    oldApplyDamage = ActionDamage.applyDamage;
    ActionDamage.applyDamage = newApplyDamage;

    -- Auto Concentration
    oldPerformAction = ActionsManager.performAction;
    ActionsManager.performAction = newPerformAction;
    ActionsManager.registerResultHandler("concentration", handleConcentrationCheck);

    oldOnEffectActorStartTurn = EffectManager.fCustomOnEffectActorStartTurn;
    EffectManager.setCustomOnEffectActorStartTurn(checkConcentrationEffectOnActorStartTurn);

    -- Combo Hotkeys
    OptionsManager.registerOption2("COMBOHOTKEYS", true, "option_header_client", "option_label_COMBOHOTKEYS", "option_entry_cycler", { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
    Interface.onHotkeyDrop = onHotkeyDrop;
    Interface.onHotkeyActivated = onHotkey;
end

function newAddItemToList(vList, sClass, vSource, bTransferAll, nTransferCount)
    local nodeNew = oldAddItemToList(vList, sClass, vSource, bTransferAll, nTransferCount);

    if User.isHost() and OptionsManager.getOption("AUTOIDENTIFY"):lower() == "on" and type(vList) == "string" and ItemManager.getItemSourceType(DB.createNode(vList)) == "partysheet" then
        DB.setValue(nodeNew, "isidentified", "number", 1);
    end

    return nodeNew;
end

function checkConcentrationEffectOnActorStartTurn(nodeActor, nodeEffect)
    if oldOnEffectActorStartTurn then
        if oldOnEffectActorStartTurn(nodeActor, nodeEffect, nCurrentInit, nNewInit) then
            return true;
        end
    end

    if not string.find(DB.getValue(nodeEffect, "label", ""):lower(), "concentration:", 1, true) then
        return false;
    end

    for _, v in pairs(nodeActor.createChild("effects").getChildren()) do
        local sLabel = DB.getValue(v, "label", "");
        if string.find(sLabel, "Entangled") then
            forceConcentrationCheck(nodeActor, nodeEffect, 5)
        end
    end
end

function newOnEffectEndTurn(nodeActor, nodeEffect, nCurrentInit, nNewInit)
    if oldOnEffectEndTurn then
        if oldOnEffectEndTurn(nodeActor, nodeEffect, nCurrentInit, nNewInit) then
            return true;
        end
    end

    --If an effect's duration is less than 1, expire it (e.g. set duration as 1.5 for it to last 1 round but expire at end of turn)
    local nDuration = DB.getValue(nodeEffect, "duration");
    if nDuration > 0 and nDuration < 1 then
        EffectManager.expireEffect(nodeActor, nodeEffect);
        return true;
    end

    return false;
end

function newApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)
    local nHealthBeforeAttack = getTotalHP(rTarget);

    local nNewTotal = applyTempHPChanges(nTotal, rTarget, sDamage);
    oldApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nNewTotal);

    local nHealthLost = nHealthBeforeAttack - getTotalHP(rTarget);
    if nHealthLost > 0 then
        if string.find(sDamage, "Ongoing", 1, true) then
            nHealthLost = math.max(1, math.floor(nHealthLost / 2))
        elseif wasHitByAttackOrFailedSave(rTarget) then
            setVitalityLossState(rTarget, false);
            removeVitalityEffects(rTarget);
        end

        for _, rEffect in ipairs(getConcentrationEffects(rTarget)) do
            forceConcentrationCheck(rTarget, rEffect, nHealthLost)
        end
    end
end

function getTotalHP(rActor)
    local nodeTarget = ActorManager.getCreatureNode(rActor);
    return DB.getValue(nodeTarget, "hp.total", 0) - DB.getValue(nodeTarget, "hp.wounds", 0) + DB.getValue(nodeTarget, "hp.temporary", 0);
end

function applyTempHPChanges(nTotal, rTarget, sDamage)
    if not string.match(sDamage, "%[TEMP%]") then
        --string.match(sDamage, "%[HEAL") and
        return nTotal;
    end

    local nNewTotal = nTotal;
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

    --Invigorate cannot raise a target's total (temp + current) hit points above their max hit points
    if string.match(sDamage, "%[INVIGORATE%]") then
        nNewTotal = math.min(nNewTotal, nWounds);
    end

    if not string.match(sDamage, "%[STACKING%]") then
        nNewTotal = math.max(nNewTotal - nTempHP, 0);
    end
    return nNewTotal;
end

function newGetSpellActionDemoralize(rActor, nodeAction, sSubRoll)
    local rAction = SpellManager.getSpellAction(rActor, nodeAction, sSubRoll);  --old version of the function

    if rAction.type == "cast" and DB.getValue(nodeAction, "atktype", "") == "demoralize" then
        rAction.demo = true;
        rAction.range = nil;
    end

    return rAction;
end

function getHealRollTempHPEffects(rActor, rAction)
    local rRoll = ActionHeal.getRoll(rActor, rAction);
    if rAction.type == "heal" and rAction.subtype == "temp" and rAction.meta then
        if rAction.meta == "invigorate" then
            rRoll.sDesc = rRoll.sDesc .. " [INVIGORATE]";
        elseif rAction.meta == "stacking" then
            rRoll.sDesc = rRoll.sDesc .. " [STACKING]";
        end
    end
    return rRoll;
end

function newOnSpellActionDemoralize(draginfo, nodeAction, sSubRoll)
    if not nodeAction then
        return ;
    end
    local rActor = ActorManager.getActor("", nodeAction.getChild("........."));
    if not rActor then
        return ;
    end

    local rAction = newGetSpellActionDemoralize(rActor, nodeAction, sSubRoll);

    local rRolls = {};
    if rAction.type == "cast" then
        if not rAction.subtype then
            table.insert(rRolls, ActionSpell.getSpellCastRoll(rActor, rAction));
        end

        if not rAction.subtype or rAction.subtype == "atk" then
            if rAction.range then
                table.insert(rRolls, ActionAttack.getRoll(rActor, rAction));
            elseif rAction.demo then
                local rRoll = ActionSkill.getRoll(rActor, "Demoralize", CharManager.getSkillValue(rActor, "Intimidate"));
                rRoll.sType = "demoralize";
                table.insert(rRolls, rRoll);
            end
        end

        if not rAction.subtype or rAction.subtype == "clc" then
            local rRoll = ActionSpell.getCLCRoll(rActor, rAction);
            if not rAction.subtype then
                rRoll.sType = "castclc";
                rRoll.aDice = {};
            end
            table.insert(rRolls, rRoll);
        end

        if not rAction.subtype or rAction.subtype == "save" then
            if rAction.save and rAction.save ~= "" then
                local rRoll = ActionSpell.getSaveVsRoll(rActor, rAction);
                if not rAction.subtype then
                    rRoll.sType = "castsave";
                end
                table.insert(rRolls, rRoll);
            end
        end

    elseif rAction.type == "damage" then
        local rRoll = ActionDamage.getRoll(rActor, rAction);
        if rAction.bSpellDamage then
            rRoll.sType = "spdamage";
        else
            rRoll.sType = "damage";
        end

        table.insert(rRolls, rRoll);

    elseif rAction.type == "heal" then
        table.insert(rRolls, getHealRollTempHPEffects(rActor, rAction));

    elseif rAction.type == "effect" then
        local rRoll;
        rRoll = ActionEffect.getRoll(draginfo, rActor, rAction);
        if rRoll then
            table.insert(rRolls, rRoll);
        end
    end

    if #rRolls > 0 then
        ActionsManager.performMultiAction(draginfo, rActor, rRolls[1].sType, rRolls);
    end
end

function onDemoralizeRoll(rSource, rTarget, rRoll)
    local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
    rMessage.text = string.gsub(rMessage.text, " %[MOD:[^]]*%]", "");

    local nTotal = ActionsManager.total(rRoll);

    if rRoll.nTarget then
        local nTargetDC = tonumber(rRoll.nTarget) or 0;

        rMessage.text = rMessage.text .. " (vs. DC " .. nTargetDC .. ")";
        if nTotal >= nTargetDC then
            rMessage.text = rMessage.text .. " [SUCCESS]";
        else
            rMessage.text = rMessage.text .. " [FAILURE]";
        end
    elseif rTarget then
        local nTargetDC = 10 + ActorManager2.getAbilityScore(rTarget, "lev") + ActorManager2.getAbilityBonus(rTarget, "wisdom");

        rMessage.text = rMessage.text .. " [at " .. ActorManager.getDisplayName(rTarget) .. "]";
        if nTotal >= nTargetDC then
            rMessage.text = rMessage.text .. " [SUCCESS] BEAT BY " .. math.floor((nTotal - nTargetDC) / 5) * 5 .. "+";
        else
            rMessage.text = rMessage.text .. " [FAILURE]";
        end
    end
    Comm.deliverChatMessage(rMessage);
end

function getActionDemoralizeText(nodeAction)
    if DB.getValue(nodeAction, "atktype", "") == "demoralize" then
        return Interface.getString("power_label_demoralize");
    else
        return oldGetActionAttackText(nodeAction);
    end
end

function onSkillTargeting(rSource, aTargeting, rRolls)
    local bRemoveOnMiss = false;
    local sOptRMMT = OptionsManager.getOption("RMMT");
    if sOptRMMT == "on" then
        bRemoveOnMiss = true;
    elseif sOptRMMT == "multi" then
        local aTargets = {};
        for _, vTargetGroup in ipairs(aTargeting) do
            for _, vTarget in ipairs(vTargetGroup) do
                table.insert(aTargets, vTarget);
            end
        end
        bRemoveOnMiss = (#aTargets > 1);
    end

    if bRemoveOnMiss then
        for _, vRoll in ipairs(rRolls) do
            vRoll.bRemoveOnMiss = "true";
        end
    end

    return aTargeting;
end

function useTargetsInitIfLabelled(nodeCT, rNewEffect)
    if string.find(rNewEffect.sName, "TINIT;") then
        --set initiative to target's instead of current and remove label
        rNewEffect.nInit = DB.getValue(nodeCT, "initresult");
        rNewEffect.sName = StringManager.trim(rNewEffect.sName:gsub("TINIT;", ""));
    end

    --copypasted default dupe check
    local nodeEffectsList = nodeCT.createChild("effects");
    for _, v in pairs(nodeEffectsList.getChildren()) do
        if (DB.getValue(v, "label", "") == rNewEffect.sName) and
                (DB.getValue(v, "init", 0) == rNewEffect.nInit) and
                (DB.getValue(v, "duration", 0) == rNewEffect.nDuration) then
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

function applyAttackAndSetVitalityLossState(rSource, rTarget, bSecret, sAttackType, sDesc, nTotal, sResults)
    if sResults:find("HIT", 1, 1) then
        setVitalityLossState(rTarget, true);
    end

    oldApplyAttack(rSource, rTarget, bSecret, sAttackType, sDesc, nTotal, sResults);
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
        if string.find(DB.getValue(nodeEffect, "label", ""):lower(), "vitality;", 1, true) then
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