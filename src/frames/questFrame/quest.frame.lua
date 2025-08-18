---@diagnostic disable: undefined-global
MAX_NUM_QUESTS = 32;
MAX_NUM_ITEMS = 10;
MAX_REQUIRED_ITEMS = 6;
QUEST_DESCRIPTION_GRADIENT_LENGTH = 30;
QUEST_DESCRIPTION_GRADIENT_CPS = 40;
QUESTINFO_FADE_IN = 1;
local QUEST_TEXT_FADE_DURATION = 0.1;
local xOffsetOffset = 4.5 	--打字机文本的偏移量，汉字是3.1
local Text_Language = false
-- ===================================================================
-- ====== 新增：可配置按键变量 ======
-- ===================================================================
local KEY_YES = "E" -- 默认接受按键
local KEY_NO = "R"  -- 默认拒绝/返回按键

-- ===================================================================
-- ====== NEW: Layout Configuration & State ======
-- ===================================================================
local LayoutConfig = {
    TextBottomOffset = 35,
    TextWidthPct = 0.80,
    TitleBottomOffset = 100,
    RightColumnXOffset = -500,
    RightColumnYOffset = 0,
    RightColumnWidthPct = 0.15,
    AcceptButtonYOffset = 45,
    AncillaryInitialYOffset = -30,	---右侧栏的上下间隙
    AncillarySpacing = -20,
    ItemGridColumnSpacing = 50,
    ItemGridRowSpacing = -2,
	FontSize = 19
};

local function UpdateSettings()
    -- ImmersiveUIDB 是由 ImmersiveDialogUI.lua 创建的全局设置表
    if not ImmersiveUIDB then return end

    -- 更新 LayoutConfig 表
    LayoutConfig.TextBottomOffset = ImmersiveUIDB.TextBottomOffset or LayoutConfig.TextBottomOffset
    LayoutConfig.TextWidthPct = ImmersiveUIDB.TextWidthPct or LayoutConfig.TextWidthPct
    LayoutConfig.TitleBottomOffset = ImmersiveUIDB.TitleBottomOffset or LayoutConfig.TitleBottomOffset
    LayoutConfig.RightColumnXOffset = ImmersiveUIDB.RightColumnXOffset or LayoutConfig.RightColumnXOffset
    LayoutConfig.RightColumnYOffset = ImmersiveUIDB.RightColumnYOffset or LayoutConfig.RightColumnYOffset
    LayoutConfig.RightColumnWidthPct = ImmersiveUIDB.RightColumnWidthPct or LayoutConfig.RightColumnWidthPct
    LayoutConfig.AncillaryInitialYOffset = ImmersiveUIDB.AncillaryInitialYOffset or LayoutConfig.AncillaryInitialYOffset
    LayoutConfig.AncillarySpacing = ImmersiveUIDB.AncillarySpacing or LayoutConfig.AncillarySpacing
    LayoutConfig.ItemGridColumnSpacing = ImmersiveUIDB.ItemGridColumnSpacing or LayoutConfig.ItemGridColumnSpacing
    LayoutConfig.ItemGridRowSpacing = ImmersiveUIDB.ItemGridRowSpacing or LayoutConfig.ItemGridRowSpacing
    LayoutConfig.FontSize = ImmersiveUIDB.FontSize or LayoutConfig.FontSize

    -- 更新独立的变量
    -- 检查是否为 nil，因为 false 也是一个有效值
    if ImmersiveUIDB.TextLanguage ~= nil then
        Text_Language = ImmersiveUIDB.TextLanguage
    end
    -- 新增变量的同步
    xOffsetOffset = ImmersiveUIDB.xOffsetOffset or xOffsetOffset
    -- 注意滑块定义的 name 是 "FadeDuration"
    QUEST_TEXT_FADE_DURATION = ImmersiveUIDB.FadeDuration or QUEST_TEXT_FADE_DURATION
    
    -- 新增：同步按键设置
    KEY_YES = ImmersiveUIDB.KEY_YES or KEY_YES
    KEY_NO = ImmersiveUIDB.KEY_NO or KEY_NO
end

-- 為每個面板創建獨立的佈局應用標誌，確保佈局代碼只運行一次
local layoutApplied = {};

-- 状态变量
DQuestTextChunks, DRewardTextChunks, DGreetingTextChunks, DProgressTextChunks = {}, {}, {}, {};
DQuestCurrentChunkIndex, DRewardCurrentChunkIndex, DGreetingCurrentChunkIndex, DProgressCurrentChunkIndex = 1, 1, 1, 1;
DQuestTextFullyDisplayed, DRewardTextFullyDisplayed, DGreetingTextFullyDisplayed, DProgressTextFullyDisplayed = false, false, false, false;

local QUESTCOLORS = {
    DarkBrown = {1, 1, 1},
    LightBrown = {1, 1, 1},
    Ivory = {1, 1, 1},
	TitleBrown = {0.99,0.83,0.07}
};

--隐藏与记录函数
local HiddenFrames = {}
local function ShouldKeepFrame(name)
    return name and (
        string.find(name, "^DQuest") or
        string.find(name, "^DGossip") or
        string.find(name, "^DMoneyFrame") or
        string.find(name, "^DUI") or
        name == "QuestFrame"
    )
end
function HideAllFramesExceptDQuest()
    HiddenFrames = {}
	QuestFrameCloseButton:Hide()
    local children = { UIParent:GetChildren() }
    for _, frame in ipairs(children) do
        local name = frame:GetName()
        if frame:IsVisible() and not ShouldKeepFrame(name) then
            frame:Hide()
            table.insert(HiddenFrames, frame)
        end
    end
end

function RestoreHiddenFrames()
    for _, frame in ipairs(HiddenFrames) do
        if frame and frame.Show then
            frame:Show()
        end
    end
    for _, frame in ipairs(GossipHiddenFrames) do
        if frame and frame.Show then
            frame:Show()
        end
    end
	GossipHiddenFrames = {}
    HiddenFrames = {} -- 清空记录
end
--隐藏与记录函数完毕

function SetFontColor(fontObject, key, size)
    local color = QUESTCOLORS[key];
    fontObject:SetTextColor(color[1], color[2], color[3]);
	if size then
	fontObject:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE");
	else
    fontObject:SetFont("Fonts\\FRIZQT__.TTF", LayoutConfig.FontSize, "OUTLINE");
	end
end

-- ===================================================================
-- ====== 核心工具函数 ======
-- ===================================================================

function DQuest_SetTextAndFadeIn(fontString, text)
    if not fontString then return end
    if (QUEST_FADING_DISABLE == "1") then
        fontString:SetAlpha(1);
        fontString:SetText(text or "");
    else
        fontString:SetAlpha(0);
        fontString:SetText(text or "");
        UIFrameFadeIn(fontString, QUEST_TEXT_FADE_DURATION, 0, 1);
    end
end

-- ====== UTF-8 安全的子串与长度 ======
local function utf8_charbytes(s, i)
    local c = string.byte(s, i)
    if not c then return 0 end
    if c > 240 then return 4
    elseif c > 225 then return 3
    elseif c > 192 then return 2
    else return 1 end
end

local function utf8_len(s)
    if not s then return 0 end
    local i = 1
    local cnt = 0
    local slen = string.len(s)
    while i <= slen do
        local b = utf8_charbytes(s, i)
        if b == 0 then break end
        i = i + b
        cnt = cnt + 1
    end
    return cnt
end

local function utf8_sub(s, n)
    if not s or n <= 0 then return "" end
    local i = 1
    local cnt = 0
    local last = 0
    local slen = string.len(s)
    while i <= slen and cnt < n do
        local b = utf8_charbytes(s, i)
        if b == 0 then break end
        i = i + b
        cnt = cnt + 1
        last = i - 1
    end
    return string.sub(s, 1, last)
end

-- 根据整句字节长度设置 DQuestDescription 锚点
local function UpdateDescriptionAnchorByLength(text)
    if not text then return end
	local sw = GetScreenWidth()
    local textWidth = sw * LayoutConfig.TextWidthPct
    local byteLen = string.len(text)
   -- local xOffsetOffset = 3.1 	--文字偏移量
    local xOffset = 0 - (byteLen * xOffsetOffset) --(textWidth / 2) - (byteLen * xOffsetOffset)

    DQuestDescription:ClearAllPoints()
    DQuestDescription:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", xOffset, LayoutConfig.TextBottomOffset)
end

-- ====== 显示/隐藏黑边 ======
function ShowBlackBars()
    local screenWidth = GetScreenWidth() or 1024;
	local screenHeight = GetScreenHeight() or 768;
	local barHeight = screenHeight * 0.10;

    if not DQuestTopBlackBar then
        DQuestTopBlackBar = CreateFrame("Frame", nil, UIParent);
        DQuestTopBlackBar:SetFrameStrata("BACKGROUND");
        DQuestTopBlackBar:SetBackdrop({ bgFile = "Interface\\Addons\\ImmersiveDialogUI\\src\\assets\\art\\parchment\\BlackBar" });
        DQuestTopBlackBar:SetBackdropColor(0, 0, 0, 0.95);
        DQuestTopBlackBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5, 5);
    end
    DQuestTopBlackBar:SetWidth(screenWidth+10);
    DQuestTopBlackBar:SetHeight(barHeight+10);
    DQuestTopBlackBar:Show();

    if not DQuestBottomBlackBar then
        DQuestBottomBlackBar = CreateFrame("Frame", nil, UIParent);
        DQuestBottomBlackBar:SetFrameStrata("BACKGROUND");
        DQuestBottomBlackBar:SetBackdrop({ bgFile = "Interface\\Addons\\ImmersiveDialogUI\\src\\assets\\art\\parchment\\BlackBar" });
        DQuestBottomBlackBar:SetBackdropColor(0, 0, 0, 0.95);
        DQuestBottomBlackBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5, -5);
    end
    DQuestBottomBlackBar:SetWidth(screenWidth+10);
    DQuestBottomBlackBar:SetHeight(barHeight+10);
    DQuestBottomBlackBar:Show();
end

function HideBlackBars()
    if DQuestTopBlackBar then DQuestTopBlackBar:Hide() end
    if DQuestBottomBlackBar then DQuestBottomBlackBar:Hide() end
end

local function KillPortrait()
    if QuestFramePortrait then
        QuestFramePortrait:Hide()
        QuestFramePortrait.SetTexture = function() end
    end
    if DQuestFramePortrait then
        DQuestFramePortrait:Hide()
        DQuestFramePortrait.SetTexture = function() end
    end
end

-- ===================================================================
-- ====== Helper Functions ======
-- ===================================================================

local function PositionBelow(frameToPosition, anchorFrame, xOffset, yOffset, width)
    if not frameToPosition or not anchorFrame then return anchorFrame end
    
    frameToPosition:ClearAllPoints()
    frameToPosition:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", xOffset, yOffset)
    if width and frameToPosition.SetWidth then
        frameToPosition:SetWidth(width)
    end
    frameToPosition:Show()
    return frameToPosition
end

-- ===================================================================
-- ====== Main Functions (Modified for New Layout) ======
-- ===================================================================

function DQuestFrame_OnLoad()
    this:RegisterEvent("QUEST_GREETING");
    this:RegisterEvent("QUEST_DETAIL");
    this:RegisterEvent("QUEST_PROGRESS");
    this:RegisterEvent("QUEST_COMPLETE");
    this:RegisterEvent("QUEST_FINISHED");
    this:RegisterEvent("QUEST_ITEM_UPDATE");
	SetFontColor(DQuestFrameDeclineButtonText,"LightBrown");
	SetFontColor(DQuestFrameGreetingGoodbyeButtonText,"LightBrown");
	SetFontColor(DQuestFrameAcceptButton,"LightBrown");
	SetFontColor(DQuestFrameCancelButtonText,"LightBrown");
	SetFontColor(DQuestFrameCompleteQuestButtonText,"LightBrown");
	SetFontColor(DQuestFrameNpcNameText, "TitleBrown");
	SetFontColor(DQuestFrameGoodbyeButtonText, "LightBrown");
	SetFontColor(DQuestFrameCompleteButtonText, "LightBrown");
	SetFontColor(DQuestRewardRewardTitleText, "TitleBrown");
	
	KillPortrait();
end

function HideDefaultFrames()
    QuestFrameGreetingPanel:Hide()
    QuestFrameDetailPanel:Hide()
    QuestFrameProgressPanel:Hide()
    QuestFrameRewardPanel:Hide()
    QuestNpcNameFrame:Hide()
end

function DQuestFrame_OnEvent(event)
    if (event == "QUEST_FINISHED") then
        HideUIPanel(DQuestFrame);
        return;
    end
    if ((event == "QUEST_ITEM_UPDATE") and not DQuestFrame:IsVisible()) then
        return;
    end

    HideDefaultFrames();
    ShowUIPanel(DQuestFrame);
    if (not DQuestFrame:IsVisible()) then
        CloseQuest();
        return;
    end
    if (event == "QUEST_GREETING") then
        DQuestFrameGreetingPanel:Show();
    elseif (event == "QUEST_DETAIL") then
        DQuestFrameDetailPanel:Show();
    elseif (event == "QUEST_PROGRESS") then
        DQuestFrameProgressPanel:Show();
    elseif (event == "QUEST_COMPLETE") then
        DQuestFrameRewardPanel:Show();
    elseif (event == "QUEST_ITEM_UPDATE") then
        if (DQuestFrameDetailPanel:IsVisible()) then
            DQuestFrameItems_Update("DQuestDetail");
        elseif (DQuestFrameProgressPanel:IsVisible()) then
            DQuestFrameProgressItems_Update()
        elseif (DQuestFrameRewardPanel:IsVisible()) then
            DQuestFrameItems_Update("DQuestReward");
        end
    end
end

function DQuestFrameRewardPanel_OnShow()
	UpdateSettings()
    -- [[ FIX: Apply layout on first show ]]
    if not layoutApplied["RewardPanel"] then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local textWidth = sw * LayoutConfig.TextWidthPct
        local textHeight = sh * 0.80

        -- Use SetWidth and SetHeight instead of SetSize
        DQuestRewardScrollFrame:SetWidth(textWidth)
        DQuestRewardScrollFrame:SetHeight(textHeight)
        DQuestRewardScrollChildFrame:SetWidth(textWidth)
        DQuestRewardScrollChildFrame:SetHeight(textHeight)

        DQuestRewardScrollFrame:ClearAllPoints()
        DQuestRewardScrollFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset - 20)
        DQuestRewardText:SetWidth(textWidth)
        DQuestRewardText:ClearAllPoints()
        DQuestRewardText:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset)

        DQuestFrameCancelButton:ClearAllPoints()
        DQuestFrameCancelButton:SetPoint("CENTER", UIParent, "RIGHT", LayoutConfig.RightColumnXOffset, LayoutConfig.RightColumnYOffset)
        DQuestFrameCompleteQuestButton:ClearAllPoints()
        DQuestFrameCompleteQuestButton:SetPoint("TOPLEFT", DQuestFrameCancelButton, "TOPLEFT", 0, LayoutConfig.AcceptButtonYOffset)
        
        layoutApplied["RewardPanel"] = true
    end

    DQuestFrameDetailPanel:Hide();
    DQuestFrameGreetingPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    DQuestFrameNpcNameText:SetText(GetTitleText());
    
    local fullRewardText = GetRewardText() or "";
    DRewardTextChunks = SplitQuestTextToChunks(fullRewardText);
    if (table.getn(DRewardTextChunks) == 0) then DRewardTextChunks = { fullRewardText }; end

    DRewardCurrentChunkIndex = 1;
    DRewardTextFullyDisplayed = table.getn(DRewardTextChunks) <= 1
    DQuest_SetTextAndFadeIn(DQuestRewardText, DRewardTextChunks[DRewardCurrentChunkIndex] or "");

    SetFontColor(DQuestFrameNpcNameText, "TitleBrown");
    SetFontColor(DQuestRewardTitleText, "TitleBrown");
    SetFontColor(DQuestRewardText, "DarkBrown");
    
    local sw = GetScreenWidth()
    local ancillaryWidth = sw * LayoutConfig.RightColumnWidthPct
    DQuestRewardRewardTitleText:SetWidth(ancillaryWidth)
    local lastAnchor = PositionBelow(DQuestRewardRewardTitleText, DQuestFrameCancelButton, 0, LayoutConfig.AncillaryInitialYOffset, ancillaryWidth)

    DQuestRewardItemChooseText:Hide()
    DQuestRewardItemReceiveText:Hide()
    DQuestRewardSpellLearnText:Hide()
    DQuestRewardMoneyFrame:Hide()
    DQuestFrameItems_Update("DQuestReward", lastAnchor)

    if (QUEST_FADING_DISABLE == "0") then
        DQuestRewardScrollChildFrame:SetAlpha(0);
        UIFrameFadeIn(DQuestRewardScrollChildFrame, QUESTINFO_FADE_IN);
    end
end

function DQuestRewardCancelButton_OnClick() DeclineQuest() end
function DQuestRewardCompleteButton_OnClick()
    if (DQuestFrameRewardPanel.itemChoice == 0 and GetNumQuestChoices() > 0) then
        QuestChooseRewardError();
    else
        GetQuestReward(DQuestFrameRewardPanel.itemChoice);
    end
end

function DQuestProgressCompleteButton_OnClick() CompleteQuest() end
function DQuestGoodbyeButton_OnClick() DeclineQuest() end

function DQuestItem_OnClick()
    if (IsControlKeyDown()) then
        if (this.rewardType ~= "spell") then DressUpItemLink(GetQuestItemLink(this.type, this:GetID())); end
    elseif (IsShiftKeyDown()) then
        if (ChatFrameEditBox:IsVisible() and this.rewardType ~= "spell") then ChatFrameEditBox:Insert(GetQuestItemLink(this.type, this:GetID())); end
    end
end

function DQuestRewardItem_OnClick()
    if (IsControlKeyDown()) then
        if (this.rewardType ~= "spell") then DressUpItemLink(GetQuestItemLink(this.type, this:GetID())); end
    elseif (IsShiftKeyDown()) then
        if (ChatFrameEditBox:IsVisible()) then ChatFrameEditBox:Insert(GetQuestItemLink(this.type, this:GetID())); end
    elseif (this.type == "choice") then
        DQuestRewardItemHighlight:SetPoint("TOPLEFT", this, "TOPLEFT", -2, 5);
        DQuestRewardItemHighlight:Show();
        DQuestFrameRewardPanel.itemChoice = this:GetID();
    end
end

function DQuestFrameProgressPanel_OnShow()
	UpdateSettings()
    --if not layoutApplied["ProgressPanel"] then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local textWidth = sw * LayoutConfig.TextWidthPct
        local textHeight = sh * 0.80

        DQuestProgressScrollFrame:SetWidth(textWidth)
        DQuestProgressScrollFrame:SetHeight(textHeight)
        DQuestProgressScrollChildFrame:SetWidth(textWidth)
        DQuestProgressScrollChildFrame:SetHeight(textHeight)

        DQuestProgressScrollFrame:ClearAllPoints()
        DQuestProgressScrollFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset - 20)
        DQuestProgressText:SetWidth(textWidth)
        DQuestProgressText:ClearAllPoints()
        DQuestProgressText:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset)

        DQuestFrameGoodbyeButton:ClearAllPoints()
        DQuestFrameGoodbyeButton:SetPoint("CENTER", UIParent, "RIGHT", LayoutConfig.RightColumnXOffset, LayoutConfig.RightColumnYOffset)
        DQuestFrameCompleteButton:ClearAllPoints()
        DQuestFrameCompleteButton:SetPoint("TOPLEFT", DQuestFrameGoodbyeButton, "TOPLEFT", 0, LayoutConfig.AcceptButtonYOffset)
        
        --layoutApplied["ProgressPanel"] = true
    --end

    DQuestFrameRewardPanel:Hide();
    DQuestFrameDetailPanel:Hide();
    DQuestFrameGreetingPanel:Hide();
    DQuestFrameNpcNameText:SetText(GetTitleText());

    local fullProgressText = GetProgressText() or "";
    DProgressTextChunks = SplitQuestTextToChunks(fullProgressText);
    if (table.getn(DProgressTextChunks) == 0) then DProgressTextChunks = { fullProgressText }; end

    DProgressCurrentChunkIndex = 1;
    DProgressTextFullyDisplayed = table.getn(DProgressTextChunks) <= 1
    DQuest_SetTextAndFadeIn(DQuestProgressText, DProgressTextChunks[DProgressCurrentChunkIndex] or "");

    SetFontColor(DQuestFrameNpcNameText, "TitleBrown");
    SetFontColor(DQuestProgressText, "DarkBrown");
    SetFontColor(DQuestProgressRequiredItemsText, "TitleBrown");
	--DQuestFrameNpcNameText:SetFont("Fonts\\FRIZQT__.TTF", LayoutConfig.FontSize, "OUTLINE")
	--DQuestFrameNpcNameText:SetFont("Fonts\\FRIZQT__.TTF", LayoutConfig.FontSize, "OUTLINE")
	--DQuestFrameNpcNameText:SetFont("Fonts\\FRIZQT__.TTF", LayoutConfig.FontSize, "OUTLINE")
    if (IsQuestCompletable()) then DQuestFrameCompleteButton:Enable(); else DQuestFrameCompleteButton:Disable(); end
    DQuestFrameProgressItems_Update();
    if (QUEST_FADING_DISABLE == "0") then
        DQuestProgressScrollChildFrame:SetAlpha(0);
        UIFrameFadeIn(DQuestProgressScrollChildFrame, QUESTINFO_FADE_IN);
    end
end

function DQuestFrameProgressItems_Update()
    local numRequiredItems = GetNumQuestItems();
    
    local lastAnchor = DQuestFrameGoodbyeButton
    local sw = GetScreenWidth()
    local ancillaryWidth = sw * LayoutConfig.RightColumnWidthPct
    DQuestProgressRequiredItemsText:SetWidth(ancillaryWidth)
    DQuestProgressRequiredMoneyText:SetWidth(ancillaryWidth)

    if (numRequiredItems > 0 or GetQuestMoneyToGet() > 0) then
        lastAnchor = PositionBelow(DQuestProgressRequiredItemsText, lastAnchor, 0, LayoutConfig.AncillaryInitialYOffset)
        
        if (GetQuestMoneyToGet() > 0) then
            MoneyFrame_Update("DQuestProgressRequiredMoneyFrame", GetQuestMoneyToGet());
            if (GetQuestMoneyToGet() > GetMoney()) then
                SetFontColor(DQuestProgressRequiredMoneyText, "DarkBrown");
                SetMoneyFrameColor("DQuestProgressRequiredMoneyFrame", 1, 1, 1);
            else
                SetFontColor(DQuestProgressRequiredMoneyText, "DarkBrown");
                SetMoneyFrameColor("DQuestProgressRequiredMoneyFrame", 1.0, 1.0, 1.0);
            end
            lastAnchor = PositionBelow(DQuestProgressRequiredMoneyText, lastAnchor, 0, LayoutConfig.AncillarySpacing)
            DQuestProgressRequiredMoneyFrame:ClearAllPoints()
            DQuestProgressRequiredMoneyFrame:SetPoint("LEFT", DQuestProgressRequiredMoneyText, "RIGHT", 10, 0)
            DQuestProgressRequiredMoneyFrame:Show()
        else
            DQuestProgressRequiredMoneyText:Hide();
            DQuestProgressRequiredMoneyFrame:Hide();
        end

        local questItemName = "DQuestProgressItem";
        local itemAnchor = lastAnchor
        for i = 1, numRequiredItems, 1 do
            local item = getglobal(questItemName .. i);
            item.type = "required";
            local name, texture, numItems = GetQuestItemInfo(item.type, i);
            SetItemButtonCount(item, numItems);
            SetItemButtonTexture(item, texture);
            
            item:ClearAllPoints()
            if (mod(i, 2) == 1) then
                item:SetPoint("TOPLEFT", itemAnchor, "BOTTOMLEFT", 0, LayoutConfig.AncillarySpacing);
                if i > 1 then itemAnchor = getglobal(questItemName .. (i-2)) end 
            else 
                item:SetPoint("TOPLEFT", getglobal(questItemName .. (i - 1)), "TOPRIGHT", LayoutConfig.ItemGridColumnSpacing, 0);
            end
            item:Show();
            getglobal(questItemName .. i .. "Name"):SetText(name);
        end
        for i = numRequiredItems + 1, MAX_REQUIRED_ITEMS, 1 do getglobal(questItemName .. i):Hide() end

    else
        DQuestProgressRequiredItemsText:Hide();
        DQuestProgressRequiredMoneyText:Hide();
        DQuestProgressRequiredMoneyFrame:Hide();
        for i = 1, MAX_REQUIRED_ITEMS, 1 do getglobal("DQuestProgressItem"..i):Hide() end
    end
end

function DQuestFrameGreetingPanel_OnShow()
	UpdateSettings()
    --if not layoutApplied["GreetingPanel"] then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local textWidth = sw * LayoutConfig.TextWidthPct
        local textHeight = sh * 0.80

        DQuestGreetingScrollFrame:SetWidth(textWidth)
        DQuestGreetingScrollFrame:SetHeight(textHeight)
        DQuestGreetingScrollChildFrame:SetWidth(textWidth)
        DQuestGreetingScrollChildFrame:SetHeight(textHeight)

        DQuestGreetingScrollFrame:ClearAllPoints()
        DQuestGreetingScrollFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset - 20)
        DGreetingText:SetWidth(textWidth)
        DGreetingText:ClearAllPoints()
        DGreetingText:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset)
        
        DQuestFrameGreetingGoodbyeButton:ClearAllPoints()
        DQuestFrameGreetingGoodbyeButton:SetPoint("CENTER", UIParent, "RIGHT", LayoutConfig.RightColumnXOffset, LayoutConfig.RightColumnYOffset)

        --layoutApplied["GreetingPanel"] = true
    --end

    DQuestFrameRewardPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    DQuestFrameDetailPanel:Hide();

    if (QUEST_FADING_DISABLE == "0") then
        DQuestGreetingScrollChildFrame:SetAlpha(0);
        UIFrameFadeIn(DQuestGreetingScrollChildFrame, QUESTINFO_FADE_IN);
    end
    
    local fullGreetingText = GetGreetingText() or "";
    DGreetingTextChunks = SplitQuestTextToChunks(fullGreetingText);
    if (table.getn(DGreetingTextChunks) == 0) then DGreetingTextChunks = { fullGreetingText }; end

    DGreetingCurrentChunkIndex = 1;
    DGreetingTextFullyDisplayed = table.getn(DGreetingTextChunks) <= 1
    DQuest_SetTextAndFadeIn(DGreetingText, DGreetingTextChunks[DGreetingCurrentChunkIndex] or "");

    SetFontColor(DGreetingText, "DarkBrown");
    SetFontColor(DCurrentQuestsText, "TitleBrown");
    SetFontColor(DAvailableQuestsText, "TitleBrown");
    DGreetingText:SetFont("Fonts\\FRIZQT__.TTF", LayoutConfig.FontSize, "OUTLINE")
    local numActiveQuests = GetNumActiveQuests();
    local numAvailableQuests = GetNumAvailableQuests();
    local buttonIndex = 1;
    
    local sw = GetScreenWidth()
    local ancillaryWidth = sw * LayoutConfig.RightColumnWidthPct
    local lastAnchor = DQuestFrameGreetingGoodbyeButton 

    -- 定义高亮颜色和普通颜色的引用，避免在循环中重复访问table
    local highlightColor = QUESTCOLORS["TitleBrown"]
    local normalColor = QUESTCOLORS["LightBrown"]

    if (numActiveQuests == 0) then
        DCurrentQuestsText:Hide();
    else
        lastAnchor = PositionBelow(DCurrentQuestsText, lastAnchor, 0, LayoutConfig.AncillaryInitialYOffset, ancillaryWidth)
        for i = 1, numActiveQuests, 1 do
            local questTitleButton = getglobal("DQuestTitleButton" .. buttonIndex);
            local questTitle = GetActiveTitle(i);
            if (buttonIndex <= 9) then questTitleButton:SetText(buttonIndex .. ". " .. questTitle);
            else questTitleButton:SetText(questTitle); end
            questTitleButton:SetWidth(ancillaryWidth)
            questTitleButton:SetID(i);
            questTitleButton.isActive = 1;

            -- ==================== 修改DQuestTitleButton按钮====================
            -- 1. 获取按钮的 FontString 对象
            local buttonText = getglobal(questTitleButton:GetName())
            if buttonText then
                -- 2. 设置默认字体、大小和颜色
                SetFontColor(buttonText, "LightBrown",LayoutConfig.FontSize-3)

                -- 3. 设置高亮脚本
                questTitleButton:SetScript("OnEnter", function()
                    buttonText:SetTextColor(highlightColor[1], highlightColor[2], highlightColor[3])
                end)
                questTitleButton:SetScript("OnLeave", function()
                    buttonText:SetTextColor(normalColor[1], normalColor[2], normalColor[3])
                end)
            end
            -- ==================== DQuestTitleButton END ======================

            lastAnchor = PositionBelow(questTitleButton, lastAnchor, 0, LayoutConfig.AncillarySpacing)
            buttonIndex = buttonIndex + 1;
        end
    end
    
    if (numAvailableQuests == 0) then
        DAvailableQuestsText:Hide();
    else
        local initialOffset = (numActiveQuests > 0) and LayoutConfig.AncillaryInitialYOffset or LayoutConfig.AncillaryInitialYOffset
        lastAnchor = PositionBelow(DAvailableQuestsText, lastAnchor, 0, initialOffset, ancillaryWidth)

        for i = 1, numAvailableQuests, 1 do
            local questTitleButton = getglobal("DQuestTitleButton" .. buttonIndex);
            local questTitle = GetAvailableTitle(i);
            if (buttonIndex <= 9) then questTitleButton:SetText(buttonIndex .. ". " .. questTitle);
            else questTitleButton:SetText(questTitle); end
            questTitleButton:SetWidth(ancillaryWidth)
            questTitleButton:SetID(i);
            questTitleButton.isActive = 0;

            -- ==================== 新增代码 START ====================
            -- 1. 获取按钮的 FontString 对象
            local buttonText = getglobal(questTitleButton:GetName())
            if buttonText then
                -- 2. 设置默认字体、大小和颜色
                SetFontColor(buttonText, "LightBrown",LayoutConfig.FontSize-3)

                -- 3. 设置高亮脚本
                questTitleButton:SetScript("OnEnter", function()
                    buttonText:SetTextColor(highlightColor[1], highlightColor[2], highlightColor[3])
                end)
                questTitleButton:SetScript("OnLeave", function()
                    buttonText:SetTextColor(normalColor[1], normalColor[2], normalColor[3])
                end)
            end
            -- ==================== 新增代码 END ======================

            lastAnchor = PositionBelow(questTitleButton, lastAnchor, 0, LayoutConfig.AncillarySpacing)
            buttonIndex = buttonIndex + 1;
        end
    end
    
    for i = buttonIndex, MAX_NUM_QUESTS, 1 do
        getglobal("DQuestTitleButton" .. i):Hide();
    end
end
-- ===================================================================
-- ====== 按键处理逻辑 ======
-- ===================================================================
local function DQuest_ShowDetailPanelRewards()
    DTextAlphaDependentFrame:Show();
    DQuestFrameAcceptButton:Enable();
    if (QUEST_FADING_DISABLE == "0") then
        UIFrameFadeIn(DTextAlphaDependentFrame, QUESTINFO_FADE_IN);
    else
        DTextAlphaDependentFrame:SetAlpha(1);
    end
end

local function DQuest_HandleDetailKeyDown()
    if (not DQuestTextFullyDisplayed) then
        if (not DQuestRevealing) then
            if (DQuestCurrentChunkIndex < table.getn(DQuestTextChunks)) then
                DQuestCurrentChunkIndex = DQuestCurrentChunkIndex + 1;
                DQuestCurrentCharIndex, DQuestRevealTimer, DQuestRevealing = 0, 0, true;
                DQuestDescription:SetText("");
                UpdateDescriptionAnchorByLength(DQuestTextChunks[DQuestCurrentChunkIndex] or "");
            else
                DQuestTextFullyDisplayed = true;
                DQuest_ShowDetailPanelRewards();
            end
        else 
            local chunk = DQuestTextChunks[DQuestCurrentChunkIndex] or "";
            DQuestCurrentCharIndex = utf8_len(chunk);
            DQuestDescription:SetText(utf8_sub(chunk, DQuestCurrentCharIndex));
            DQuestRevealing = false;
            if (DQuestCurrentChunkIndex >= table.getn(DQuestTextChunks)) then
                DQuestTextFullyDisplayed = true;
                DQuest_ShowDetailPanelRewards();
            end
        end
    else
        DQuestDetailAcceptButton_OnClick();
    end
end

local function DQuest_HandleRewardKeyDown()
    if (DRewardTextFullyDisplayed) then
        DQuestRewardCompleteButton_OnClick();
        return;
    end
    DRewardCurrentChunkIndex = DRewardCurrentChunkIndex + 1;
    DQuest_SetTextAndFadeIn(DQuestRewardText, DRewardTextChunks[DRewardCurrentChunkIndex] or "");
    if (DRewardCurrentChunkIndex >= table.getn(DRewardTextChunks)) then
        DRewardTextFullyDisplayed = true;
    end
end

local function DQuest_HandleProgressKeyDown()
    if (DProgressTextFullyDisplayed) then
        if (DQuestFrameCompleteButton:IsEnabled()) then
            DQuestProgressCompleteButton_OnClick();
        end
        return;
    end
    DProgressCurrentChunkIndex = DProgressCurrentChunkIndex + 1;
    DQuest_SetTextAndFadeIn(DQuestProgressText, DProgressTextChunks[DProgressCurrentChunkIndex] or "");
    if (DProgressCurrentChunkIndex >= table.getn(DProgressTextChunks)) then
        DProgressTextFullyDisplayed = true;
    end
end

local function DQuest_HandleGreetingKeyDown()
    if (DGreetingTextFullyDisplayed) then
        if (GetNumActiveQuests() > 0 or GetNumAvailableQuests() > 0) then
            local firstButton = getglobal("DQuestTitleButton1");
            if (firstButton and firstButton:IsVisible()) then firstButton:Click(); end
        end
        return;
    end
    DGreetingCurrentChunkIndex = DGreetingCurrentChunkIndex + 1;
    DQuest_SetTextAndFadeIn(DGreetingText, DGreetingTextChunks[DGreetingCurrentChunkIndex] or "");
    if (DGreetingCurrentChunkIndex >= table.getn(DGreetingTextChunks)) then
        DGreetingTextFullyDisplayed = true;
    end
end

function DQuestFrame_OnKeyDown()
    local key = arg1;
    
    -- 修改: 使用 KEY_NO 变量替代 "B"，并保留 ESCAPE
	if (key == KEY_NO or key == "ESCAPE") then
        HideUIPanel(DQuestFrame);
        return
    end

    -- 修改: 使用 KEY_YES 变量替代 "X"，并保留 SPACE
    if (key == KEY_YES or key == "SPACE") then
        if (DQuestFrameDetailPanel:IsVisible()) then DQuest_HandleDetailKeyDown();
        elseif (DQuestFrameRewardPanel:IsVisible()) then DQuest_HandleRewardKeyDown();
        elseif (DQuestFrameProgressPanel:IsVisible()) then DQuest_HandleProgressKeyDown();
        elseif (DQuestFrameGreetingPanel:IsVisible()) then DQuest_HandleGreetingKeyDown();
        end
        return;
    end
    
    if (key >= "1" and key <= "9") then
        if (DQuestFrameGreetingPanel:IsVisible()) then
            local buttonNum = tonumber(key);
            local questButton = getglobal("DQuestTitleButton" .. buttonNum);
            if (questButton and questButton:IsVisible()) then questButton:Click(); end
        end
    end
end

function DQuestFrame_OnShow()
	UpdateSettings()
    --if not layoutApplied["MainFrame"] then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        DQuestFrame:SetWidth(sw)
        DQuestFrame:SetHeight(sh)
        DQuestFrame:ClearAllPoints()
        DQuestFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        DQuestFrame:SetFrameLevel(1) 

        DQuestFrameNpcNameText:SetWidth(sw) 
        DQuestFrameNpcNameText:ClearAllPoints()
        DQuestFrameNpcNameText:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TitleBottomOffset)
        
        local ancillaryWidth = sw * LayoutConfig.RightColumnWidthPct
        local ancillaryFrames = {
            "DQuestDetailObjectiveTitleText", "DQuestObjectiveText", "DQuestDetailRewardTitleText",
            "DQuestDetailItemChooseText", "DQuestDetailItemReceiveText", "DQuestDetailSpellLearnText",
            "DQuestRewardRewardTitleText", "DQuestRewardItemChooseText", "DQuestRewardItemReceiveText",
            "DQuestRewardSpellLearnText", "DCurrentQuestsText", "DAvailableQuestsText"
        }
        for _, name in ipairs(ancillaryFrames) do
            local frame = getglobal(name)
            if frame and frame.SetWidth then
                frame:SetWidth(ancillaryWidth)
            end
        end

       -- layoutApplied["MainFrame"] = true;
    --end

    PlaySound("igQuestListOpen");
	DQuestFrameNpcNameText:SetText(UnitName("npc"));
    DQuestFrame:EnableKeyboard(true);
    DQuestFrame:SetScript("OnKeyDown", DQuestFrame_OnKeyDown);
	HideAllFramesExceptDQuest();
	SetFontColor(DQuestDetailObjectiveTitleText, "TitleBrown");
	SetFontColor(DAvailableQuestsText, "TitleBrown");
	ShowBlackBars();
end

function DQuestFrame_OnHide()
    DQuestFrameGreetingPanel:Hide();
    DQuestFrameDetailPanel:Hide();
    DQuestFrameRewardPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    
    DQuestTextChunks, DRewardTextChunks, DGreetingTextChunks, DProgressTextChunks = {}, {}, {}, {};
    DQuestCurrentChunkIndex, DRewardCurrentChunkIndex, DGreetingCurrentChunkIndex, DProgressCurrentChunkIndex = 1, 1, 1, 1;
    DQuestTextFullyDisplayed, DRewardTextFullyDisplayed, DGreetingTextFullyDisplayed, DProgressTextFullyDisplayed = false, false, false, false;

    CloseQuest();
    PlaySound("igQuestListClose");
	RestoreHiddenFrames();
    HideBlackBars();
end

function DQuestTitleButton_OnClick()
    if (this.isActive == 1) then SelectActiveQuest(this:GetID());
    else SelectAvailableQuest(this:GetID()); end
    PlaySound("igQuestListSelect");
end

function DQuestMoneyFrame_OnLoad()
    MoneyFrame_OnLoad();
    MoneyFrame_SetType("STATIC");
end

function DQuestFrameItems_Update(questState, initialAnchor)
    if (DQuestFrameRewardPanel) then DQuestFrameRewardPanel.itemChoice = 0; end
    if (DQuestRewardItemHighlight) then DQuestRewardItemHighlight:Hide(); end

    local numQuestRewards = GetNumQuestRewards();
    local numQuestChoices = GetNumQuestChoices();
    local money = GetRewardMoney();
    local totalRewards = numQuestRewards + numQuestChoices;
    
    local questItemName = questState .. "Item";
    local lastAnchor = initialAnchor or DQuestFrame;

    if (totalRewards == 0 and money == 0) then
        getglobal(questState .. "RewardTitleText"):Hide();
        return lastAnchor;
    else
        -- [[ FIX START ]]
        local rewardTitleFrame = getglobal(questState .. "RewardTitleText");
        
        -- 檢查要定位的框架是否與錨點相同，如果不同才重新定位
        -- 這可以防止 "anchor to itself" 的錯誤
        if (rewardTitleFrame ~= lastAnchor) then
            lastAnchor = PositionBelow(rewardTitleFrame, lastAnchor, 0, LayoutConfig.AncillarySpacing);
        end

        -- 確保標題文字顏色與其他標題一致
        SetFontColor(rewardTitleFrame, "TitleBrown");
        -- [[ FIX END ]]
    end

    local rewardsCount = 0;

    if (numQuestChoices > 0) then
        local itemChooseText = getglobal(questState .. "ItemChooseText");
        lastAnchor = PositionBelow(itemChooseText, lastAnchor, 0, LayoutConfig.AncillarySpacing)
        SetFontColor(itemChooseText, "DarkBrown");
        
        local itemAnchor = lastAnchor
        for i = 1, numQuestChoices, 1 do
            local item = getglobal(questItemName .. (rewardsCount + i));
            local name, texture, numItems, quality, isUsable = GetQuestItemInfo("choice", i);
            item:SetID(i); item.type = "choice"; item.rewardType = "item"
            getglobal(item:GetName() .. "Name"):SetText(name);
            SetItemButtonCount(item, numItems or 1); SetItemButtonTexture(item, texture);
            if (isUsable) then SetItemButtonTextureVertexColor(item, 1.0, 1.0, 1.0); else SetItemButtonTextureVertexColor(item, 0.9, 0, 0); end

            item:ClearAllPoints()
            if (mod(i, 2) == 1) then
                item:SetPoint("TOPLEFT", itemAnchor, "BOTTOMLEFT", 0, LayoutConfig.ItemGridRowSpacing);
                if i > 1 then itemAnchor = getglobal(questItemName .. (rewardsCount + i - 2)) end
            else
                item:SetPoint("TOPLEFT", getglobal(questItemName .. (rewardsCount + i - 1)), "TOPRIGHT", LayoutConfig.ItemGridColumnSpacing, 0);
            end
            item:Show();
        end
        lastAnchor = getglobal(questItemName .. (rewardsCount + numQuestChoices - mod(numQuestChoices-1, 2))) 
        rewardsCount = rewardsCount + numQuestChoices;
    else
        getglobal(questState .. "ItemChooseText"):Hide();
    end

    if (numQuestRewards > 0) then
        local itemReceiveText = getglobal(questState .. "ItemReceiveText");
        lastAnchor = PositionBelow(itemReceiveText, lastAnchor, 0, LayoutConfig.AncillarySpacing)
        SetFontColor(itemReceiveText, "DarkBrown");

        local itemAnchor = lastAnchor
        for i = 1, numQuestRewards, 1 do
            local item = getglobal(questItemName .. (rewardsCount + i));
            local name, texture, numItems, quality, isUsable = GetQuestItemInfo("reward", i);
            item:SetID(i); item.type = "reward"; item.rewardType = "item";
            getglobal(item:GetName() .. "Name"):SetText(name);
            SetItemButtonCount(item, numItems or 1); SetItemButtonTexture(item, texture);
           
            item:ClearAllPoints()
            if (mod(i, 2) == 1) then
                item:SetPoint("TOPLEFT", itemAnchor, "BOTTOMLEFT", 0, LayoutConfig.ItemGridRowSpacing);
                if i > 1 then itemAnchor = getglobal(questItemName .. (rewardsCount + i - 2)) end
            else
                item:SetPoint("TOPLEFT", getglobal(questItemName .. (rewardsCount + i - 1)), "TOPRIGHT", LayoutConfig.ItemGridColumnSpacing, 0);
            end
            item:Show();
        end
        lastAnchor = getglobal(questItemName .. (rewardsCount + numQuestRewards - mod(numQuestRewards-1, 2)))
        rewardsCount = rewardsCount + numQuestRewards
    else
        getglobal(questState .. "ItemReceiveText"):Hide();
    end
    
    for i = rewardsCount + 1, MAX_NUM_ITEMS, 1 do getglobal(questItemName .. i):Hide(); end

    if (money > 0) then
        local moneyFrame = getglobal(questState .. "MoneyFrame")
        lastAnchor = PositionBelow(moneyFrame, lastAnchor, 10, LayoutConfig.AncillarySpacing)
        MoneyFrame_Update(questState .. "MoneyFrame", money);
        moneyFrame:Show()
    else
        getglobal(questState .. "MoneyFrame"):Hide();
    end

    if (questState == "QuestReward") then
        DQuestFrameCompleteQuestButton:Enable();
        DQuestRewardItemHighlight:Hide();
    end
    return lastAnchor
end
--[[
    优化后的文本分段函数
    - text: 要处理的字符串
    - mode: "en" 或 "zh"，代表英文或中文模式
    - word_limit_en: 英文模式下的单词数上限 (建议 25-30)
    - char_limit_zh: 中文模式下的字数上限 (建议 40-50)
]]
function SplitQuestTextToChunks(text, word_limit_en, char_limit_zh)
    -- 根據您的建議，將判斷邏輯內置
    local mode = Text_Language and "zh" or "en"
    
    local chunks = {}
    if type(text) ~= "string" or text == "" then return chunks end
    word_limit_en = word_limit_en or 25
    char_limit_zh = char_limit_zh or 45

    -- 1. 预处理：移除换行符和首尾空格
    text = string.gsub(text, "[\r\n]", " ") -- 将换行符统一变为空格，以正确计算单词数
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ") -- 将多个连续空格合并为单个，使单词计数更准确

    local buffer = ""
    local space_count = 0 -- 单词计数器 (英文模式)
    local char_count = 0  -- 字符计数器 (中文模式)
    
    local i, len = 1, string.len(text)
    while i <= len do
        -- 正确处理 UTF-8 字符
        local byte1 = string.byte(text, i)
        local charLen = (byte1 > 240 and 4) or (byte1 > 224 and 3) or (byte1 > 192 and 2) or 1
        local char = string.sub(text, i, i + charLen - 1)
        
        buffer = buffer .. char

        -- 2. 检查是否为终结符或特殊符号
        local should_split = false
        local is_ender_char = false

        -- 检查 "..." 和 "…"
        if char == "." and string.sub(text, i, i + 2) == "..." then
            -- 检测到 "..."，作为一个整体处理
            buffer = buffer .. ".." -- 补全省略号
            i = i + 2 -- 跳过后面两个点
            charLen = 3
            is_ender_char = true
        elseif char == "…" or char == "—" then
            -- 对于成对出现的符号，可以检查下一个是否也是同类
            local next_char_start = i + charLen
            if next_char_start <= len then
                local next_char_byte1 = string.byte(text, next_char_start)
                local next_charLen = (next_char_byte1 > 240 and 4) or (next_char_byte1 > 224 and 3) or (next_char_byte1 > 192 and 2) or 1
                if string.sub(text, next_char_start, next_char_start + next_charLen - 1) == char then
                    is_ender_char = true
                end
            end
        elseif char == "。" or char == "！" or char == "？" or char == "!" or char == "?" or char == ";" or char == "；" then
            is_ender_char = true
        elseif char == "." then
            -- 核心优化：处理 Mr.Z的情况
            -- 只有当句点后是空格，或是字符串结尾时，才认为是句子结束
            local next_char = string.sub(text, i + 1, i + 1)
            if next_char == " " or next_char == "" then
                is_ender_char = true
            end
        end

        -- 3. 根据模式判断是否分段
        if is_ender_char then
            if mode == "en" and space_count >= 3 then -- 英文模式下，句子至少有一定单词量，避免超短句
                should_split = true
            elseif mode == "zh" and char_count >= 10 then -- 中文模式下，句子至少有一定字数
                should_split = true
            end
        end
        
        -- 4. 检查是否达到长度上限，强制分段
        if not should_split then
            if mode == "en" and char == " " then
                space_count = space_count + 1
                if space_count >= word_limit_en then
                    should_split = true
                end
            elseif mode == "zh" then
                -- 在中文模式下，我们统计非符号字符的数量
                if not string.find("，。,！!？?；;……— ", char) then
                    char_count = char_count + 1
                    if char_count >= char_limit_zh then
                        should_split = true
                    end
                end
            end
        end

        -- 5. 执行分段
        if should_split then
            -- Trim a leading space from the new buffer if the split happens after a space
            local next_start = i + charLen
            if next_start <= len and string.sub(text, next_start, next_start) == " " then
                i = i + 1 -- 如果当前分段结尾是空格，下一个分段就跳过这个空格
            end
            table.insert(chunks, buffer)
            buffer, space_count, char_count = "", 0, 0
        end

        i = i + charLen
    end

    -- 6. 添加最后剩余的 buffer
    if string.gsub(buffer, "%s+", "") ~= "" then
        table.insert(chunks, buffer)
    end
    
    return chunks
end

function DQuestFrameDetailPanel_OnShow()
	UpdateSettings()
    --if not layoutApplied["DetailPanel"] then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local textWidth = sw * LayoutConfig.TextWidthPct
        local textHeight = sh * 0.80

        DQuestDetailScrollFrame:SetWidth(textWidth)
        DQuestDetailScrollFrame:SetHeight(textHeight)
        DQuestDetailScrollChildFrame:SetWidth(textWidth)
        DQuestDetailScrollChildFrame:SetHeight(textHeight)

        DQuestDetailScrollFrame:ClearAllPoints()
        DQuestDetailScrollFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LayoutConfig.TextBottomOffset - 20)
        DQuestDescription:SetWidth(textWidth)
        DQuestDescription:ClearAllPoints()
        -- The position for DQuestDescription is set dynamically in UpdateDescriptionAnchorByLength

        DQuestFrameDeclineButton:ClearAllPoints()
        DQuestFrameDeclineButton:SetPoint("CENTER", UIParent, "RIGHT", LayoutConfig.RightColumnXOffset, LayoutConfig.RightColumnYOffset)
        DQuestFrameAcceptButton:ClearAllPoints()
        DQuestFrameAcceptButton:SetPoint("TOPLEFT", DQuestFrameDeclineButton, "TOPLEFT", 0, LayoutConfig.AcceptButtonYOffset)
        
        --layoutApplied["DetailPanel"] = true
    --end

    DQuestFrameRewardPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    DQuestFrameGreetingPanel:Hide();
    DQuestFrameNpcNameText:SetText(GetTitleText());
    
    local fullText = GetQuestText() or "";
    DQuestTextChunks = SplitQuestTextToChunks(fullText);
    if (table.getn(DQuestTextChunks) == 0) then DQuestTextChunks = { fullText }; end

    DQuestCurrentChunkIndex, DQuestCurrentCharIndex, DQuestRevealTimer = 1, 0, 0;
    DQuestRevealSpeed, DQuestRevealing, DQuestTextFullyDisplayed = 24, true, false;

    local sw = GetScreenWidth()
    local ancillaryWidth = sw * LayoutConfig.RightColumnWidthPct
    local lastAnchor = DQuestFrameDeclineButton

    lastAnchor = PositionBelow(DQuestDetailObjectiveTitleText, lastAnchor, 0, LayoutConfig.AncillaryInitialYOffset, ancillaryWidth)
    lastAnchor = PositionBelow(DQuestObjectiveText, lastAnchor, 0, LayoutConfig.AncillarySpacing, ancillaryWidth)
    DQuestObjectiveText:SetText(GetObjectiveText());
    SetFontColor(DQuestObjectiveText, "DarkBrown");
    
    DQuestDetailRewardTitleText:Hide()
    DQuestDetailItemChooseText:Hide()
    DQuestDetailItemReceiveText:Hide()
    DQuestDetailSpellLearnText:Hide()
    DQuestFrameItems_Update("DQuestDetail", lastAnchor);
    
	SetFontColor(DQuestDetailRewardTitleText, "TitleBrown");
    SetFontColor(DQuestFrameNpcNameText, "TitleBrown");
    SetFontColor(DQuestDescription, "DarkBrown");
	DQuestDescription:SetFont("Fonts\\FRIZQT__.TTF", LayoutConfig.FontSize, "OUTLINE")
	UpdateDescriptionAnchorByLength(DQuestTextChunks[DQuestCurrentChunkIndex] or "")
	DQuestDescription:SetText("");

    DTextAlphaDependentFrame:SetAlpha(0);
    DQuestFrameAcceptButton:Disable();
end

function DQuestFrameDetailPanel_OnUpdate(elapsed)
    local chunk = DQuestTextChunks[DQuestCurrentChunkIndex] or ""
    if (chunk == "" or not DQuestRevealing) then return end

    DQuestRevealTimer = DQuestRevealTimer + elapsed
    local cps = DQuestRevealSpeed or 24
    local add = math.floor(DQuestRevealTimer * cps)
    if add > 0 then
        DQuestRevealTimer = DQuestRevealTimer - (add / cps)
        local totalChars = utf8_len(chunk)
        DQuestCurrentCharIndex = math.min(totalChars, DQuestCurrentCharIndex + add)
        DQuestDescription:SetText(utf8_sub(chunk, DQuestCurrentCharIndex))
        
        if DQuestCurrentCharIndex >= totalChars then
            DQuestRevealing = false
            if (DQuestCurrentChunkIndex >= table.getn(DQuestTextChunks)) then
                DQuestTextFullyDisplayed = true
                DQuest_ShowDetailPanelRewards();
            else
                DQuestFrameAcceptButton:Disable();
            end
        end
    end
end

function DQuestDetailAcceptButton_OnClick() AcceptQuest() end
function DQuestDetailDeclineButton_OnClick()
    HideUIPanel(DQuestFrame);
    PlaySound("igQuestCancel");
end