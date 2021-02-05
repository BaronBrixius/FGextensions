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
    local nSelected = DB.getValue(getDatabaseNode(), ".selected");
    local castWindow = self.windowlist.window.cast_window.subwindow;
    local sCategory = getDatabaseNode().getPath():match("%.destruction_([^%.]+)");

    if selection == 6 and subselection == 7 then
        if nSelected == 1 then
            if sCategory == "shapes" then
                castWindow.clearShapeSelection();
            elseif sCategory == "types" then
                castWindow.clearTypeSelection();
            elseif sCategory == "other" then
                castWindow.clearOtherSelection(getDatabaseNode().getNodeName());
            end
        end
        getDatabaseNode().delete();
    elseif selection == 3 then
        setCastDataChangedLock(true);
        local nodeNewAction = getDatabaseNode().createChild("actions").createChild();
        DB.setValue(nodeNewAction, "talenttype", "string", sCategory);
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

        setCastDataChangedLock(false);

        if not nSelected == 1 then
            return;
        end

        if sCategory == "shapes" then
            castWindow.resetShapeActions();
        elseif sCategory == "types" then
            castWindow.resetTypeActions();
        elseif sCategory == "other" then
            castWindow.resetOtherActions();
        end
    end
end

function setCastDataChangedLock(bDataChangedLock)
    self.windowlist.window.cast_window.subwindow.setDataChangedLock(bDataChangedLock);
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