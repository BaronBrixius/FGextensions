
local nodeShape;
local nodeType;
local aOtherTalents = { };

function onInit()
    local nodeCastBox = getDatabaseNode();
    --DB.addHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_shapes")), 'onChildUpdate', resetShapeActions);
    --DB.addHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_types")), 'onChildUpdate', resetTypeActions);
    --DB.addHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_other")), 'onChildUpdate', resetOtherTalentActions);
    DB.addHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.addHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);
end

function onClose()
    local nodeCastBox = getDatabaseNode();
    --DB.removeHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_shapes")), 'onChildUpdate', resetShapeActions);
    --DB.removeHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_types")), 'onChildUpdate', resetTypeActions);
    --DB.removeHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_other")), 'onChildUpdate', resetOtherTalentActions);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);
end

local bDataChangedLock = false;

function setDataChangedLock(bNewValue)
    bDataChangedLock = bNewValue;
end

function updatePPCost()
    DB.setValue(getDatabaseNode(), "cast.cost", "number", getTotalPPCost(nodeShape, nodeType, aOtherTalents));
end

function getTotalPPCost()
    local nCost = DB.getValue(nodeShape, "cost", 0)
            + DB.getValue(nodeType, "cost", 0);

    for _, talent in pairs(aOtherTalents) do
        nCost = nCost + DB.getValue(talent, "cost", 0);
    end

    if DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1 then
        nCost = nCost + 1;
    end

    return math.max(nCost, 0);
end

function resetShapeActions()
    local nodeCastActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    for _, v in pairs(nodeCastActionsList.getChildren()) do
        if DB.getValue(v, "talenttype") == "shape" then
            DB.deleteNode(v);
        end
    end

    local bIgnoreSpellResist = getSpellResistPropertyFromType();

    if not nodeShape then
        createBasicCastAction(nodeCastActionsList, bIgnoreSpellResist);
        return ;
    end

    local aShapeActions = nodeShape.getChild("actions").getChildren();
    for _, v in pairs(aShapeActions) do
        local nodeNewAction = copyActionToCast(nodeCastActionsList, v);
        DB.setValue(nodeNewAction, "talenttype", "string", "shape");
        if DB.getValue(nodeNewAction, "type") == "cast" then
            applySpellResistIgnore(nodeNewAction, bIgnoreSpellResist);
        end
    end
end

function createBasicCastAction(nodeCastActionsList, bIgnoreSpellResist)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "cast");
    DB.setValue(nodeNewAction, "atktype", "string", "rtouch");
    DB.setValue(nodeNewAction, "talenttype", "string", "shape");

    applySpellResistIgnore(nodeNewAction, bIgnoreSpellResist);
end

function applySpellResistIgnore(nodeAction, bIgnoreSpellResist)
    if bIgnoreSpellResist then
        DB.setValue(nodeAction, "srnotallowed", "number", 1);
    else
        DB.setValue(nodeAction, "srnotallowed", "number", 0);
    end
end

function resetTypeActions()
    local nodeCastActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    for _, v in pairs(nodeCastActionsList.getChildren()) do
        if DB.getValue(v, "talenttype") == "type" then
            DB.deleteNode(v);
        end
    end

    local bFullPower = DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1;
    if not nodeType then
        createBasicDamageAction(nodeCastActionsList, bFullPower);
        return ;
    end

    local aTypeActions = nodeType.getChild("actions").getChildren();

    for _, action in pairs(aTypeActions) do
        local nodeNewAction = copyActionToCast(nodeCastActionsList, action);
        DB.setValue(nodeNewAction, "talenttype", "string", "type");
        if bFullPower and DB.getValue(nodeNewAction, "type") == "damage" then
            for _, dmgEntry in pairs(nodeNewAction.getChild("damagelist").getChildren()) do
                if DB.getValue(dmgEntry, "dicestat") == "oddcl" then
                    DB.setValue(dmgEntry, "dicestat", "string", "cl");
                end
            end
        end
    end
end

function createBasicDamageAction(nodeCastActionsList, bFullPower)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "damage");
    DB.setValue(nodeNewAction, "talenttype", "string", "type");

    local nodeDmgList = nodeNewAction.createChild("damagelist");
    local nodeDmgEntry = nodeDmgList.createChild();
    DB.setValue(nodeDmgEntry, "dice", "dice", { "d6" });
    DB.setValue(nodeDmgEntry, "type", "string", "bludgeoning");

    if bFullPower then
        DB.setValue(nodeDmgEntry, "dicestat", "string", "cl");
    else
        DB.setValue(nodeDmgEntry, "dicestat", "string", "oddcl");
    end
end

function resetOtherTalentActions()
    local nodeCastActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    for _, v in pairs(nodeCastActionsList.getChildren()) do
        if DB.getValue(v, "talenttype") == "zOther" then
            DB.deleteNode(v);
        end
    end

    for _, talent in pairs(aOtherTalents) do
        for _, action in pairs(talent.getChild("actions").getChildren()) do
            local nodeNewAction = copyActionToCast(nodeCastActionsList, action);
            DB.setValue(nodeNewAction, "talenttype", "string", "zOther");
        end
    end
end

function copyTalentActionsToCast(nodeCastActionsList, nodeTalent)
    local aTalentActions = nodeTalent.getChild("actions").getChildren();

    local aKeys = { };
    for k in pairs(aTalentActions) do
        table.insert(aKeys, k);
    end
    table.sort(aKeys);

    for _, k in ipairs(aKeys) do
        copyActionToCast(nodeCastActionsList, aTalentActions[k]);
    end
end

function copyActionToCast(nodeCastActionsList, nodeAction)
    --todo remove detailbutton from action when copied over
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.copyNode(nodeAction, nodeNewAction);
    return nodeNewAction;
end

function getSpellResistPropertyFromType()
    if not nodeType then
        return false;
    end

    for _, typeAction in pairs(nodeType.getChild("actions").getChildren()) do
        if DB.getValue(typeAction, "type") == "damage" and DB.getValue(typeAction, "dmgnotspell", 0) == 1 then
            return true;
        end
    end

    return false;
end

function setShape(nodeTalent, nSelectionValue)
    if bDataChangedLock then
        return;
    end
    setDataChangedLock(true);

    if nSelectionValue == 0 then
        nodeShape = nil;
    else
        DB.setValue(nodeShape, ".selected", "number", 0);
        nodeShape = nodeTalent;
    end

    resetShapeActions();
    setDataChangedLock(false);
end

function setType(nodeTalent, nSelectionValue)
    if bDataChangedLock then
        return;
    end
    setDataChangedLock(true);

    if nSelectionValue == 0 then
        nodeType = nil;
    else
        DB.setValue(nodeType, ".selected", "number", 0);
        nodeType = nodeTalent;
    end

    resetTypeActions();
    setDataChangedLock(false);
end

function setOtherTalent(nodeTalent, nSelectionValue)
    if bDataChangedLock then
        return;
    end
    setDataChangedLock(true);
    
    local sName = nodeTalent.getNodeName();
    if nSelectionValue == 0 then
        aOtherTalents[sName] = nil;
    else
        aOtherTalents[sName] = nodeTalent;
    end

    resetOtherTalentActions();
    setDataChangedLock(false);
end


function onSpellAction(draginfo, nodeAction, sSubRoll)
    --Debug.chat('cast button')

    --createDisplay();


    --if not nodeAction then
    --    return;
    --end
    --
    --local rActor = ActorManager.getActor("", nodeAction.getChild("..."));
    --Debug.chat(rActor)
    --if not rActor then
    --    return;
    --end
    --
    --local rAction = SpellManager.getSpellAction(rActor, nodeAction, sSubRoll);
    --
    --local rRolls = {};
    --local rCustom = nil;
    --if rAction.type == "cast" then
    --    if not rAction.subtype then
    --        table.insert(rRolls, ActionSpell.getSpellCastRoll(rActor, rAction));
    --    end
    --
    --    if not rAction.subtype or rAction.subtype == "atk" then
    --        if rAction.range then
    --            table.insert(rRolls, ActionAttack.getRoll(rActor, rAction));
    --        end
    --    end
    --
    --    if not rAction.subtype or rAction.subtype == "clc" then
    --        local rRoll = ActionSpell.getCLCRoll(rActor, rAction);
    --        if not rAction.subtype then
    --            rRoll.sCategory = "castclc";
    --            rRoll.aDice = {};
    --        end
    --        table.insert(rRolls, rRoll);
    --    end
    --
    --    if not rAction.subtype or rAction.subtype == "save" then
    --        if rAction.save and rAction.save ~= "" then
    --            local rRoll = ActionSpell.getSaveVsRoll(rActor, rAction);
    --            if not rAction.subtype then
    --                rRoll.sCategory = "castsave";
    --            end
    --            table.insert(rRolls, rRoll);
    --        end
    --    end
    --
    --elseif rAction.type == "damage" then
    --    local rRoll = ActionDamage.getRoll(rActor, rAction);
    --    if rAction.bSpellDamage then
    --        rRoll.sCategory = "spdamage";
    --    else
    --        rRoll.sCategory = "damage";
    --    end
    --
    --    table.insert(rRolls, rRoll);
    --
    --elseif rAction.type == "heal" then
    --    table.insert(rRolls, ActionHeal.getRoll(rActor, rAction));
    --
    --elseif rAction.type == "effect" then
    --    local rRoll;
    --    rRoll = ActionEffect.getRoll(draginfo, rActor, rAction);
    --    if rRoll then
    --        table.insert(rRolls, rRoll);
    --    end
    --end
    --
    --if #rRolls > 0 then
    --    ActionsManager.performMultiAction(draginfo, rActor, rRolls[1].sCategory, rRolls);
    --end
end

function usePower()
    local nodeSpell = getDatabaseNode();
    local nodeSpellClass = nodeSpell.getChild(".");
    local rActor = ActorManager.getActor("", nodeSpell.getChild("..."))

    local sMessage;

    if DB.getValue(nodeSpellClass, "castertype", "") == "points" then
        local nPP = DB.getValue(nodeSpell, ".points", 0);
        local nPPUsed = DB.getValue(nodeSpell, ".pointsused", 0);
        local nCost = DB.getValue(nodeSpell, "cast.cost", 0);

        sMessage = DB.getValue(nodeSpell, "name", "") .. " [" .. nCost .. " PP]";
        if (nPP - nPPUsed) < nCost then
            sMessage = sMessage .. " [INSUFFICIENT PP AVAILABLE]";
        else
            nPPUsed = nPPUsed + nCost;
            DB.setValue(nodeSpell, ".pointsused", "number", nPPUsed);
        end
    else
        sMessage = DB.getValue(nodeSpell, "name", "") .. " [SPELL CLASS DOES NOT USE PP]";
    end

    ChatManager.Message(sMessage, ActorManager.isPC(rActor), rActor);
end

function updateAllActionValues()
    updateTalentActionValues();
    updateCastActionValues();
end

function updateCastActionValues()
    for _, w in pairs(destruction_actions.getWindows()) do
        w.updateViews();
    end
end

function updateTalentActionValues()
    for _, wl in pairs(parentcontrol.window.shape_list.getWindows()) do
        for _, w in pairs(wl.actions.getWindows()) do
            w.updateViews();
        end
    end

    for _, wl in pairs(parentcontrol.window.type_list.getWindows()) do
        for _, w in pairs(wl.actions.getWindows()) do
            w.updateViews();
        end
    end
end