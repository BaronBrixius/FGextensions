local bDataChangedLock = false;

function onInit()
    local nodeCastBox = getDatabaseNode();
    DB.addHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.addHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);
end

function onClose()
    local nodeCastBox = getDatabaseNode();
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);
end

function dataChangeIsLocked()
    if bDataChangedLock then
        return true;
    end
    return User.isHost() and #parentcontrol.window.parentcontrol.window.getViewers() > 0;
end

function setShape(nodeTalent, bSelected)
    if dataChangeIsLocked() then
        return ;
    end
    bDataChangedLock = true;

    for _, window in pairs(destruction_shapes.getWindows()) do
        window.setSelected(window.getDatabaseNode() == nodeTalent and bSelected);
    end

    updatePPCost();
    bDataChangedLock = false;
end

function setType(nodeTalent, bSelected)
    if dataChangeIsLocked() then
        return ;
    end
    bDataChangedLock = true;

    for _, window in pairs(destruction_types.getWindows()) do
        window.setSelected(window.getDatabaseNode() == nodeTalent and bSelected);
    end

    setShapesSpellResistIgnoreProperty(bSelected and getSpellResistIgnoreProperty(nodeTalent))
    updatePPCost();
    bDataChangedLock = false;
end

function setOtherTalent()
    if dataChangeIsLocked() then
        return ;
    end
    bDataChangedLock = true;

    for _, window in pairs(destruction_other.getWindows()) do
        window.setSelected(DB.getValue(window.getDatabaseNode(), ".selected", 0) == 1)
    end

    updatePPCost();
    bDataChangedLock = false;
end

function updatePPCost()
    DB.setValue(getDatabaseNode(), "cast.cost", "number", getTotalPPCost());
end

function getTotalPPCost()
    local nCost = getPPCost(destruction_shapes) + getPPCost(destruction_types) + getPPCost(destruction_other);

    if DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1 then
        nCost = nCost + 1;
    end

    return math.max(nCost, 0);
end

function getPPCost(wlCastTalents)
    local nCost = 0;
    for _, window in pairs(wlCastTalents.getWindows()) do
        local nodeTalent = window.getDatabaseNode();
        if DB.getValue(nodeTalent, ".selected", 0) == 1 then
            nCost = nCost + DB.getValue(nodeTalent, "cost", 0);
        end
    end
    return nCost;
end

function getSpellResistIgnoreProperty(nodeType)
    for _, typeAction in pairs(nodeType.getChild("actions").getChildren()) do
        if DB.getValue(typeAction, "type") == "damage" and DB.getValue(typeAction, "dmgnotspell", 0) == 1 then
            return true;
        end
    end
    return false;
end

function setShapesSpellResistIgnoreProperty(bIgnoreSpellResist)
    for _, nodeTalent in pairs(destruction_shapes.getDatabaseNode().getChildren()) do
        for _, nodeAction in pairs(nodeTalent.getChild("actions").getChildren()) do
            if DB.getValue(nodeAction, "type") == "cast" then
                DB.setValue(nodeAction, "srnotallowed", "number", bIgnoreSpellResist and 1 or 0);
                break ;  --only applies to first cast in a shape, since extra effects shouldn't need to reroll SR
            end
        end
    end
end

function fullPowerToggled(nSelectionValue)
    updatePPCost();
    setTypesFullPowerProperty(nSelectionValue == 1)
end

function setTypesFullPowerProperty(bFullPower)
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

function updateAllActionValues()
    updateActionValues(destruction_shapes);
    updateActionValues(destruction_types);
    updateActionValues(destruction_other);
end

function updateActionValues(wlCastTalents)
    for _, windowList in pairs(wlCastTalents.getWindows()) do
        for _, window in pairs(windowList.actions.getWindows()) do
            window.updateViews();
        end
    end
end

function usePower()
    local nodeSpell = getDatabaseNode();
    local sMessage;

    if DB.getValue(nodeSpell.getChild("."), "castertype", "") == "points" then
        local nPPTotal = DB.getValue(nodeSpell, ".points", 0);
        local nPPUsed = DB.getValue(nodeSpell, ".pointsused", 0);
        local nCost = DB.getValue(nodeSpell, "cast.cost", 0);

        sMessage = "Destructive Blast " .. " [" .. nCost .. " PP]";
        if (nPPTotal - nPPUsed) < nCost then
            sMessage = sMessage .. " [INSUFFICIENT PP AVAILABLE]";
        else
            DB.setValue(nodeSpell, ".pointsused", "number", nPPUsed + nCost);
        end
    else
        sMessage = "Destructive Blast " .. " [SPELL CLASS DOES NOT USE PP]";
    end

    ChatManager.Message(sMessage, true, ActorManager.getActor("", nodeSpell.getChild("...")));
end

