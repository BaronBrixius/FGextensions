function onInit()
    local nodeCast = getDatabaseNode();
    DB.addHandler(DB.getPath(nodeCast.getChild("destruction_shapes")), 'onChildUpdate', updateCastActionList);
    DB.addHandler(DB.getPath(nodeCast.getChild("destruction_types")), 'onChildUpdate', updateCastActionList);
    DB.addHandler(DB.getPath(nodeCast.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.addHandler(DB.getPath(nodeCast.getChild(".dc.total")), 'onUpdate', updateAllActionValues);

    doWithLock(updateCastDisplay)
end

function onClose()
    local nodeCast = getDatabaseNode();
    DB.removeHandler(DB.getPath(nodeCast.getChild("destruction_shapes")), 'onChildUpdate', updateCastActionList);
    DB.removeHandler(DB.getPath(nodeCast.getChild("destruction_types")), 'onChildUpdate', updateCastActionList);
    DB.removeHandler(DB.getPath(nodeCast.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.removeHandler(DB.getPath(nodeCast.getChild(".dc.total")), 'onUpdate', updateAllActionValues);
end

local bDataChangedLock = false;
function doWithLock(fFunction, aArguments)
    if bDataChangedLock == true then
        return false;
    end
    bDataChangedLock = true;

    fFunction(aArguments)

    bDataChangedLock = false;
    return true;
end

function selectTalent(rNewTalent, sCategory)
    if sCategory == "shapes" then
        doWithLock(clearOtherShapes, rNewTalent)
    elseif sCategory == "types" then
        doWithLock(clearOtherTypes, rNewTalent)
    end

    updateCastDisplay();
end

function clearOtherShapes(rSelectedShape)       --todo make this method not copypasted
    --if sType ~= "shapes" and sType ~="types" then
    --    return;
    --end
    local rSelectedShapeNode = rSelectedShape.getDatabaseNode();
    for _, v in pairs(getDatabaseNode().getChild("destruction_shapes").getChildren()) do
        if v ~= rSelectedShapeNode then
            DB.setValue(v, ".selected", "number", 0);
        end
    end
end

function clearOtherTypes(rSelectedType)
    local rSelectedTypeNode = rSelectedType.getDatabaseNode();
    for _, v in pairs(getDatabaseNode().getChild("destruction_types").getChildren()) do
        if v ~= rSelectedTypeNode then
            DB.setValue(v, ".selected", "number", 0);
        end
    end
end

function getTalent(sCategory)
    for _, v in pairs(getDatabaseNode().getChild("destruction_" .. sCategory).getChildren()) do
        if DB.getValue(v, ".selected", 0) == 1 then
            return v;
        end
    end
    return nil;
end

function updateCastDisplay()
    updateCost();
    updateCastActionList();
    --Debug.chat(getDatabaseNode().getChild("destruction_shapes").getChildren())
    --Debug.chat(DB.getPath(retrieveShapeSelection().getChild("cost"), "cast.cost"))

    --local num = getDatabaseNode().getChild("cost");
    --Debug.chat(num.type)
    --Debug.chat(num)

    --local node = retrieveShapeSelection().getChild("cost");
    --if node then
    --    num.sources[name] = node;
    --    node.onUpdate = sourceUpdate;
    --    num.hasSources = true;
    --end
    --DB.setValue(getDatabaseNode().getChild("cost"), retrieveShapeSelection().getChild("cost"), "number", 0);
    --Debug.chat(DB.getValue(retrieveShapeSelection().getChild("cost"), "cast.cost", 0).sources)

end

function updateCost()
    local nCost = DB.getValue(getTalent("shapes"), "cost", 0) + DB.getValue(getTalent("types"), "cost", 0);

    for _, v in pairs(getDatabaseNode().getChild("destruction_other").getChildren()) do
        if DB.getValue(v, ".selected", 0) == 1 then
            nCost = nCost + DB.getValue(v, "cost", 0);
        end
    end

    if DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1 then
        nCost = nCost + 1;
    end

    DB.setValue(getDatabaseNode(), "cast.cost", "number", nCost);
end

function updateCastActionList()
    local nodeSpell = getDatabaseNode();
    local nodeActionsList = nodeSpell.createChild("level.level0.spell.spell0.destruction_actions");

    DB.deleteChildren(nodeActionsList)

    copyActionsToCast(nodeActionsList, getTalent("shapes"));
    copyActionsToCast(nodeActionsList, getTalent("types"));

    for _, v in pairs(getDatabaseNode().getChild("destruction_other").getChildren()) do
        if DB.getValue(v, ".selected", 0) == 1 then
            copyActionsToCast(nodeActionsList, v)
        end
    end

    copySpellResistanceFromDamageToCast();
end

function copyActionsToCast(aCastActions, nodeTalent)
    if not nodeTalent then
        Debug.chat(nodeTalent)
        --addBasicAction(aCastActions) --todo
        return;
    end
    local aTalentActions = nodeTalent.getChild("spells.spell0.actions").getChildren();

    local aKeys = { };
    for k in pairs(aTalentActions) do
        table.insert(aKeys, k);
    end
    table.sort(aKeys);

    for _,k in ipairs(aKeys) do
        addActions(aCastActions, aTalentActions[k]);
    end
end

function addActions(nodeActionsList, nodeAction)   --todo remove detailbutton from action when copied over
    local nodeNewAction = nodeActionsList.createChild();
    DB.copyNode(nodeAction, nodeNewAction);
    --Debug.chat(nodeNewAction.getPath().getControls())
end

function copySpellResistanceFromDamageToCast()
    --todo
end

function activatePower()
    Debug.chat('activate power')
    local nodeSpell = getDatabaseNode();
    if nodeSpell then
        ChatManager.Message(getDescription(), true, ActorManager.getActor("", nodeSpell.getChild(".....")));
    end
end

function onSpellAction(draginfo, nodeAction, sSubRoll) --todo cast should use PP and cast all actions until failure
    Debug.chat('cast button')

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
        sMessage = DB.getValue(nodeSpell, "name", "");
    end

    ChatManager.Message(sMessage, ActorManager.isPC(rActor), rActor);
end

function onSpellCounterUpdate()
    Debug.chat('spell counter update')
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