
-- TODO FHEAL temp health
-- TODO move Beat By text here
-- TODO aura mod throws fits on removal

local oldOnSpellAction;
local oldGetActionAttackText;
local oldApplyDamage;
local oldEndTurn;
local oldCustomOnEffectAddIgnoreCheck;
local oldMessageDamage;
local oldApplyAttack;
local oldClearCritState;
local oldAddItemToList;

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

    -- Temp HP Changes
    oldApplyDamage = ActionDamage.applyDamage;
    ActionDamage.applyDamage = tempHPOverrides;

    -- Effect Expires At End Of Turn
    oldEndTurn = EffectManager.fCustomOnEffectEndTurn
    EffectManager.setCustomOnEffectEndTurn(newEndTurn)

    -- Use Target Initiative For Effect
    oldCustomOnEffectAddIgnoreCheck = EffectManager.fCustomOnEffectAddIgnoreCheck;
    EffectManager.setCustomOnEffectAddIgnoreCheck(useTargetsInitIfLabelled);

    -- Vitality
    ActionSave.applySave = applySaveStalwartAndVitality;    --also Stalwart

    oldMessageDamage = ActionDamage.messageDamage;
    ActionDamage.messageDamage = messageDamageAndClearVitalityLossState;

    oldApplyAttack = ActionAttack.applyAttack;
    ActionAttack.applyAttack = applyAttackAndSetVitalityLossState;

    oldClearCritState = ActionAttack.clearCritState;
    ActionAttack.clearCritState = clearCritAndVitalityLossState;

    -- Auto Identify
    oldAddItemToList = ItemManager.addItemToList;
    ItemManager.addItemToList = newAddItemToList;

    OptionsManager.registerOption2("AUTOIDENTIFY", false, "option_header_game", "option_label_AUTOIDENTIFY", "option_entry_cycler", { labels = "option_val_on", values="on", baselabel = "option_val_off", baseval="off", default="off"});
end

function newAddItemToList(vList, sClass, vSource, bTransferAll, nTransferCount)
    local nodeNew = oldAddItemToList(vList, sClass, vSource, bTransferAll, nTransferCount);

    if not User.isHost() then
        return nodeNew;
    end

    if OptionsManager.getOption("AUTOIDENTIFY"):lower() ~= "on" then
        return nodeNew;
    end

    local nodeList;
    if type(vList) == "string" then
        nodeList = DB.createNode(vList);
    end

    if nodeList and ItemManager.getItemSourceType(nodeList) == "partysheet" then
        DB.setValue(nodeNew, "isidentified", "number", 1);
    end

    return nodeNew;
end

function newEndTurn(nodeActor, nodeEffect, nCurrentInit, nNewInit)
    if oldEndTurn then
        oldEndTurn(nodeActor, nodeEffect, nCurrentInit, nNewInit);
    end

    --If an effect's duration is less than 1, expire it (e.g. set duration as 1.5 to last 1 round but expire at end of turn)
    local nDuration = DB.getValue(nodeEffect, "duration");
    if nDuration > 0 and nDuration < 1 then
        EffectManager.expireEffect(nodeActor, nodeEffect);
        return true;
    end
end

function tempHPOverrides(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)
    local nNewTotal = nTotal;
    if string.match(sDamage, "%[HEAL") and string.match(sDamage, "%[TEMP%]") then
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
    end

    oldApplyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nNewTotal);
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

    --compatibility safeguard
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

function messageDamageAndClearVitalityLossState(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
    if sDamageType ~= "Heal" and sDamageType ~= "Temporary hit points" then
        if getVitalityLossState(rTarget) then
            setVitalityLossState(rTarget, false);

            if tonumber(sTotal) and tonumber(sTotal) > 0 then
                for _, nodeEffect in pairs(DB.getChildren(ActorManager.getCTNode(rTarget), "effects")) do
                    if string.find(DB.getValue(nodeEffect, "label", ""), "VITALITY;") then
                        EffectManager.expireEffect(rTarget, nodeEffect, 0);
                    end
                end
            end
        end
    end

    oldMessageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
end

function getVitalityLossState(rVitalActor)
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