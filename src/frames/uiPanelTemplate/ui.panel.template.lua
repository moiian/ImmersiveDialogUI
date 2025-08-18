function ScrollFrameTemplate_OnMouseWheel(value, scrollBar)
    scrollBar = scrollBar or getglobal(this:GetName() .. "ScrollBar");
    if (value > 0) then
        scrollBar:SetValue(scrollBar:GetValue() - (scrollBar:GetHeight() / 2));
    else
        scrollBar:SetValue(scrollBar:GetValue() + (scrollBar:GetHeight() / 2));
    end
end

-- Scrollframe functions
function ScrollFrame_OnLoad()
    getglobal(this:GetName() .. "ScrollBarScrollDownButton"):Disable();
    getglobal(this:GetName() .. "ScrollBarScrollUpButton"):Disable();

    local scrollbar = getglobal(this:GetName() .. "ScrollBar");
    scrollbar:SetMinMaxValues(0, 0);
    scrollbar:SetValue(0);
    this.offset = 0;
	
end

function ScrollFrame_OnScrollRangeChanged(scrollrange)
    local scrollbar = getglobal(this:GetName() .. "ScrollBar");
    if (not scrollrange) then
        scrollrange = this:GetVerticalScrollRange();
    end
    local value = scrollbar:GetValue();
    if (value > scrollrange) then
        value = scrollrange;
    end
    scrollbar:SetMinMaxValues(0, scrollrange);
    scrollbar:SetValue(value);
    if (floor(scrollrange) == 0) then
        if (this.scrollBarHideable) then
            getglobal(this:GetName() .. "ScrollBar"):Hide();
            getglobal(scrollbar:GetName() .. "ScrollDownButton"):Hide();
            getglobal(scrollbar:GetName() .. "ScrollUpButton"):Hide();
        else
            getglobal(scrollbar:GetName() .. "ScrollDownButton"):Disable();
            getglobal(scrollbar:GetName() .. "ScrollUpButton"):Disable();
            getglobal(scrollbar:GetName() .. "ScrollDownButton"):Show();
            getglobal(scrollbar:GetName() .. "ScrollUpButton"):Show();
        end
        getglobal(scrollbar:GetName() .. "ThumbTexture"):Hide();
    else
        getglobal(scrollbar:GetName() .. "ScrollDownButton"):Show();
        getglobal(scrollbar:GetName() .. "ScrollUpButton"):Show();
        getglobal(this:GetName() .. "ScrollBar"):Show();
        getglobal(scrollbar:GetName() .. "ScrollDownButton"):Enable();
        getglobal(scrollbar:GetName() .. "ThumbTexture"):Show();
    end

    -- Hide/show scrollframe borders
    local top = getglobal(this:GetName() .. "Top");
    local bottom = getglobal(this:GetName() .. "Bottom");
    local middle = getglobal(this:GetName() .. "Middle");
    if (top and bottom and this.scrollBarHideable) then
        if (this:GetVerticalScrollRange() == 0) then
            top:Hide();
            bottom:Hide();
        else
            top:Show();
            bottom:Show();
        end
    end
    if (middle and this.scrollBarHideable) then
        if (this:GetVerticalScrollRange() == 0) then
            middle:Hide();
        else
            middle:Show();
        end
    end
end

function ScrollingEdit_OnTextChanged(scrollFrame)
    if (not scrollFrame) then
        scrollFrame = this:GetParent();
    end
end

function ScrollingEdit_OnCursorChanged(x, y, w, h)
    this.cursorOffset = y;
    this.cursorHeight = h;
end
