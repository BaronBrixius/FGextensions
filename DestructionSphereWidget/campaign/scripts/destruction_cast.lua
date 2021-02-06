local nodeShape;
local nodeType;
local aOtherTalents = { };
local bDataChangedLock = false;

function onInit()
    local nodeCastBox = getDatabaseNode();
    DB.addHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.addHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);

    if not nodeShape then
        nodeShape = getSelection("shapes");
    end
    if nodeShape then
        DB.addHandler(DB.getPath(nodeShape.getChild("actions")), 'onChildUpdate', updateShapeActions)
    end

    if not nodeType then
        nodeType = getSelection("types");
    end
    if nodeType then
        DB.addHandler(DB.getPath(nodeType.getChild("actions")), 'onChildUpdate', updateTypeActions)
    end

    aOtherTalents = { };
    for _, talent in pairs(getDatabaseNode().getChild("spells.spell0.destruction_other").getChildren()) do
        if DB.getValue(talent, ".selected", 0) == 1 then
            aOtherTalents[talent.getNodeName()] = talent;
            DB.addHandler(DB.getPath(talent.getChild("actions")), 'onChildUpdate', updateOtherActions)
        end
    end

    updateShapeActions()
    updateTypeActions()
    updateOtherActions()
end

function onClose()
    local nodeCastBox = getDatabaseNode();
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);
end

function getSelection(sCategory)
    for _, v in pairs(getDatabaseNode().getChild("spells.spell0.destruction_" .. sCategory).getChildren()) do
        if DB.getValue(v, ".selected", 0) == 1 then
            return v;
        end
    end
    return nil;
end

function setDataChangedLock(bNewValue)
    bDataChangedLock = bNewValue;
end

function setShape(nodeTalent, nSelectionValue)
    if bDataChangedLock then
        return ;
    end
    setDataChangedLock(true);

    clearShapeSelection();
    if nSelectionValue == 1 then
        nodeShape = nodeTalent;
        DB.addHandler(DB.getPath(nodeShape.getChild("actions")), 'onChildUpdate', updateShapeActions)
    end

    setDataChangedLock(false);
    updateShapeActions();
    updatePPCost();
end

function clearShapeSelection()
    if not nodeShape then
        return ;
    end

    DB.removeHandler(DB.getPath(nodeShape.getChild("actions")), 'onChildUpdate', updateShapeActions)
    DB.setValue(nodeShape, ".selected", "number", 0);
    nodeShape = nil;
end

function setType(nodeTalent, nSelectionValue)
    if bDataChangedLock then
        return ;
    end
    setDataChangedLock(true);

    clearTypeSelection();
    if nSelectionValue == 1 then
        nodeType = nodeTalent;
        DB.addHandler(DB.getPath(nodeType.getChild("actions")), 'onChildUpdate', updateTypeActions)
    end

    setDataChangedLock(false);
    updateTypeActions();
    updatePPCost();
end

function clearTypeSelection()
    if not nodeType then
        return ;
    end

    DB.removeHandler(DB.getPath(nodeType.getChild("actions")), 'onChildUpdate', updateTypeActions)
    DB.setValue(nodeType, ".selected", "number", 0);
    nodeType = nil;
end

function setOtherTalent(nodeTalent, nSelectionValue)
    if bDataChangedLock then
        return ;
    end
    setDataChangedLock(true);

    local sName = nodeTalent.getNodeName();
    if nSelectionValue == 0 then
        clearOtherSelection(sName)
    else
        aOtherTalents[sName] = nodeTalent;
        DB.addHandler(DB.getPath(aOtherTalents[sName].getChild("actions")), 'onChildUpdate', updateOtherActions)
    end

    setDataChangedLock(false);
    updateOtherActions();
    updatePPCost();
end

function clearOtherSelection(sName)
    if not aOtherTalents[sName] then
        return ;
    end

    DB.removeHandler(DB.getPath(aOtherTalents[sName].getChild("actions")), 'onChildUpdate', updateOtherActions)
    DB.setValue(aOtherTalents[sName], ".selected", "number", 0);
    aOtherTalents[sName] = nil;
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

function updateShapeActions()
    if bDataChangedLock then
        return ;
    end
    setDataChangedLock(true);

    local nodeCastActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    deleteActionsInCategory(nodeCastActionsList, "shapes");

    local bIgnoreSpellResist = getSpellResistPropertyFromType();

    if not nodeShape then
        createBasicCastAction(nodeCastActionsList, bIgnoreSpellResist);
        setDataChangedLock(false);
        return ;
    end

    for _, v in pairs(nodeShape.getChild("actions").getChildren()) do
        local nodeNewAction = copyActionToCast(nodeCastActionsList, v);
        if DB.getValue(nodeNewAction, "type") == "cast" then
            DB.setValue(nodeNewAction, "srnotallowed", "number", bIgnoreSpellResist and 1 or 0);
        end
    end

    setDataChangedLock(false);
end

function updateTypeActions()
    if bDataChangedLock then
        return ;
    end
    setDataChangedLock(true);

    local nodeCastActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    deleteActionsInCategory(nodeCastActionsList, "types");

    local bFullPower = DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1;

    setShapeSpellResistProperty(nodeCastActionsList, getSpellResistPropertyFromType());

    if not nodeType then
        createBasicDamageAction(nodeCastActionsList, bFullPower);
        setDataChangedLock(false);
        return ;
    end

    for _, action in pairs(nodeType.getChild("actions").getChildren()) do
        local nodeNewAction = copyActionToCast(nodeCastActionsList, action);
        if bFullPower and DB.getValue(nodeNewAction, "type") == "damage" then
            for _, dmgEntry in pairs(nodeNewAction.getChild("damagelist").getChildren()) do
                if DB.getValue(dmgEntry, "dicestat") == "oddcl" then
                    DB.setValue(dmgEntry, "dicestat", "string", "cl");
                end
            end
        end
    end

    setDataChangedLock(false);
end

function updateOtherActions()
    if bDataChangedLock then
        return ;
    end
    setDataChangedLock(true);

    local nodeCastActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    deleteActionsInCategory(nodeCastActionsList, "other");

    for _, talent in pairs(aOtherTalents) do
        for _, action in pairs(talent.getChild("actions").getChildren()) do
            copyActionToCast(nodeCastActionsList, action);
        end
    end

    setDataChangedLock(false);
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
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.copyNode(nodeAction, nodeNewAction);
    return nodeNewAction;
end

function deleteActionsInCategory(nodeCastActionsList, sCategory)
    for _, v in pairs(nodeCastActionsList.getChildren()) do
        if DB.getValue(v, "talenttype") == sCategory then
            DB.deleteNode(v);
        end
    end
end

function createBasicCastAction(nodeCastActionsList, bIgnoreSpellResist)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "cast");
    DB.setValue(nodeNewAction, "atktype", "string", "rtouch");
    DB.setValue(nodeNewAction, "talenttype", "string", "shapes");

    DB.setValue(nodeAction, "srnotallowed", "number", bIgnoreSpellResist and 1 or 0);
end

function createBasicDamageAction(nodeCastActionsList, bFullPower)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "damage");
    DB.setValue(nodeNewAction, "talenttype", "string", "types");

    local nodeDmgEntry = nodeNewAction.createChild("damagelist").createChild();
    DB.setValue(nodeDmgEntry, "dice", "dice", { "d6" });
    DB.setValue(nodeDmgEntry, "type", "string", "bludgeoning");
    DB.setValue(nodeDmgEntry, "dicestat", "string", bFullPower and "cl" or "oddcl");
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

function setShapeSpellResistProperty(nodeCastActionsList, bIgnoreSpellResist)
    for _, nodeAction in pairs(nodeCastActionsList.getChildren()) do
        if DB.getValue(nodeAction, "talenttype") == "shapes" and DB.getValue(nodeAction, "type") == "cast" then
            DB.setValue(nodeAction, "srnotallowed", "number", bIgnoreSpellResist and 1 or 0);
        end
    end
end

function fullPowerToggled(nSelectionValue)
    updatePPCost();
    setFullPowerProperty(getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions") , nSelectionValue == 1)
end

function setFullPowerProperty(nodeCastActionsList, bFullPower)
    for _, nodeAction in pairs(nodeCastActionsList.getChildren()) do
        if DB.getValue(nodeAction, "talenttype") == "types" and DB.getValue(nodeAction, "type") == "damage" then
            for _, dmgEntry in pairs(nodeAction.getChild("damagelist").getChildren()) do
                local diceStat = DB.getValue(dmgEntry, "dicestat");
                if diceStat == "oddcl" or diceStat == "cl" then
                    DB.setValue(dmgEntry, "dicestat", "string", bFullPower and "cl" or "oddcl");
                end
            end
        end
    end
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

    for _, wl in pairs(parentcontrol.window.other_list.getWindows()) do
        for _, w in pairs(wl.actions.getWindows()) do
            w.updateViews();
        end
    end
end