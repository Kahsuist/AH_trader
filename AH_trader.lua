-- переменные для задания паузы
-- local dbWowUction_com = TSM.data
--local frame_counter=0
--local twoSecondAmountFrames=120
local missFramesAfterOneAction = 1	-- предназначена для пропуска некоторого количеста фреймов(кадров) после некоторого действия. для разных действий разное время. фактически является паузой. длительность паузы равна (количКадровВСекунду/величЭтойПеременной). нужна для возможности задать в отдельном действии время паузы
local missFrames = 1	-- задает паузу для missFramesAfterOneAction в общем случае, чтобы процесс не проходил молниеносно, а имел некоторую длительность
local pauseAfterAhQuery = 5	-- задает паузу запроса на сервер, эта величина попадет так же в missFramesAfterOneAction
local pauseAfterBuyLot = 9	-- аналогично перем-й выше
local makeActionInThisFrame=true	-- принимает истину когда истекает пауза, т.е. missFramesAfterOneAction=1
-- переменные для создания циклов
-- listOfItemsForSpeculation находится в listID.lua
local iterator_SpeculationItemsList = 1	-- итератор передеметов которые будут спекулироваться для цикла перебора itemID в списке listOfItemsForSpeculation : (файл listID.lua)
local activelyLoop_SpeculationItems = false	-- не используется ?????????????? зачем введена
local needQueryForSpeculItem = false	-- необходимо сделать запрос на сервер, чтобы потом обработать полученные данные. после запроса надо ждать неопределенное время о событии что ответ получен полностью и готов к обработке
local needWorkingQueryForSpeculItem = false	-- величина, обратная needQueryForSpeculItem. т.е. сначала делается запрос, затем запрос обрабатывается, затем следующий запрос. запрос делается на один конкретный итем
local interactBuyoutAccepting = false	-- флаг поднят когда появляется кнопка подтверждения покупки на ауке
local glBuyoutPrice = 0	-- эта переменная только для того чтобы передать цену в StaticPopupDialogs["PURCHASE_ITEM_CONFIRM"]

local iterator_AuctionResultsList = 0	-- итератор для цикла перебора в списке возвращаемом ф-ей вов QueryAuctionItems(name)
local activelyLoop_AuctionResults = false
-- обработка аукциона
local numBatchAuctions, totalAuctions, itemID
local currentPage,totalPages = 0,1

-- UnitGUID(\"unit\")
-- hasLoot, canLoot = CanLootUnit(unitGUID)
-- local name = UnitName("target"); unit_in_my_target_guid = UnitGUID("target"); ChatFrame1:AddMessage(name.." has the GUID: "..unit_in_my_target_guid);
-- /run local hL, cL = CanLootUnit(unit_in_my_target_guid); local hLt=0 cLt=0; if hL then hLt=1 else hLt=0 end; if cL then hLt=1 else cLt=0 end; ChatFrame1:AddMessage("can loot: "..hLt.." has loot: "..cLt);
-------- ФЛАГИ ---------------------------------------------------
	-- AH --
local AH_opened = false
local getNewItemID = false		-- поднимается когда нужно начать работу с новым итемом, то е. в самом начале и когда закончено сканирование предыдущего
local ahListUpdated = false		-- поднимается когда получен сигнал о полученной инфе на запрос о предмете в аукцион
local createAuctionItemslotChanged = false
local needSellToAhMyItems = false		-- поднимается когда была получена почта и пришло время выставить на аукцион предметы из сумок
local canSellToAH = false	-- флаг о том что можно выставлять товар на аукцион
	-- GB --
local GB_opened = false
	-- MailBox --
local mailbox_opened = false
------------------------------------------------------------------------

function AH_trader_Init(self)
			-- AH events
	frm_AH_trader:RegisterEvent("AUCTION_HOUSE_SHOW");
	frm_AH_trader:RegisterEvent("AUCTION_HOUSE_CLOSED");
	frm_AH_trader:RegisterEvent("AUCTION_ITEM_LIST_UPDATE");	-- Fires when the information becomes available for the list of auction browse/search results
	frm_AH_trader:RegisterEvent("NEW_AUCTION_UPDATE");	-- Fires when the content of the auction house's Create Auction item slot changes
			-- GB events
	frm_AH_trader:RegisterEvent("GUILDBANKFRAME_OPENED");
	frm_AH_trader:RegisterEvent("GUILDBANKFRAME_CLOSED");
			-- MailBox events
	frm_AH_trader:RegisterEvent("MAIL_SHOW");	-- 	Fires when the player begins interaction with a mailbox
	frm_AH_trader:RegisterEvent("MAIL_CLOSED");	-- 	Fires when the player ends interaction with a mailbox
	frm_AH_trader:RegisterEvent("MAIL_INBOX_UPDATE");	-- 	Fires when information about the contents of the player's inbox changes or becomes available
		-- MAIL_SEND_SUCCESS	Fires when an outgoing message is successfully sent
		-- UPDATE_PENDING_MAIL	Fires when information about newly received mail messages (not yet seen at a mailbox) becomes available
end

function AH_trader_Event(self, event, ...)
	--print("event happened:") 
	if(event=="AUCTION_HOUSE_SHOW") then 		AH_opened = true  getNewItemID = true	 needQueryForSpeculItem=true		canSellToAH = false		print("AH opened") end
	if(event=="AUCTION_ITEM_LIST_UPDATE") then 	ahListUpdated = true end	-- print("AH list updated")
	if(event=="AUCTION_HOUSE_CLOSED") then 		AH_opened = false 	ahListUpdated = false print("AH closed") end
	if(event=="NEW_AUCTION_UPDATE") then 			createAuctionItemslotChanged = true print("AH put item to trading") end
	if(event=="GUILDBANKFRAME_OPENED") then 	GB_opened = true 		print("GB opened") end
	if(event=="MAIL_SHOW") then 	mailbox_opened = true 		print("MailBox opened") end
	-- GET_ITEM_INFO_RECEIVED 
end

function AH_trader_OnUpdate(self)
	--print("updated..")
	if missFramesAfterOneAction > 2 then missFramesAfterOneAction=missFramesAfterOneAction-1 makeActionInThisFrame=false end
	if makeActionInThisFrame then
		--print("working..")
		local CanISendQuery,_=CanSendAuctionQuery("list")
		-- ------------------------------------- start main OnUpdate ------------------------------------------
		
		-- делать закупки на аукционе
		if AH_opened and (not interactBuyoutAccepting) and (not canSellToAH) then
			-- получить из списка новый номер итема
			if getNewItemID then
				-- print("0 - init start params for new item...")
				itemID = listOfItemsForSpeculation[iterator_SpeculationItemsList]
				iterator_SpeculationItemsList=iterator_SpeculationItemsList+1
				if iterator_SpeculationItemsList>#listOfItemsForSpeculation then
					iterator_SpeculationItemsList = 1
					-- CloseAuctionHouse()
					canSellToAH = true
				end
				currentPage = 0
				getNewItemID = false
				ahListUpdated = false
			end
			
			-- запрос на сервер, после этого ждать получение данных
			if needQueryForSpeculItem and CanISendQuery then 
				local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount = GetItemInfo(itemID)
				if sName then 
					-- print("1 - making query for ", sName, itemID, iterator_SpeculationItemsList,"currentPage=",currentPage)
					QueryAuctionItems(sName, nil, nil, currentPage, 0, 0, false, true, nil)	
					needQueryForSpeculItem = false
					ahListUpdated = false
				end
			end

			-- когда данные по итему получены надо поднять флаг что пора обрабатывать их и снять флаг что они уже получены
			if ahListUpdated and (not needWorkingQueryForSpeculItem) then 
				numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
				totalPages = math.ceil(totalAuctions / 50)
				--currentPage = 0
				-- print("2 - num auctions in current list=",numBatchAuctions,"  total auctions=", totalAuctions, "  totalPages=",totalPages)
				needWorkingQueryForSpeculItem = true 
				ahListUpdated = false
			end
			
			--print("3 - currentPage="..currentPage)
			-- 
			if needWorkingQueryForSpeculItem then
				--print("needWorkingQueryFor "..listOfItemsForSpeculation[iterator_SpeculationItemsList] )
				checkPriceAndBuyLot(iterator_AuctionResultsList)
				iterator_AuctionResultsList=iterator_AuctionResultsList+1
				--print("3 - iterator_AuctionResultsList "..iterator_AuctionResultsList)
				if iterator_AuctionResultsList>numBatchAuctions then 
					iterator_AuctionResultsList = 0
					-- нужен новый список лотов
					-- если лоты все прочеканы то или прочекать снова или завершить с текущим итемом и начать с новым
					defineQueryParams()
					needWorkingQueryForSpeculItem = false
					needQueryForSpeculItem=true
				end
			end
			-- activelyLoop_SpeculationItems
			-- make query for itemID
			missFrames = pauseAfterAhQuery
		end
		
		-- выставлять товар на аукцион
		if AH_opened and canSellToAH then
			canSellToAH = false
			missFrames = 1000
			--CloseAuctionHouse()
		end
		
		if GB_opened then
		
		end
		
		if mailbox_opened then
			-- запрос на сервер CheckInbox()
			-- сигнал что данные получены  MAIL_INBOX_UPDATE
			-- 
		end
		
		if needSellToAhMyItems then
		
		end
		
		-- -------------------------------------  end  main OnUpdate ------------------------------------------
	
		missFramesAfterOneAction = missFrames
	end
	makeActionInThisFrame=true
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------- FUNCTIONS -----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------
function defineQueryParams(itemID)
		if true then	-- needWorkingQueryForSpeculItem
			--print("next page .... or next item....")
			if currentPage then currentPage = currentPage + 1 end
			if currentPage and (currentPage >= totalPages) then
				needWorkingQueryForSpeculItem = false
				getNewItemID = true
			end
			--print("currentPage=",currentPage,"iterator_SpeculationItemsList=",iterator_SpeculationItemsList)
	--		printWowuctionDbForItemId(itemID)
		end

end

function checkPriceAndBuyLot(indexAhResultListID)
	local name, texture, count, quality, canUse, level, _, minBid, _, buyoutPrice, highestBidder, owner, sold = GetAuctionItemInfo("list", indexAhResultListID)
	glBuyoutPrice = buyoutPrice	-- эта строчка только для того чтобы перезать цену в StaticPopupDialogs["PURCHASE_ITEM_CONFIRM"]
	--print("buyoutPrice "..buyoutPrice)
	local buyoutPriceForOne = buyoutPrice/count
	local actualPrice = actualPriceFor(itemID)
	--print("PriceForOneItem "..buyoutPrice/count.."\n")
	if buyoutPriceForOne<(actualPrice*2/3) and buyoutPrice>0 then
		print("--->>> buyouting for "..buyoutPriceForOne.." actualPrice "..actualPrice)
		
		StaticPopup_Show("PURCHASE_ITEM_CONFIRM",buyoutPrice)	-- купить	, itemToPurchase
		interactBuyoutAccepting = true
		missFrames = pauseAfterBuyLot
	end
end

-- высплывающая кнопка подтверждения покупки на ауке
 StaticPopupDialogs["PURCHASE_ITEM_CONFIRM"] = {

     text = "%s",
     button1 = "Yes",
     button2 = "No",
     OnAccept = function() 
				print("lot num in list=",iterator_AuctionResultsList," placing price=",glBuyoutPrice)
         PlaceAuctionBid("list", iterator_AuctionResultsList-1, glBuyoutPrice)	-- здесь итератор должен быть уменьшен на 1, почему?
				interactBuyoutAccepting = false
     end,
		OnCancel = function()
				interactBuyoutAccepting = false
		end,
     timeout = 300,
     whileDead = false,
     hideOnEscape = true,
 }

function actualPriceFor(itemID)
	--local itemID = listOfItemsForSpeculation[iterator_SpeculationItemsList]
	--print("itemID in actualPriceFor() "..itemID)
	-- запрос в таблицу взятую с сайта WOWUction.com
--	local realmTable=dbWowUction_com["Свежеватель Душ"]
--	local medianPrice = realmTable.alliance[itemID].medianPrice
--	local medianPriceErr = realmTable.alliance[itemID].medianPriceErr
	local realmTable=dbWowUction_com["Гордунни"]
	local medianPrice = realmTable.alliance[itemID].medianPrice
	--print("medPriceOfItem = ", medianPrice)
	
	return medianPrice
end

-------------------------------------------------- old functions------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

function getTablePriceQuantityForItemId(itemID)
	
	if ahListUpdated then

		
		for i=1, totalAuctions do
			-- local name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("type", index)
			
			
			ahListUpdated = false	-- <-- ????????????????????????????????????????????????????????????????/
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------
function printingListOfItems()
	print("list of items in listID.lua:") 
	for a=1,#listOfItemsForSpeculation do
		local itemID=listOfItemsForSpeculation[a]
		local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount = GetItemInfo(itemID)
		print("\n",a, "-th itemID in list is ", itemID, sLink, " # = ", #listOfItemsForSpeculation)
		printWowuctionDbForItemId(itemID)
		--f listOfItemsForSpeculation[a]==theItem then 
			-- print("the white crap true->", theItem, " vs ", listOfCrapWhiteItems[a], " in ", a)
		--	return true
		--end 
	end
end

function printWowuctionDbForItemId(itemID)
	-- TSM.data = {  ["Свежеватель Душ"] = {    lastUpdate = 1462719229,    alliance = {      [25] = {marketValue=0, minBuyout=0, medianPrice=0, marketValueErr=0, medianPriceErr=0, regionMarketValue=61826600, regionMarketValueErr=12123200, regionMedianPrice=55098400, regionMedianPriceErr=12401099, regionAvgDailyQuantity=0.43},
	--print ("1: ", dbWowUction_com)
	local realmTable=dbWowUction_com["Гордунни"]
	--print ("2: ", realmTable)
--	local timeOfGetDB=realmTable["lastUpdate"]
	--print ("datatime: ", timeOfGetDB)
--	local ahTable=realmTable["alliance"]
	--print ("3: ", ahTable)
	--print ("itemID: ", itemID)
--	local itemTable = ahTable[tonumber(itemID)]
	--print ("4: ", itemTable)
--	local quantity = itemTable["regionAvgDailyQuantity"]
--	local avgPrice = itemTable["regionMedianPrice"]
--	local medPrice = itemTable["medianPrice"]
--	print ("regionAvgDailyQuantity: ", quantity ," for average price: ", avgPrice, " and median price: ", medPrice)
	-- print("medPriceOfItem = ", dbWowUction_com.realm.faction.itemID.medPriceOfItem)
	print("medPriceOfItem = ", realmTable.alliance[itemID].regionMedianPrice)
end