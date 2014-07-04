-----------------------------------------------------------------------------------------------
-- Client Lua Script for EZAuction
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "Money"
require "Item"
require "Unit"
require "MarketplaceLib"
require "ItemAuction"


 
-----------------------------------------------------------------------------------------------
-- EZAuction Module Definition
-----------------------------------------------------------------------------------------------
local EZAuction = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local defaults = {}
defaults.config = {}
defaults.config.BidUndercutBuyout = false
defaults.config.DisableSellConfirmation = false
defaults.config.DisableCancelConfirmation = false
defaults.config.BuyoutUndercutByPercent = true
defaults.config.BidUndercutByPercent = true
defaults.config.CheckListingFee = false
defaults.config.BuyoutUndercutAmount = 100
defaults.config.BuyoutUndercutPercentage = 5
defaults.config.BidUndercutAmount = 100
defaults.config.BidUndercutPercentage = 5

 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function EZAuction:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here	
	self.SaveData = {}
	self.SaveData.config = setmetatable({}, {__index = defaults.config})

    return o
end

function EZAuction:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"MarketplaceAuction",
		"MarketplaceListings"
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)	
end

function EZAuction:InitializeOptions()	
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutBuyoutAmount:Amount"):SetAmount(self.SaveData.config.BuyoutUndercutAmount)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutBuyoutPercent:Amount"):SetText(self.SaveData.config.BuyoutUndercutPercentage)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutBuyoutPercent:Slider"):SetValue(self.SaveData.config.BuyoutUndercutPercentage)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutByPercentButton"):SetCheck(self.SaveData.config.BuyoutUndercutByPercent)
	
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBidAmount:Amount"):SetAmount(self.SaveData.config.BidUndercutAmount)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBidPercent:Amount"):SetText(self.SaveData.config.BidUndercutPercentage)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBidPercent:Slider"):SetValue(self.SaveData.config.BidUndercutPercentage)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutByPercentButton"):SetCheck(self.SaveData.config.BidUndercutByPercent)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBuyoutButton"):SetCheck(self.SaveData.config.BidUndercutBuyout)
	
	self.wndOptions:FindChild("EZAuctionOptions:OtherOptions:SellConfirmation:DisableSellConfirmationButton"):SetCheck(self.SaveData.config.DisableSellConfirmation)
	self.wndOptions:FindChild("EZAuctionOptions:OtherOptions:CancelConfirmation:DisableCancelConfirmationButton"):SetCheck(self.SaveData.config.DisableCancelConfirmation)
		
	self:ToggleBuyoutPercentAmount()
	self:ToggleBidPercentAmount()
end
 

-----------------------------------------------------------------------------------------------
-- EZAuction OnLoad
-----------------------------------------------------------------------------------------------
function EZAuction:OnLoad()
	
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EZAuction.xml")
	
	-- Get MarketplaceAuction addon
	self.MarketplaceAuction = Apollo.GetAddon("MarketplaceAuction")
	
	-- Get MarketplaceListings addon
	self.MarketplaceListings = Apollo.GetAddon("MarketplaceListings")
		
	self:InitializeHooks()
end


-----------------------------------------------------------------------------------------------
-- EZAuction Functions
-----------------------------------------------------------------------------------------------
function EZAuction:InitializeHooks()
	local MarketplaceAuction = Apollo.GetAddon("MarketplaceAuction")
	local MarketplaceListings = Apollo.GetAddon("MarketplaceListings")
	
	
	-- Override OnToggleAuctionWindow
	local fnOnToggleAuctionWindow = MarketplaceAuction.OnToggleAuctionWindow
	MarketplaceAuction.OnToggleAuctionWindow = function(tMarketplaceAuction)
		fnOnToggleAuctionWindow(tMarketplaceAuction)
		
		self.wndOptionsButton = Apollo.LoadForm(self.xmlDoc, "EZAuctionOptionsButtonContainer", tMarketplaceAuction.wndMain, self)
		self.wndOptions = Apollo.LoadForm(self.xmlDoc, "EZAuctionOptions", tMarketplaceAuction.wndMain, self)

		self.wndOptionsButton:FindChild("EZAuctionOptionsButton"):AttachWindow(self.wndOptions)
		self:InitializeOptions()
	end
	
	-- Override OnCreateBuyoutInputBoxChanged
	local fnOldOnCreateBuyoutInputBoxChanged = MarketplaceAuction.OnCreateBuyoutInputBoxChanged
	MarketplaceAuction.OnCreateBuyoutInputBoxChanged = function(tMarketplaceAuction, wndHandler, wndControl)
		local AuctionWindow = tMarketplaceAuction.wndMain
		
		self:UpdatePrice(AuctionWindow, nil, nil)
		fnOldOnCreateBuyoutInputBoxChanged(tMarketplaceAuction, wndHandler, wndControl)
	end
	
	-- Override OnItemAuctionSearchResults
	local fnOnItemAuctionSearchResults = MarketplaceAuction.OnItemAuctionSearchResults
	MarketplaceAuction.OnItemAuctionSearchResults = function(tMarketplaceAuction, nPage, nTotalResults, tAuctions)
		fnOnItemAuctionSearchResults(tMarketplaceAuction, nPage, nTotalResults, tAuctions)
		
		local AuctionWindow = tMarketplaceAuction.wndMain
		local nLowestBuyoutPrice = 0
		local nLowestBidPrice = 0
		
		for idx, aucCurr in ipairs(tAuctions) do
			local nBuyoutPrice = aucCurr:GetBuyoutPrice():GetAmount()
			local nBidPrice = math.max(aucCurr:GetMinBid():GetAmount(), aucCurr:GetCurrentBid():GetAmount()) 
			
			if nLowestBidPrice == 0 or nBidPrice < nLowestBidPrice then
				nLowestBidPrice = nBidPrice
			end
			
			if nLowestBuyoutPrice == 0 or nBuyoutPrice < nLowestBuyoutPrice then
				nLowestBuyoutPrice = nBuyoutPrice
			end
		end
		
		self:UpdatePrice(AuctionWindow, nLowestBidPrice, nLowestBuyoutPrice)
		
		if AuctionWindow ~= nil then
			local itemSelling = AuctionWindow:FindChild("SellContainer"):FindChild("CreateSellOrderBtn"):GetData()
			
			if itemSelling ~= nil and itemSelling:IsAuctionable() then
				MarketplaceAuction.ValidateSellOrder(tMarketplaceAuction)
			end
		end
	end
	
	-- Override OnSellListItemCheck
	local fnOldOnSellListItemCheck = MarketplaceAuction.OnSellListItemCheck
	MarketplaceAuction.OnSellListItemCheck = function(tMarketplaceAuction, wndHandler, wndControl)
		fnOldOnSellListItemCheck(tMarketplaceAuction, wndHandler, wndControl)
		
		local itemSelling = wndHandler:GetData()
		local itemSellingRarity = itemSelling:GetItemQuality()
		local arFilter =  tOptions, { nType = MarketplaceLib.ItemAuctionFilterData.ItemAuctionFilterQuality, nMin = itemSellingRarity , nMax = itemSellingRarity }
	
		MarketplaceLib.RequestItemAuctionsByItems({ itemSelling:GetItemId() }, 0, MarketplaceLib.AuctionSort.Buyout, false, arFilter  , nil, nil, nil)
	end
	
	-- Override OnPostItemAuctionResult
	local fnOldOnPostItemAuctionResult = MarketplaceAuction.OnPostItemAuctionResult
	MarketplaceAuction.OnPostItemAuctionResult = function(tMarketplaceAuction, eAuctionPostResult, aucCurr)	
		if not self.SaveData.config.DisableSellConfirmation then
			fnOldOnPostItemAuctionResult(tMarketplaceAuction, eAuctionPostResult, aucCurr)	
		end
	end
	
	local fnOldOnCancelBtn = MarketplaceListings.OnCancelBtn
	MarketplaceListings.OnCancelBtn = function(tMarkerplaceListings, wndHandler, wndControl)
		if self.SaveData.config.DisableCancelConfirmation then
			local aucCurrent = wndHandler:GetData()
			if not aucCurrent then
				return
			end
			aucCurrent:Cancel()
		else
			fnOldOnCancelBtn(tMarkerplaceListings, wndHandler, wndControl)
		end
	end
end

-- Update the ui with new prices
function EZAuction:UpdatePrice(tAuctionWindow, nBidPrice, nBuyoutPrice)
	if tAuctionWindow == nil then
		return
	end
	
	local tBidInput = tAuctionWindow:FindChild("SellContainer:SellRightSide:CreateOrderContainer:CreateBidInputBG:CreateBidInputBox")
	local tBuyoutInput = tAuctionWindow:FindChild("SellContainer:SellRightSide:CreateOrderContainer:CreateBuyoutInputBG:CreateBuyoutInputBox")
	local nNewBuyoutPrice = self:CalculatePrice(nBuyoutPrice, true, self.SaveData.config.BuyoutUndercutByPercent)
	
	if nNewBuyoutPrice ~= nil then
		tBuyoutInput:SetAmount(nNewBuyoutPrice )
	end
		
	if self.SaveData.config.BidUndercutBuyout then
		tBidInput:SetAmount(self:CalculatePrice(tBuyoutInput:GetAmount(), false, self.SaveData.config.BuyoutUndercutByPercent))
	else
		if nBidPrice ~= nil then
			tBidInput:SetAmount(self:CalculatePrice(nBidPrice, false, self.SaveData.config.BuyoutUndercutByPercent))
		end
	end	
end

-- Calculate the price according to the settings
function EZAuction:CalculatePrice(Amount, isBuyout, isPercent)
	if Amount == nil then
		return Amount
	end
	
	if isBuyout then
		if isPercent then
			return Amount * ( 1 - (self.SaveData.config.BuyoutUndercutPercentage / 100))
		else
			return Amount - self.SaveData.config.BuyoutUndercutAmount
		end
	else
		if isPercent then
			return Amount * ( 1 - (self.SaveData.config.BidUndercutPercentage / 100))
		else
			return Amount - self.SaveData.config.BidUndercutAmount
		end	
	end
end

-- Save settings
function EZAuction:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end
	return self.SaveData.config
end

--Load Settings
function EZAuction:OnRestore(eLevel, tData)
	self.SaveData.config = setmetatable(tData, {__index = defaults.config})
end


---------------------------------------------------------------------------------------------------
-- EZAuctionOptions Functions
---------------------------------------------------------------------------------------------------

function EZAuction:UndercutBuyoutSliderChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.SaveData.config.BuyoutUndercutPercentage= fNewValue
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutBuyoutPercent:Amount"):SetText(fNewValue)
end

function EZAuction:OnUndercutBuyoutAmountChanged( wndHandler, wndControl )
	self.SaveData.config.BuyoutUndercutAmount = self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutBuyoutAmount:Amount"):GetAmount()
end

function EZAuction:btnUndercutByPercentToggle( wndHandler, wndControl, eMouseButton )
	self.SaveData.config.BuyoutUndercutByPercent = not self.SaveData.config.BuyoutUndercutByPercent
	self:ToggleBuyoutPercentAmount()
end

function EZAuction:ToggleBuyoutPercentAmount()
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutBuyoutPercent"):Show(self.SaveData.config.BuyoutUndercutByPercent)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBuyout:UndercutBuyoutAmount"):Show(not self.SaveData.config.BuyoutUndercutByPercent)
end

function EZAuction:UndercutBidSliderChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.SaveData.config.BidUndercutPercentage= fNewValue
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBidPercent:Amount"):SetText(fNewValue)
end

function EZAuction:OnUndercutBidAmountChanged( wndHandler, wndControl )
	self.SaveData.config.BidUndercutAmount = self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBidAmount:Amount"):GetAmount()

end

function EZAuction:btnUndercutBidByPercentToggle( wndHandler, wndControl, eMouseButton )
	self.SaveData.config.BidUndercutByPercent = not self.SaveData.config.BidUndercutByPercent
	self:ToggleBidPercentAmount()
end

function EZAuction:ToggleBidPercentAmount()
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBidPercent"):Show(self.SaveData.config.BidUndercutByPercent)
	self.wndOptions:FindChild("EZAuctionOptions:UndercutBid:UndercutBidAmount"):Show(not self.SaveData.config.BidUndercutByPercent)
end

function EZAuction:btnUndercutBuyout( wndHandler, wndControl, eMouseButton )
	self.SaveData.config.BidUndercutBuyout = not self.SaveData.config.BidUndercutBuyout 
end

function EZAuction:btnDisableSellConfirmation( wndHandler, wndControl, eMouseButton )
	self.SaveData.config.DisableSellConfirmation = not self.SaveData.config.DisableSellConfirmation
end

function EZAuction:btnDisableCancelConfirmation( wndHandler, wndControl, eMouseButton )
	self.SaveData.config.DisableCancelConfirmation = not self.SaveData.config.DisableCancelConfirmation
end

-----------------------------------------------------------------------------------------------
-- EZAuction Instance
-----------------------------------------------------------------------------------------------
local EZAuctionInst = EZAuction:new()
EZAuctionInst:Init()
