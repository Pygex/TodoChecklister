--------------------------------------
-- Namespaces
--------------------------------------
local _, core = ...
core.TodoChecklisterFrame = {} -- adds Config table to addon namespace
local TodoChecklisterFrame = core.TodoChecklisterFrame

local ResponsiveFrame = core.ResponsiveFrame
local TableUtils = core.TableUtils
local TodoList = core.TodoList

--------------------------------------
-- TodoChecklisterFrame functions
--------------------------------------
function TodoChecklisterFrame:AddItem(text)
	if (text ~= "" and text ~= nil and text) then
		-- If the item is not selected
		if (self.selectedItem == nil or self.selectedItem == 0) then
			TodoList:AddItem(text)
		else
			TodoList:UpdateItem(self.selectedItem, {text = text})
		end
		self:ClearSelected()
		self:OnUpdate()
	end
end

function TodoChecklisterFrame:RemoveItem(todoItem)
	local indexToRemove = TodoList:GetIndexByItem(todoItem)

	if (indexToRemove > 0) then
		-- If we are removing the current selected item
		if (self.selectedItem and self.selectedItem == indexToRemove) then
			-- Clear selection before removing it
			self:ClearSelected()
		end

		local selectedItem
		-- If we have something selected, we have to re-find its index after deletion
		if (self.selectedItem and self.selectedItem > 0) then
			-- So we store the current text
			selectedItem = TodoList:GetItems()[self.selectedItem]
		end

		TodoList:RemoveItem(indexToRemove)

		if (selectedItem ~= nil) then
			local indexToSelect = TodoList:GetIndexByItem(selectedItem)
			self.selectedItem = indexToSelect
		end

		self:OnUpdate()
	end
end

function TodoChecklisterFrame:CheckItem(todoItem)
	local indexToCheck = TodoList:GetIndexByItem(todoItem)
	if (indexToCheck > 0) then
		local item = TodoList:GetItems()[indexToCheck]
		TodoList:UpdateItem(indexToCheck, {isChecked = (not item.isChecked)})
		self:OnUpdate()
	end
end

function TodoChecklisterFrame:SelectItem(todoItem, buttonFrame)
	local indexToSelect = TodoList:GetIndexByItem(todoItem)

	-- If index is different = select a new item
	if (indexToSelect ~= self.selectedItem) then
		self.selectedItem = indexToSelect
		self.frame.TodoText:SetText(TodoList:GetItems()[self.selectedItem].text)
	else
		-- If index is the same = deselect the item
		self:ClearSelected()
	end

	self:OnUpdate()
end

function TodoChecklisterFrame:ClearSelected()
	self.selectedItem = 0
	self.frame.TodoText:SetText("")
	self.frame.TodoText:ClearFocus()
end

function TodoChecklisterFrame:Toggle()
	if (self.frame:IsShown()) then
		self.frame:Hide()
	else
		self.frame:Show()
	end
end

function TodoChecklisterFrame:GetColor(todoItem)
	local highlightColor = NORMAL_FONT_COLOR

	if (todoItem.isChecked) then
		highlightColor = DISABLED_FONT_COLOR
	end

	return highlightColor
end

function TodoChecklisterFrame:PaintItem(frame, todoItem, index)
	index = index or 0

	frame.todoItem = todoItem
	-- Update button values
	if (todoItem.isChecked) then
		frame.TodoContent.FontText:SetFontObject(GameFontDarkGraySmall)
	else
		frame.TodoContent.FontText:SetFontObject(GameFontNormalSmall)
	end
	frame.TodoContent:SetWidth(TodoItemsScrollFrame:GetWidth() - frame.RemoveButton:GetWidth() - 23)
	frame.TodoContent.FontText:SetText(todoItem.text)

	if (self.selectedItem == index) then
		local highlightColor = self:GetColor(todoItem)

		frame.TodoContent.ButtonHighlightFrame.ButtonHighlightTexture:SetVertexColor(
			highlightColor.r,
			highlightColor.g,
			highlightColor.b
		)
		frame.TodoContent.ButtonHighlightFrame:Show()
	else
		frame.TodoContent.ButtonHighlightFrame:Hide()
	end

	-- Update checkbox values
	frame.TodoCheckButton:SetChecked(todoItem.isChecked)
end

function TodoChecklisterFrame:FloatingButton(parent)
	-- Create an initial offset based on where the mouse is
	local cx = GetCursorPosition()
	local xOffset = cx / self.frame:GetEffectiveScale() - (parent:GetLeft())

	-- Create or reuse a frame
	local floatingFrame = self.floatingFrame or CreateFrame("Frame", "TODODragButton", UIParent, "TodoItemTemplate")

	floatingFrame.todoItem = parent:GetParent().todoItem
	-- Fill the frame's values
	self:PaintItem(floatingFrame, floatingFrame.todoItem)

	-- When moving
	floatingFrame:SetScript(
		"OnUpdate",
		function(frame)
			-- Make the clone follow the mouse
			parent:GetParent().BottomDropIndicator:Hide()
			if frame.isMoving then
				local cx, cy = GetCursorPosition()
				local x, y = cx / self.frame:GetEffectiveScale(), cy / self.frame:GetEffectiveScale()
				frame:ClearAllPoints()
				frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - xOffset + 30, y - 25)
			end
		end
	)

	floatingFrame:SetScale(self.frame:GetScale())
	floatingFrame:SetMovable(true)
	floatingFrame:SetToplevel(true)
	floatingFrame:SetFrameStrata("TOOLTIP")
	floatingFrame.Background:Show()
	return floatingFrame
end

function TodoChecklisterFrame:Move(fromIndex, toIndex)
	local selectedItem
	if (self.selectedItem and self.selectedItem > 0) then
		selectedItem = TodoList:GetItems()[self.selectedItem]
	end

	if (fromIndex < toIndex) then
		toIndex = toIndex - 1
	end

	TodoList:Move(fromIndex, toIndex)

	if (selectedItem) then
		self.selectedItem = TodoList:GetIndexByItem(selectedItem)
	end

	self:OnUpdate()
end

--------------------------------------
-- TodoChecklisterFrame Events
--------------------------------------
function TodoChecklisterFrame:OnUpdate()
	local scrollFrame = TodoItemsScrollFrame
	local list = TodoList:GetItems()
	if (scrollFrame and scrollFrame.buttons and list) then
		local offset = HybridScrollFrame_GetOffset(scrollFrame)

		if (#list > 0) then
			self.frame.Background.BlankText:SetText("")
		else
			self.frame.Background.BlankText:SetText(
				"You have no items on your list \r\n\r\n Start by typing them in the box above \r\n\r\n =)"
			)
		end

		for i = 1, #scrollFrame.buttons do
			local idx = i + offset
			local button = scrollFrame.buttons[i]

			if (idx <= #list) then
				local todoItem = list[idx]
				self:PaintItem(button, todoItem, idx)

				-- Setup drag
				button.TodoContent:RegisterForDrag("LeftButton")
				button.TodoContent:SetScript(
					"OnDragStart",
					function(todoContent)
						-- Clone the original button as a floating window
						self.floatingFrame = self:FloatingButton(todoContent)

						-- Display the window and drag it with the mouse
						self.floatingFrame:Show()
						self.floatingFrame.isMoving = true
						self.floatingFrame:StartMoving()

						-- Show that this item is being moved
						button.isMoving = true
						-- todoContent.ButtonHighlightFrame:Show()
					end
				)

				button.TodoContent:SetScript(
					"OnDragStop",
					function(todoContent)
						-- Hide that this item is being moved
						button.isMoving = false
						-- todoContent.ButtonHighlightFrame:Hide()

						-- Hide the floating window
						self.floatingFrame.isMoving = false
						self.floatingFrame:StopMovingOrSizing()
						self.floatingFrame:Hide()

						-- Resets fake animation
						todoContent.FontText:ClearAllPoints()
						todoContent.FontText:SetPoint("LEFT", todoContent, "LEFT", 0, 0)

						if (self.floatingFrame.targetIndex and self.floatingFrame.targetIndex > 0) then
							button.BottomDropIndicator:Hide()
							button.TopDropIndicator:Hide()

							local moveIndex = TodoList:GetIndexByItem(self.floatingFrame.todoItem)
							self:Move(moveIndex, self.floatingFrame.targetIndex)
						end

						self.floatingFrame.targetIndex = 0
						self.floatingFrame.todoItem = nil
					end
				)

				local highlightColor = self:GetColor(todoItem)
				button.TodoContent:SetScript(
					"OnUpdate",
					function(todoContent)
						if (self.selectedItem ~= idx) then
							todoContent.ButtonHighlightFrame:Hide()
						end

						-- If dragging
						if (self.floatingFrame and self.floatingFrame.isMoving) then
							button.BottomDropIndicator:Hide()
							button.TopDropIndicator:Hide()

							-- Every item have highlight on the top
							local topOffset = 10
							if (idx == 1) then
								topOffset = 800
							end
							if (todoContent:IsMouseOver(topOffset)) then
								self.floatingFrame.targetIndex = idx
								-- Highlight where dragged item will be dropped
								button.TopDropIndicator:Show()
							end

							if (idx == #list and todoContent:IsMouseOver(0, -800)) then
								self.floatingFrame.targetIndex = idx + 1
								button.BottomDropIndicator:Show()
							end
						else
							button.BottomDropIndicator:Hide()
							button.TopDropIndicator:Hide()
							-- If not dragging but hovering
							if (todoContent:IsMouseOver(5, 5)) then
								-- Display hover effect
								todoContent.ButtonHighlightFrame.ButtonHighlightTexture:SetVertexColor(
									highlightColor.r,
									highlightColor.g,
									highlightColor.b
								)
								todoContent.ButtonHighlightFrame:Show()
							end
						end
					end
				)

				button:Show()
			else
				button:Hide()
			end
		end

		HybridScrollFrame_Update(scrollFrame, (scrollFrame.buttons[1]:GetHeight()) * #list, scrollFrame:GetHeight())
	end
end

function TodoChecklisterFrame:OnLoad(frame)
	self.frame = frame
	-- Parent's OnLoad Function
	ResponsiveFrame:OnLoad(frame)

	-- Set up elements
	frame.Title:SetText(UnitName("player") .. "'s List")

	_G["TodoChecklisterClose"]:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
	_G["TodoChecklisterClose"]:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")

	local scrollFrame = frame.ScrollFrame
	scrollFrame.update = function()
		self:OnUpdate()
	end
	HybridScrollFrame_CreateButtons(frame.ScrollFrame, "TodoItemTemplate")

	-- Display the frame
	self:OnUpdate()
	self:Toggle()
end

function OnLoad(frame)
	TodoChecklisterFrame:OnLoad(frame)
end

function OnShow(frame)
	TodoChecklisterFrame:OnUpdate()
end

function OnSizeChanged(frame)
	frame.ScrollFrame:SetHeight(frame.Background:GetHeight())
	HybridScrollFrame_CreateButtons(frame.ScrollFrame, "TodoItemTemplate")
	TodoChecklisterFrame:OnUpdate()
end

function OnSaveItem(frame)
	local text = TodoChecklister.TodoText:GetText()
	if (not text) then
		text = ""
	end

	TodoChecklisterFrame:AddItem(text)
end

function OnRemoveItem(frame)
	--TODO: RECEIVE ENTIRE ITEM AND CHECK IF THERE'S ID. IF THERE'S NOT, USE TEXT
	TodoChecklisterFrame:RemoveItem(frame:GetParent().todoItem)
end

function OnCheckItem(frame)
	TodoChecklisterFrame:CheckItem(frame:GetParent().todoItem)
end

function OnSelectItem(frame)
	TodoChecklisterFrame:SelectItem(frame:GetParent().todoItem)
end
