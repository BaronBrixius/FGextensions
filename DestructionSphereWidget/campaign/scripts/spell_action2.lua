--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

local m_sType = nil;
local oldOnSpellAction;

function onInit()
    local sNode = getDatabaseNode().getNodeName();
    DB.addHandler(sNode, "onChildAdded", onDataChanged);
    DB.addHandler(sNode, "onChildUpdate", onDataChanged);
    onDataChanged();

    oldOnSpellAction = SpellManager.onSpellAction;
    SpellManager.onSpellAction = onSpellAction;

    SpellManager.getActionMod = getActionMod;
end

function test()
    Debug.chat("here")
end

function onSpellAction(draginfo, nodeAction, sSubRoll)
    --Debug.chat(nodeAction)

    if string.find(nodeAction.getPath(), "destruction", 1, 1) and not string.find(nodeAction.getPath(), "One.Two.Three.Four", 1, 1) then
        nodeAction = nodeAction.createChild("One")
                .createChild("Two")
                .createChild("Three")
                .createChild("Four");
    end

    Debug.chat(ActorManager.getActor("", nodeAction.getChild(".........")))
    oldOnSpellAction(draginfo, nodeAction, sSubRoll);


    --if not nodeAction then
    --    return;
    --end
    --
    --Debug.chat(ActorManager.getActor("", nodeAction.getChild(".......")));
    --local rActor = ActorManager.getActor("", nodeAction.getChild("........."));
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


function getActionMod(rActor, nodeAction, sStat, nStatMax)
    local nStat;

    if sStat == "" then
        nStat = 0;
    elseif sStat == "cl" or sStat == "halfcl" or sStat == "oddcl" then
        nStat = DB.getValue(nodeAction, ".......cl", 0);
        if sStat == "halfcl" then
            nStat = math.floor((nStat + 0.5) / 2);
        elseif sStat == "oddcl" then
            nStat = math.floor((nStat + 1.5) / 2);
        end
    else
        nStat = ActorManager2.getAbilityBonus(rActor, sStat);
    end

    if nStat > 0 and nStatMax and nStatMax > 0 then
        nStat = math.max(math.min(nStat, nStatMax), 0);
    end

    return nStat;
end

function onClose()
    local sNode = getDatabaseNode().getNodeName();
    DB.removeHandler(sNode, "onChildAdded", onDataChanged);
    DB.removeHandler(sNode, "onChildUpdate", onDataChanged);
end

function onMenuSelection(selection, subselection)
    if selection == 4 and subselection == 3 then
        getDatabaseNode().delete();
    end
end

local bDataChangedLock = false;
function onDataChanged()
    if bDataChangedLock then
        return;
    end
    bDataChangedLock = true;
    if not m_sType then
        local sType = DB.getValue(getDatabaseNode(), "type");
        if (sType or "") ~= "" then
            createDisplay(sType);
            m_sType = sType;
        end
    end
    if m_sType then
        updateViews();
    end
    bDataChangedLock = false;
end

function highlight(bState)
    if bState then
        setFrame("rowshade");
    else
        setFrame(nil);
    end
end

function createDisplay(sType)
    if sType == "cast" then
        createAttack();
        createLevelCheck();
        createSave();
    elseif sType == "damage" then
        createDamage();
    elseif sType == "heal" then
        createHeal();
    elseif sType == "effect" then
        createEffect();
    end
end

function createAttack()
    createControl("destruction_action_attackbutton", "attackbutton");
    createControl("destruction_action_attackviewlabel", "attackviewlabel");
    createControl("destruction_action_attackview", "attackview");
end

function createLevelCheck()
    createControl("destruction_action_levelcheckbutton", "levelcheckbutton");
    createControl("destruction_action_levelcheckviewlabel", "levelcheckviewlabel");
    createControl("destruction_action_levelcheckview", "levelcheckview");
end

function createSave()
    createControl("destruction_action_savebutton", "savebutton");
    createControl("destruction_action_saveviewlabel", "saveviewlabel");
    createControl("destruction_action_saveview", "saveview");
end

function createDamage()
    createControl("spell_action_damagebutton", "damagebutton");
    createControl("spell_action_damagelabel", "damagelabel");
    createControl("spell_action_damageview", "damageview");
end

function createHeal()
    createControl("spell_action_healbutton", "healbutton");
    createControl("spell_action_heallabel", "heallabel");
    createControl("spell_action_healview", "healview");
    createControl("spell_action_healtypelabel", "healtypelabel");
    createControl("spell_action_healtype", "healtype");
end

function createEffect()
    createControl("spell_action_effectbutton", "effectbutton");
    createControl("spell_action_effecttargeting", "targeting");
    createControl("spell_action_effectapply", "apply");
    createControl("spell_action_effectlabel", "label");
    createControl("spell_action_effectdurationview", "durationview");
end

function updateViews()
    if m_sType == "cast" then
        onCastChanged();
    elseif m_sType == "damage" then
        onDamageChanged();
    elseif m_sType == "heal" then
        onHealChanged();
    elseif m_sType == "effect" then
        onEffectChanged();
    end
end

function onCastChanged()
    local node = getDatabaseNode();

    local sAttack = SpellManager.getActionAttackText(node);
    attackview.setValue(sAttack);

    local nCL = SpellManager.getActionCLC(node);
    levelcheckview.setValue("" .. nCL);

    local sSave = SpellManager.getActionSaveText(node);
    saveview.setValue(sSave);
end

function onDamageChanged()
    local sDamage = SpellManager.getActionDamageText(getDatabaseNode());
    damageview.setValue(sDamage);
end

function onHealChanged()
    local sHeal = SpellManager.getActionHealText(getDatabaseNode());
    healview.setValue(sHeal);
end

function onEffectChanged()
    local sDuration = SpellManager.getActionEffectDurationText(getDatabaseNode());
    durationview.setValue(sDuration);
end
