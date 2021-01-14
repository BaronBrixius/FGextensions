-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	local node = getDatabaseNode();
	if not node then
		return;
	end

	--Debug.chat(DB.getChildren(getDatabaseNode().getParent()))

	--registerMenuItem(Interface.getString("menu_addspell"), "insert", 5);
end

function update(bEditMode)
	if minisheet then
		return;
	end
	
	spells_iadd.setVisible(bEditMode);
	for _,w in ipairs(spells.getWindows()) do
		w.update(bEditMode);
	end
end

function onSpellCounterUpdate()
	--		DB.setValue(nodeSpellClass, "pointsused", "number", 0);
	windowlist.window.onSpellCounterUpdate();
end

function onMenuSelection(selection, subselection)
	if selection == 5 then
		spells.addEntry(true);
	end
end

function onClickDown(button, x, y)
	return true;
end

function onClickRelease(button, x, y)
	if DB.getChildCount(spells.getDatabaseNode(), "") == 0 then
		spells.addEntry(true);
		return true;
	end

	spells.setVisible(not spells.isVisible());
	return true;
end
