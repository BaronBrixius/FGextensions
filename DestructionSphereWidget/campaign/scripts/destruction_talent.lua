function onInit()
    if not windowlist.isReadOnly() then
        registerMenuItem(Interface.getString("menu_deletespell"), "delete", 6);
        registerMenuItem(Interface.getString("list_menu_deleteconfirm"), "delete", 6, 7);

        registerMenuItem(Interface.getString("menu_addspellaction"), "pointer", 3);
        registerMenuItem(Interface.getString("menu_addspellcast"), "radial_sword", 3, 2);
        registerMenuItem(Interface.getString("menu_addspelldamage"), "radial_damage", 3, 3);
        registerMenuItem(Interface.getString("menu_addspellheal"), "radial_heal", 3, 4);
        registerMenuItem(Interface.getString("menu_addspelleffect"), "radial_effect", 3, 5);
    end
end

function toggleDetail()
    local status = (activatedetail.getValue() == 1);
    actions.setVisible(status);
end

function onMenuSelection(selection, subselection)
    if selection == 6 and subselection == 7 then
        getDatabaseNode().delete();
    elseif selection == 3 then
        local nodeNewAction = getDatabaseNode().createChild("actions").createChild();
        if subselection == 2 then
            setUpNewCast(nodeNewAction);
        elseif subselection == 3 then
            setUpNewDamage(nodeNewAction);
        elseif subselection == 4 then
            setUpNewHeal(nodeNewAction);
        elseif subselection == 5 then
            setUpNewEffect(nodeNewAction);
        end
        activatedetail.setValue(1);
    end
end

function setUpNewCast(nodeAction)
    DB.setValue(nodeAction, "type", "string", "cast");
    DB.setValue(nodeAction, "savedctype", "string", "casterlevel");
    DB.setValue(nodeAction, "srnotallowed", "number", 1);
end

function setUpNewDamage(nodeAction)
    DB.setValue(nodeAction, "type", "string", "damage");

    local nodeDmgEntry = nodeAction.createChild("damagelist").createChild();
    DB.setValue(nodeDmgEntry, "dicestat", "string", "oddcl");
end

function setUpNewHeal(nodeAction)
    DB.setValue(nodeAction, "type", "string", "heal");
end

function setUpNewEffect(nodeAction)
    DB.setValue(nodeAction, "type", "string", "effect");
end