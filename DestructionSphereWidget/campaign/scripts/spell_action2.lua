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

    --oldOnSpellAction = SpellManager.onSpellAction;
    --SpellManager.onSpellAction = onSpellAction;

    SpellManager.getActionMod = getActionMod;
end

function test()
    Debug.chat("here")
end

function onSpellAction(draginfo, nodeAction, sSubRoll)
    --Debug.chat(nodeAction)

    --if not string.find(nodeAction.getPath(), "destruction", 1, 1) then
        oldOnSpellAction(draginfo, nodeAction, sSubRoll);
        --return;
    --end


--    if not nodeAction then
--        return;
--    end
--
--    local rActor = ActorManager.getActor("", nodeAction.getChild("....."));
--    if not rActor then
--        return;
--    end
--
--    local rAction = getSpellAction(rActor, nodeAction, sSubRoll);
--Debug.chat(rAction)
--    local rRolls = {};
--    local rCustom = nil;
--    if rAction.type == "cast" then
--        if not rAction.subtype then
--            table.insert(rRolls, ActionSpell.getSpellCastRoll(rActor, rAction));
--        end
--
--        if not rAction.subtype or rAction.subtype == "atk" then
--            if rAction.range then
--                table.insert(rRolls, ActionAttack.getRoll(rActor, rAction));
--            end
--        end
--
--        if not rAction.subtype or rAction.subtype == "clc" then
--            local rRoll = ActionSpell.getCLCRoll(rActor, rAction);
--            if not rAction.subtype then
--                rRoll.sType = "castclc";
--                rRoll.aDice = {};
--            end
--            table.insert(rRolls, rRoll);
--        end
--
--        if not rAction.subtype or rAction.subtype == "save" then
--            if rAction.save and rAction.save ~= "" then
--                local rRoll = ActionSpell.getSaveVsRoll(rActor, rAction);
--                if not rAction.subtype then
--                    rRoll.sType = "castsave";
--                end
--                table.insert(rRolls, rRoll);
--            end
--        end
--
--    elseif rAction.type == "damage" then
--        local rRoll = ActionDamage.getRoll(rActor, rAction);
--        if rAction.bSpellDamage then
--            rRoll.sType = "spdamage";
--        else
--            rRoll.sType = "damage";
--        end
--
--        table.insert(rRolls, rRoll);
--
--    elseif rAction.type == "heal" then
--        table.insert(rRolls, ActionHeal.getRoll(rActor, rAction));
--
--    elseif rAction.type == "effect" then
--        local rRoll;
--        rRoll = ActionEffect.getRoll(draginfo, rActor, rAction);
--        if rRoll then
--            table.insert(rRolls, rRoll);
--        end
--    end
--
--    if #rRolls > 0 then
--        ActionsManager.performMultiAction(draginfo, rActor, rRolls[1].sType, rRolls);
--    end
--end
--
--function getSpellAction(rActor, nodeAction, sSubRoll)
--    if not nodeAction then
--        return;
--    end
--
--    local sType = DB.getValue(nodeAction, "type", "");
--
--    local rAction = {};
--    rAction.type = sType;
--    rAction.label = DB.getValue(nodeAction, "...name", "");
--    rAction.order = SpellManager.getSpellActionOutputOrder(nodeAction);
--
--    if sType == "cast" then
--        rAction.subtype = sSubRoll;
--        rAction.onmissdamage = DB.getValue(nodeAction, "onmissdamage", "");
--
--        local sAttackType = DB.getValue(nodeAction, "atktype", "");
--        if sAttackType ~= "" then
--            if sAttackType == "mtouch" then
--                rAction.range = "M";
--                rAction.touch = true;
--            elseif sAttackType == "rtouch" then
--                rAction.range = "R";
--                rAction.touch = true;
--            elseif sAttackType == "ranged" then
--                rAction.range = "R";
--            elseif sAttackType == "cm" then
--                rAction.range = "M";
--                rAction.cm = true;
--            else
--                rAction.range = "M";
--            end
--
--            if rAction.cm then
--                rAction.modifier = ActorManager2.getAbilityScore(rActor, "cmb") + DB.getValue(nodeAction, "atkmod", 0);
--            else
--                rAction.modifier = ActorManager2.getAbilityScore(rActor, "bab") + DB.getValue(nodeAction, "atkmod", 0);
--            end
--            rAction.modifier = DB.getValue(nodeAction, "atkmod", 0);
--            rAction.crit = 20;
--
--            local sType, nodeActor = ActorManager.getTypeAndNode(rActor);
--            if sType == "pc" then
--                if rAction.range == "R" then
--                    rAction.stat = DB.getValue(nodeActor, "attackbonus.ranged.ability", "");
--                    if rAction.stat == "" then
--                        rAction.stat = "dexterity";
--                    end
--                    if sType == "pc" then
--                        rAction.modifier = rAction.modifier + DB.getValue(nodeActor, "attackbonus.ranged.size", 0) + DB.getValue(nodeActor, "attackbonus.ranged.misc", 0);
--                    end
--                else
--                    if rAction.cm then
--                        rAction.stat = DB.getValue(nodeActor, "attackbonus.grapple.ability", "");
--                        if rAction.stat == "" then
--                            rAction.stat = "strength";
--                        end
--                        if sType == "pc" then
--                            rAction.modifier = rAction.modifier + DB.getValue(nodeActor, "attackbonus.grapple.size", 0) + DB.getValue(nodeActor, "attackbonus.grapple.misc", 0);
--                        end
--                    else
--                        rAction.stat = DB.getValue(nodeActor, "attackbonus.melee.ability", "");
--                        if rAction.stat == "" then
--                            rAction.stat = "strength";
--                        end
--                        rAction.modifier = rAction.modifier + DB.getValue(nodeActor, "attackbonus.melee.size", 0) + DB.getValue(nodeActor, "attackbonus.melee.misc", 0);
--                    end
--                end
--                rAction.modifier = rAction.modifier + ActorManager2.getAbilityScore(rActor, "bab") + ActorManager2.getAbilityBonus(rActor, rAction.stat);
--            else
--                if rAction.range == "R" then
--                    rAction.stat = "dexterity";
--                else
--                    rAction.stat = "strength";
--                end
--                if rAction.cm then
--                    rAction.modifier = rAction.modifier + ActorManager2.getAbilityScore(rActor, "cmb");
--                else
--                    rAction.modifier = rAction.modifier + ActorManager2.getAbilityScore(rActor, "bab") + ActorManager2.getAbilityBonus(rActor, rAction.stat);
--                end
--            end
--        end
--
--        rAction.clc = SpellManager.getActionCLC(nodeAction);
--        rAction.sr = "yes";
--
--        if (DB.getValue(nodeAction, "srnotallowed", 0) == 1) then
--            rAction.sr = "no";
--        end
--
--        rAction.dcstat = DB.getValue(nodeAction, ".......dc.ability", "");
--
--        local sSaveType = DB.getValue(nodeAction, "savetype", "");
--        if sSaveType ~= "" then
--            rAction.save = sSaveType;
--            rAction.savemod = SpellManager.getActionSaveDC(nodeAction);
--        else
--            rAction.save = "";
--            rAction.savemod = 0;
--        end
--
--    elseif sType == "damage" then
--        rAction.clauses = SpellManager.getActionDamage(rActor, nodeAction);
--
--        rAction.meta = DB.getValue(nodeAction, "meta", "");
--
--        rAction.bSpellDamage = (DB.getValue(nodeAction, "dmgnotspell", 0) == 0);
--        if rAction.bSpellDamage then
--            for _,vClause in ipairs(rAction.clauses) do
--                if not vClause.dmgtype or vClause.dmgtype == "" then
--                    vClause.dmgtype = "spell";
--                else
--                    vClause.dmgtype = vClause.dmgtype .. ",spell";
--                end
--            end
--        end
--
--    elseif sType == "heal" then
--        rAction.clauses = SpellManager.getActionHeal(rActor, nodeAction);
--
--        rAction.subtype = DB.getValue(nodeAction, "healtype", "");
--        rAction.meta = DB.getValue(nodeAction, "meta", "");
--
--    elseif sType == "effect" then
--        local nodeSpellClass = DB.getChild(nodeAction, ".......");
--        rAction.sName = EffectManager35E.evalEffect(rActor, DB.getValue(nodeAction, "label", ""), nodeSpellClass);
--
--        rAction.sApply = DB.getValue(nodeAction, "apply", "");
--        rAction.sTargeting = DB.getValue(nodeAction, "targeting", "");
--
--        rAction.aDice, rAction.nDuration = SpellManager.getActionEffectDuration(rActor, nodeAction);
--
--        rAction.sUnits = DB.getValue(nodeAction, "durunit", "");
--    end
--
--    return rAction;
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
        createCast();

    elseif sType == "damage" then
        createDamage();
    elseif sType == "heal" then
        createHeal();
    elseif sType == "effect" then
        createEffect();
    end
end

function createCast()
    createControl("spell_action_attackbutton", "attackbutton");
    createControl("spell_action_attackviewlabel", "attackviewlabel");
    createControl("spell_action_attackview", "attackview");
    createControl("spell_action_levelcheckbutton", "levelcheckbutton");
    createControl("spell_action_levelcheckviewlabel", "levelcheckviewlabel");
    createControl("spell_action_levelcheckview", "levelcheckview");
    createControl("spell_action_savebutton", "savebutton");
    createControl("spell_action_saveviewlabel", "saveviewlabel");
    createControl("spell_action_saveview", "saveview");
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
