function onInit()
    doWithLock(updateDisplay)
    --getDatabaseNode().getChild("cost").addSource(rShape.cost)
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

function setShape(rNewShape)
    doWithLock(clearOtherShapeSelections, rNewShape)
    setShapeAsDataSource(rNewShape.getDatabaseNode())
    updateCastDisplay();
    --Debug.chat(DB.getValue(rNewShape.getDatabaseNode(), "cost", 0))
    --Debug.chat(self.cost.sources)

    --for k,v in pairs(self.cost.sources) do
    --    Debug.chat(k,v)
    --end
end

function setShapeAsDataSource(nodeShape)
    for k,v in pairs(self.cost.sources) do
        if (string.match(k, "shapes", 1, 1)) then
            v = nil;
            self.cost.ops[k] = nil;
        end
    end

    self.cost.addSourceWithOp(string.match(DB.getPath(nodeShape, "cost"), "destruction.*"), "+");
end

function clearOtherShapeSelections(rSelectedShape)
    local rSelectedShapeNode = rSelectedShape.getDatabaseNode();
    for _, v in pairs(getDatabaseNode().getChild("destruction_shapes").getChildren()) do
        if v ~= rSelectedShapeNode then
            DB.setValue(v, ".selected", "number", 0);
        end
    end
end

function getShape()
    for _, v in pairs(getDatabaseNode().getChild("destruction_shapes").getChildren()) do
        if DB.getValue(v, ".selected", "number", 0) == 1 then
            return v;
        end
    end
    return nil;
end

function updateDisplay()
    setShapeAsDataSource(getShape());
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
    local nodeActions = nodeSpell.createChild("castactions");

    DB.deleteChildren(nodeActions)

    local nodeShape = getShape();

    addMainCastAction(nodeActions, nodeShape);
end

function addMainCastAction(nodeActions, nodeShape)
    local nodeNewAction = nodeActions.createChild("main_cast");
    if not nodeNewAction then
        return nil;
    end

    local nodeShapeActions = nodeShape.getChild("actions");
    for k,v in pairs(nodeShapeActions.getChildren()) do
        DB.copyNode(v, nodeNewAction)
    end

end

--function createAttack()
--    createControl("destruction_action_attackbutton", "attackbutton");
--    createControl("destruction_action_attackviewlabel", "attackviewlabel");
--    createControl("destruction_action_attackview", "attackview");
--end
--
--function createLevelCheck()
--    createControl("destruction_action_levelcheckbutton", "levelcheckbutton");
--    createControl("destruction_action_levelcheckviewlabel", "levelcheckviewlabel");
--    createControl("destruction_action_levelcheckview", "levelcheckview");
--end
--
--function createSave()
--    createControl("destruction_action_savebutton", "savebutton");
--    createControl("destruction_action_saveviewlabel", "saveviewlabel");
--    createControl("destruction_action_saveview", "saveview");
--end
--
--function createDamage()
--    createControl("destruction_action_damagebutton", "damagebutton");
--    createControl("destruction_action_damagelabel", "damagelabel");
--    createControl("destruction_action_damageview", "damageview");
--end

function activatePower()
    local nodeSpell = getDatabaseNode();
    if nodeSpell then
        ChatManager.Message(getDescription(), true, ActorManager.getActor("", nodeSpell.getChild(".....")));
    end
end

function onSpellAction(draginfo, nodeAction, sSubRoll)
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
    --            rRoll.sType = "castclc";
    --            rRoll.aDice = {};
    --        end
    --        table.insert(rRolls, rRoll);
    --    end
    --
    --    if not rAction.subtype or rAction.subtype == "save" then
    --        if rAction.save and rAction.save ~= "" then
    --            local rRoll = ActionSpell.getSaveVsRoll(rActor, rAction);
    --            if not rAction.subtype then
    --                rRoll.sType = "castsave";
    --            end
    --            table.insert(rRolls, rRoll);
    --        end
    --    end
    --
    --elseif rAction.type == "damage" then
    --    local rRoll = ActionDamage.getRoll(rActor, rAction);
    --    if rAction.bSpellDamage then
    --        rRoll.sType = "spdamage";
    --    else
    --        rRoll.sType = "damage";
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
    --    ActionsManager.performMultiAction(draginfo, rActor, rRolls[1].sType, rRolls);
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

