function onInit()
    local nodeCast = getDatabaseNode();
    DB.addHandler(DB.getPath(nodeCast.getChild("spells.spell0.destruction_shapes")), 'onChildUpdate', updateCastDisplay); --todo maybe destruction_other needs this
    DB.addHandler(DB.getPath(nodeCast.getChild("spells.spell0.destruction_types")), 'onChildUpdate', updateCastDisplay);
    DB.addHandler(DB.getPath(nodeCast.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.addHandler(DB.getPath(nodeCast.getChild(".dc.total")), 'onUpdate', updateAllActionValues);

    doWithLock(updateCastDisplay)
end

function onClose()
    local nodeCast = getDatabaseNode();
    DB.removeHandler(DB.getPath(nodeCast.getChild("spells.spell0.destruction_shapes")), 'onChildUpdate', updateCastDisplay);
    DB.removeHandler(DB.getPath(nodeCast.getChild("spells.spell0.destruction_types")), 'onChildUpdate', updateCastDisplay);
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

function selectTalent(rNewTalent, sCategory)    --todo creating new talent removes selection and takes a while
    if sCategory == "shapes" then
        doWithLock(clearOtherShapes, rNewTalent)
    elseif sCategory == "types" then
        doWithLock(clearOtherTypes, rNewTalent)
    end

    updateCastDisplay();
end

function clearOtherShapes(rSelectedShape)
    --todo make this method not copypasted
    --if sType ~= "shapes" and sType ~="types" then
    --    return;
    --end
    local rSelectedShapeNode = rSelectedShape.getDatabaseNode();
    for _, v in pairs(getDatabaseNode().getChild("spells.spell0.destruction_shapes").getChildren()) do
        if v ~= rSelectedShapeNode then
            DB.setValue(v, ".selected", "number", 0);
        end
    end
end

function clearOtherTypes(rSelectedType)
    local rSelectedTypeNode = rSelectedType.getDatabaseNode();
    for _, v in pairs(getDatabaseNode().getChild("spells.spell0.destruction_types").getChildren()) do
        if v ~= rSelectedTypeNode then
            DB.setValue(v, ".selected", "number", 0);
        end
    end
end

function getTalent(sCategory)
    for _, v in pairs(getDatabaseNode().getChild("spells.spell0.destruction_" .. sCategory).getChildren()) do
        if DB.getValue(v, ".selected", 0) == 1 then
            return v;
        end
    end
    return nil;
end

function updateCastDisplay()
    local nodeShape, nodeType, aOtherTalents = getAllSelectedTalents();
    updateCost(nodeShape, nodeType, aOtherTalents);
    setCastActions(nodeShape, nodeType, aOtherTalents);
end

function updateCost(nodeShape, nodeType, aOtherTalents)
    if not aOtherTalents then
        nodeShape, nodeType, aOtherTalents = getAllSelectedTalents();
    end
    DB.setValue(getDatabaseNode(), "cast.cost", "number", getTotalCost(nodeShape, nodeType, aOtherTalents));
end

function getAllSelectedTalents()
    local nodeShape = getTalent("shapes") or nil;
    local nodeType = getTalent("types") or nil;

    local aOtherTalents = { };
    for _, talent in pairs(getDatabaseNode().getChild("spells.spell0.destruction_other").getChildren()) do
        if DB.getValue(talent, ".selected", 0) == 1 then
            table.insert(aOtherTalents, talent);
        end
    end

    return nodeShape, nodeType, aOtherTalents;
end

function getTotalCost(nodeShape, nodeType, aOtherTalents)
    local nCost = DB.getValue(nodeShape, "cost", 0) + DB.getValue(nodeType, "cost", 0);

    for _, talent in pairs(aOtherTalents) do
        nCost = nCost + DB.getValue(talent, "cost", 0);
    end

    if DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1 then
        nCost = nCost + 1;
    end

    return math.max(nCost, 0);
end

function setCastActions(nodeShape, nodeType, aOtherTalents)
    if not aOtherTalents then
        nodeShape, nodeType, aOtherTalents = getAllSelectedTalents();
    end

    local nodeActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    DB.deleteChildren(nodeActionsList)

    addTalentToCast(nodeActionsList, nodeShape, "shapes");
    setSpellResistancePropertyFromType(nodeActionsList, nodeType);
    addTalentToCast(nodeActionsList, nodeType, "types");


    for _, v in ipairs(getDatabaseNode().getChild("spells.spell0.destruction_other").getChildren()) do
        if DB.getValue(v, ".selected", 0) == 1 then
            addTalentToCast(nodeActionsList, v)
        end
    end

end

function addTalentToCast(nodeCastActionsList, nodeTalent, sCategory)
    if not nodeTalent then
        if sCategory then
            if sCategory == "shapes" then
                addBasicShape(nodeCastActionsList);
            elseif sCategory == "types" then
                addBasicType(nodeCastActionsList);
            end
        end
        return ;
    end

    local aTalentActions = nodeTalent.getChild("actions").getChildren();

    local aKeys = { };
    for k in pairs(aTalentActions) do
        table.insert(aKeys, k);
    end
    table.sort(aKeys);

    for _, k in ipairs(aKeys) do
        addAction(nodeCastActionsList, aTalentActions[k]);
    end
end

function addBasicShape(nodeCastActionsList)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "cast");
    DB.setValue(nodeNewAction, "atktype", "string", "rtouch");
end

function addBasicType(nodeCastActionsList)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "damage");

    local nodeDmgList = nodeNewAction.createChild("damagelist");
    local nodeDmgEntry = nodeDmgList.createChild();
    DB.setValue(nodeDmgEntry, "dice", "dice", { "d6" });
    DB.setValue(nodeDmgEntry, "dicestat", "string", "oddcl");
    DB.setValue(nodeDmgEntry, "type", "string", "bludgeoning");
end

function addAction(nodeCastActionsList, nodeAction)   --todo remove detailbutton from action when copied over
    DB.copyNode(nodeAction, nodeCastActionsList.createChild());
end

function setSpellResistancePropertyFromType(nodeActionsList, nodeType)
    local bIgnoreSpellResist = false;
    for _, typeAction in pairs(nodeType.getChild("actions").getChildren()) do
        if DB.getValue(typeAction, "type") == "damage" and DB.getValue(typeAction, "dmgnotspell", 0) == 1 then
            bIgnoreSpellResist = true;
        end
    end

    if not bIgnoreSpellResist then
        return ;
    end

    for _, castAction in pairs(nodeActionsList.getChildren()) do
        if DB.getValue(castAction, "type") == "cast" then
            DB.setValue(castAction, "srnotallowed", "number", 1);
        end
    end
end

function activatePower()
    Debug.chat('activate power')
    local nodeSpell = getDatabaseNode();
    if nodeSpell then
        ChatManager.Message(getDescription(), true, ActorManager.getActor("", nodeSpell.getChild(".....")));
    end
end

function onSpellAction(draginfo, nodeAction, sSubRoll)
    --todo cast should use PP and cast all actions until failure
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