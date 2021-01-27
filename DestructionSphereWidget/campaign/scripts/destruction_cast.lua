function onInit()
    DB.addHandler(DB.getPath(getDatabaseNode().getChild("destruction_shapes")), 'onChildUpdate', updateCastActionList);
    DB.addHandler(DB.getPath(getDatabaseNode().getChild("destruction_types")), 'onChildUpdate', updateCastActionList);
    DB.addHandler(DB.getPath(getDatabaseNode().getChild("...abilities")), 'onChildUpdate', updateAllActionValues);
    DB.addHandler(DB.getPath(getDatabaseNode().getChild(".dc.total")), 'onUpdate', updateAllActionValues);

    doWithLock(updateDisplay)
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

    setAsCostSource(rNewTalent.getDatabaseNode(), sCategory);
    updateCastDisplay();
end

function setAsCostSource(nodeShape, sCategory)
    for k, v in pairs(self.cost.sources) do
        if (string.match(k, sCategory, 1, 1)) then
            v = nil;
            self.cost.ops[k] = nil;
        end
    end

    self.cost.addSourceWithOp(string.match(DB.getPath(nodeShape, "cost"), "destruction.*"), "+");
end

function clearOtherShapes(rSelectedShape)
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
        if DB.getValue(v, ".selected", "number", 0) == 1 then
            return v;
        end
    end
    return nil;
end

function updateDisplay()
    setAsCostSource(getTalent("shapes"), "shapes");
    setAsCostSource(getTalent("types"), "types");
    updateCastDisplay();
end

function updateCastDisplay()
    self.cost.sourceUpdate();
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

function updateCastActionList()
    local nodeSpell = getDatabaseNode();
    local nodeActions = nodeSpell.createChild("level.level0.spell.spell0.destruction_actions");

    DB.deleteChildren(nodeActions)

    addMainCastAction(nodeActions, getTalent("shapes"));
    addMainDamageAction(nodeActions, getTalent("types"));
end

function addMainCastAction(nodeActions, nodeShape)
    local nodeNewMainCast = nodeActions.createChild("main_cast");
    if not nodeNewMainCast then
        return nil;
    end

    local nodeShapeCast = { 9999 };

    for _, v in pairs(nodeShape.getChild("spells.spell0.actions").getChildren()) do
        if DB.getValue(v, "type", "") == "cast" then
            local nOrder = DB.getValue(v, "order", 0);
            if nOrder < nodeShapeCast[1] then
                nodeShapeCast[1] = nOrder;
                nodeShapeCast[2] = v;
            end
        end
    end

    if (nodeShapeCast[2]) then
        DB.copyNode(nodeShapeCast[2], nodeNewMainCast)
        DB.setValue(nodeNewMainCast, "order", "number", 1);
    else
        Debug.console("Error: No cast action in Shape.");
    end
end

function addMainDamageAction(nodeActions, nodeType)
    local nodeNewMainDamage = nodeActions.createChild("main_damage");
    if not nodeNewMainDamage then
        return nil;
    end

    local nodeTypeDamage = { 9999 };

    for _, v in pairs(nodeType.getChild("spells.spell0.actions").getChildren()) do
        if DB.getValue(v, "type", "") == "damage" then
            local nOrder = DB.getValue(v, "order", 0);
            if nOrder < nodeTypeDamage[1] then
                nodeTypeDamage[1] = nOrder;
                nodeTypeDamage[2] = v;
            end
        end
    end

    if (nodeTypeDamage[2]) then
        DB.copyNode(nodeTypeDamage[2], nodeNewMainDamage)
        DB.setValue(nodeNewMainDamage, "order", "number", 2);
    else
        Debug.console("Error: No damage action in Type.");
    end
end

function activatePower()
    local nodeSpell = getDatabaseNode();
    if nodeSpell then
        ChatManager.Message(getDescription(), true, ActorManager.getActor("", nodeSpell.getChild(".....")));
    end
end

function onSpellAction(draginfo, nodeAction, sSubRoll)
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
    Debug.chat('spellcounterupdate')
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