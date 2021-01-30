function onInit()
    local nodeCastBox = getDatabaseNode();
    DB.addHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_shapes")), 'onChildUpdate', updateCastActionValues); --todo maybe destruction_other needs this
    DB.addHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_types")), 'onChildUpdate', updateCastActionValues);
    DB.addHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_other")), 'onChildUpdate', updateCastActionValues);
    DB.addHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.addHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);

    updateCast()
end

function onClose()
    local nodeCastBox = getDatabaseNode();
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_shapes")), 'onChildUpdate', updateCastActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_types")), 'onChildUpdate', updateCastActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("spells.spell0.destruction_other")), 'onChildUpdate', updateCastActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.removeHandler(DB.getPath(nodeCastBox.getChild(".dc.total")), 'onUpdate', updateAllActionValues);
end

function clearNotSelectedTalents(nodeTalentList, nodeSelection)
    for _, v in pairs(nodeTalentList.getChildren()) do
        if v ~= nodeSelection then
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

local bDataChangedLock = false;
function updateCast()   --todo find better way to determine when it should update, currently either overupdates if the handler points to this, or underupdates if not
    if bDataChangedLock then
        return false;
    end
    bDataChangedLock = true;

    Debug.chat("updatecast")
    printstack()
    local nodeShape, nodeType, aOtherTalents = getAllSelectedTalents();
    updatePPCost(nodeShape, nodeType, aOtherTalents);
    setCastActions(nodeShape, nodeType, aOtherTalents);

    bDataChangedLock = false;
    return true;
end

function updatePPCost(nodeShape, nodeType, aOtherTalents)
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

function setCastActions(nodeShape, nodeType, aOtherTalents)
    if not aOtherTalents then
        nodeShape, nodeType, aOtherTalents = getAllSelectedTalents();
    end

    local nodeActionsList = getDatabaseNode().createChild("level.level0.spell.spell0.destruction_actions");
    DB.deleteChildren(nodeActionsList)

    local bIgnoreSpellResist = getSpellResistPropertyFromType(nodeType);
    addShapeToCast(nodeActionsList, nodeShape, bIgnoreSpellResist);

    local bFullPower = (DB.getValue(getDatabaseNode(), ".fullpower", 0) == 1);
    addTypeToCast(nodeActionsList, nodeType, bFullPower);

    for _, v in ipairs(getDatabaseNode().getChild("spells.spell0.destruction_other").getChildren()) do
        if DB.getValue(v, ".selected", 0) == 1 then
            addTalentToCast(nodeActionsList, v)
        end
    end
end

function addShapeToCast(nodeCastActionsList, nodeShape, bIgnoreSpellResist)
    if not nodeShape then
        addBasicCastAction(nodeCastActionsList, bIgnoreSpellResist);
        return ;
    end

    local aTalentActions = nodeShape.getChild("actions").getChildren();

    local aKeys = { };
    for k in pairs(aTalentActions) do
        table.insert(aKeys, k);
    end
    table.sort(aKeys);

    for _, k in ipairs(aKeys) do
        local nodeNewAction = copyActionToCast(nodeCastActionsList, aTalentActions[k]);
        if bIgnoreSpellResist and DB.getValue(nodeNewAction, "type") == "cast" then
            DB.setValue(nodeNewAction, "srnotallowed", "number", 1);
        end
    end
end

function addTypeToCast(nodeCastActionsList, nodeType, bFullPower)
    if not nodeType then
        addBasicDamageAction(nodeCastActionsList);
        return ;
    end

    local aTalentActions = nodeType.getChild("actions").getChildren();

    local aKeys = { };
    for k in pairs(aTalentActions) do
        table.insert(aKeys, k);
    end
    table.sort(aKeys);

    for _, k in ipairs(aKeys) do
        local nodeNewAction = copyActionToCast(nodeCastActionsList, aTalentActions[k]);
        if bFullPower and DB.getValue(nodeNewAction, "type") == "damage" then
            for _, dmgEntry in pairs(nodeNewAction.getChild("damagelist").getChildren()) do
                if DB.getValue(dmgEntry, "dicestat") == "oddcl" then
                    DB.setValue(dmgEntry, "dicestat", "string", "cl");
                end
            end
        end
    end
end

function addTalentToCast(nodeCastActionsList, nodeTalent)
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

function addBasicCastAction(nodeCastActionsList, bIgnoreSpellResist)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "cast");
    DB.setValue(nodeNewAction, "atktype", "string", "rtouch");
    if bIgnoreSpellResist then
        DB.setValue(nodeNewAction, "srnotallowed", "number", 1);
    end
end

function addBasicDamageAction(nodeCastActionsList)
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.setValue(nodeNewAction, "type", "string", "damage");

    local nodeDmgList = nodeNewAction.createChild("damagelist");
    local nodeDmgEntry = nodeDmgList.createChild();
    DB.setValue(nodeDmgEntry, "dice", "dice", { "d6" });
    DB.setValue(nodeDmgEntry, "dicestat", "string", "oddcl");
    DB.setValue(nodeDmgEntry, "type", "string", "bludgeoning");
end

function copyActionToCast(nodeCastActionsList, nodeAction)
    --todo remove detailbutton from action when copied over
    local nodeNewAction = nodeCastActionsList.createChild();
    DB.copyNode(nodeAction, nodeNewAction);
    return nodeNewAction;
end

function getSpellResistPropertyFromType(nodeType)
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

function updateAllActionValues()
    Debug.chat("updateviews")
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