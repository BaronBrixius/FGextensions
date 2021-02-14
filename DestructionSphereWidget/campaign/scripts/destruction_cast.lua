local bDataChangedLock = false;

function onInit()
    local nodeCastBox = getDatabaseNode();
    DB.addHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateActionValues);
    DB.addHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateActionValues);
end

function onClose()
    local nodeCastBox = getDatabaseNode();
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateActionValues);
end

function setDataChangedLock(bNewValue)
    bDataChangedLock = bNewValue;
end

function dataChangeIsLocked()
    if bDataChangedLock then
        return true;
    end

    return User.isHost() and #parentcontrol.window.parentcontrol.window.getViewers() > 0;
end

function setShape(nodeTalent, nSelectionValue)
    if dataChangeIsLocked() then
        return ;
    end
    setDataChangedLock(true);

    for _, window in pairs(destruction_shapes.getWindows()) do
        window.setSelected(window.getDatabaseNode() == nodeTalent and nSelectionValue == 1);
    end

    updatePPCost();
    setDataChangedLock(false);
end

function setType(nodeTalent, nSelectionValue)
    if dataChangeIsLocked() then
        return ;
    end
    setDataChangedLock(true);

    for _, window in pairs(destruction_types.getWindows()) do
        window.setSelected(window.getDatabaseNode() == nodeTalent and nSelectionValue == 1);
    end

    setShapeSpellResistProperty(getSpellResistPropertyFromType())
    updatePPCost();
    setDataChangedLock(false);
end

function setOtherTalent()
    if dataChangeIsLocked() then
        return ;
    end
    setDataChangedLock(true);

    for _, window in pairs(destruction_other.getWindows()) do
        window.setSelected(DB.getValue(window.getDatabaseNode(), ".selected", 0) == 1)
    end

    updatePPCost();
    setDataChangedLock(false);
end

function updatePPCost()
    DB.setValue(getDatabaseNode(), "cast.cost", "number", getTotalPPCost());
end

function getTotalPPCost()
    local nCost = 0;

    for _, window in pairs(destruction_shapes.getWindows()) do
        local nodeTalent = window.getDatabaseNode();
        if DB.getValue(nodeTalent, ".selected", 0) == 1 then
            nCost = nCost + DB.getValue(nodeTalent, "cost", 0);
            break;
        end
    end

    for _, window in pairs(destruction_types.getWindows()) do
        local nodeTalent = window.getDatabaseNode();
        if DB.getValue(nodeTalent, ".selected", 0) == 1 then
            nCost = nCost + DB.getValue(nodeTalent, "cost", 0);
            break;
        end
    end

    for _, window in pairs(destruction_other.getWindows()) do
        local nodeTalent = window.getDatabaseNode();
        if DB.getValue(nodeTalent, ".selected", 0) == 1 then
            nCost = nCost + DB.getValue(nodeTalent, "cost", 0);
        end
    end

    if DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1 then
        nCost = nCost + 1;
    end

    return math.max(nCost, 0);
end

--function createBasicCastAction(nodeCastActionsList, bIgnoreSpellResist)
--    local nodeNewAction = nodeCastActionsList.createChild();
--    DB.setValue(nodeNewAction, "type", "string", "cast");
--    DB.setValue(nodeNewAction, "atktype", "string", "rtouch");
--    DB.setValue(nodeNewAction, "talenttype", "string", "shapes");
--
--    DB.setValue(nodeNewAction, "srnotallowed", "number", bIgnoreSpellResist and 1 or 0);
--end
--
--function createBasicDamageAction(nodeCastActionsList, bFullPower)
--    local nodeNewAction = nodeCastActionsList.createChild();
--    DB.setValue(nodeNewAction, "type", "string", "damage");
--    DB.setValue(nodeNewAction, "talenttype", "string", "types");
--
--    local nodeDmgEntry = nodeNewAction.createChild("damagelist").createChild();
--    DB.setValue(nodeDmgEntry, "dice", "dice", { "d6" });
--    DB.setValue(nodeDmgEntry, "type", "string", "bludgeoning");
--    DB.setValue(nodeDmgEntry, "dicestat", "string", bFullPower and "cl" or "oddcl");
--end

function getSpellResistPropertyFromType()
    for _, window in pairs(destruction_types.getWindows()) do
        local nodeTalent = window.getDatabaseNode();
        if DB.getValue(nodeTalent, ".selected", 0) == 1 then
            for _, typeAction in pairs(nodeTalent.getChild("actions").getChildren()) do
                if DB.getValue(typeAction, "type") == "damage" and DB.getValue(typeAction, "dmgnotspell", 0) == 1 then
                    return true;
                end
            end
        end
    end

    return false;
end

function setShapeSpellResistProperty(bIgnoreSpellResist)
    for _, nodeTalent in pairs(destruction_shapes.getDatabaseNode().getChildren()) do
        for _, nodeAction in pairs(nodeTalent.getChild("actions").getChildren()) do
            if DB.getValue(nodeAction, "type") == "cast" then
                DB.setValue(nodeAction, "srnotallowed", "number", bIgnoreSpellResist and 1 or 0);
                break;  --only applies to first cast in a shape, since extra effects shouldn't need to reroll SR
            end
        end
    end
end

function fullPowerToggled(nSelectionValue)
    updatePPCost();
    setFullPowerProperty(nSelectionValue == 1)
end

function setFullPowerProperty(bFullPower)
    for _, nodeTalent in pairs(destruction_types.getDatabaseNode().getChildren()) do
        for _, nodeAction in pairs(nodeTalent.getChild("actions").getChildren()) do
            if DB.getValue(nodeAction, "type") == "damage" then
                for _, dmgEntry in pairs(nodeAction.getChild("damagelist").getChildren()) do
                    local diceStat = DB.getValue(dmgEntry, "dicestat");
                    if diceStat == "oddcl" or diceStat == "cl" then
                        DB.setValue(dmgEntry, "dicestat", "string", bFullPower and "cl" or "oddcl");
                    end
                end
            end
        end
    end
end

function updateActionValues()
    for _, windowList in pairs(destruction_shapes.getWindows()) do
        for _, window in pairs(windowList.actions.getWindows()) do
            window.updateViews();
        end
    end

    for _, windowList in pairs(destruction_types.getWindows()) do
        for _, window in pairs(windowList.actions.getWindows()) do
            window.updateViews();
        end
    end

    for _, windowList in pairs(destruction_other.getWindows()) do
        for _, window in pairs(windowList.actions.getWindows()) do
            window.updateViews();
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

