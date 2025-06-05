
-- 📌 Adds "Auction House" to right-click context menu on tiles that support it

local function isAuctionTile(square)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local validTiles = {
        ["10640_9613"] = true, -- Example tile
    }
    return validTiles[x .. "_" .. y] or false
end

Events.OnFillWorldObjectContextMenu.Add(function(playerIndex, context, worldobjects, test)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    for _, obj in ipairs(worldobjects) do
        local square = obj:getSquare()
        if square and isAuctionTile(square) then
            context:addOption("Open Auction House", square, function()
                local x, y = square:getX(), square:getY()
                local key = "AuctionHouse_" .. x .. "_" .. y
                local listings = ModData.getOrCreate(key)
                ISTimedActionQueue.add(OpenAuctionHouseAction:new(player, listings, key))
            end)
        end
    end
end)

-- Auction House Action & UI
OpenAuctionHouseAction = ISBaseTimedAction:derive("OpenAuctionHouseAction")

function OpenAuctionHouseAction:new(character, listings, key)
    local o = ISBaseTimedAction.new(self, character)
    o.listings = listings
    o.key = key
    return o
end

function OpenAuctionHouseAction:perform()
    AuctionHouseUI:show(self.character, self.listings, self.key)
    ISBaseTimedAction.perform(self)
end

AuctionHouseUI = {}

function AuctionHouseUI:show(player, listings, key)
    local modal = ISTextBox:new(100, 100, 400, 400, "Auction House", "Select an option:", nil, nil, nil)
    modal.entry:setVisible(false)

    local function drawListings()
        local listText = ""
        for i, entry in ipairs(listings) do
            listText = listText .. string.format("%d. %s x%d - $%d (Seller: %s)
", i, entry.item, entry.count, entry.price, entry.seller)
        end
        return listText == "" and "No listings." or listText
    end

    modal:setOnlyNumbers(false)
    modal:setValidateFunction(nil)
    modal:setTargetFunc(function(button, text)
        if button.internal == "OK" then
            AuctionHouseUI:showOptions(player, listings, key)
        end
    end)
    modal:setText(drawListings())
    modal:addToUIManager()
end

function AuctionHouseUI:showOptions(player, listings, key)
    local modal = ISTextBox:new(100, 100, 400, 200, "Auction Options", "Type: 'list' to sell, number to buy.", nil, nil, nil)
    modal:setTargetFunc(function(button, input)
        if button.internal ~= "OK" then return end
        if input == "list" then
            AuctionHouseUI:listItem(player, listings, key)
        else
            local index = tonumber(input)
            if index and listings[index] then
                AuctionHouseUI:buyItem(player, listings, key, index)
            end
        end
    end)
    modal:addToUIManager()
end

function AuctionHouseUI:listItem(player, listings, key)
    if not AuctionHouseUI:canListMore(player) then
        player:Say("You’ve reached your listing limit (30 items).")
        return
    end
    local inventory = player:getInventory():getItems()
    
    if inventory:size() == 0 then
        player:Say("You have nothing to list.")
        return
    end

    local options = {}
    for i = 0, inventory:size() - 1 do
        local item = inventory:get(i)
        table.insert(options, item:getName())
    end

    local modal = ISTextBox:new(100, 100, 300, 150, "Select Item", "Type item number to list:\n" .. table.concat(options, "\n"), nil, nil, nil)
    modal:setTargetFunc(function(button, input)
        if button.internal ~= "OK" then return end
        local index = tonumber(input)
        if not index or index < 1 or index > #options then
            player:Say("Invalid selection.")
            return
        end
        local selectedItem = inventory:get(index - 1)
        AuctionHouseUI:askPrice(player, listings, key, selectedItem)
    end)
    modal:addToUIManager()
    return
    
        player:Say("You have nothing to list.")
        return
    end

    local modal = ISTextBox:new(100, 100, 300, 150, "Set Price", "Enter price for " .. firstItem:getName(), nil, nil, nil)
    modal:setTargetFunc(function(button, input)
        if button.internal ~= "OK" then return end
        local price = tonumber(input)
        if not price then
            player:Say("Invalid price.")
            return
        end

        table.insert(listings, {
            seller = player:getUsername(),
            item = firstItem:getFullType(),
            count = 1,
            price = price
        })

        player:getInventory():Remove(firstItem)
        ModData.transmit(key)
        player:Say("Listed " .. firstItem:getName() .. " for $" .. price)
    end)
    modal:addToUIManager()
end

function AuctionHouseUI:buyItem(player, listings, key, index)
    local entry = listings[index]
    if not entry then return end

    local money = CurrencyX.getBalance(player)
    if money < entry.price then
        player:Say("Not enough money.")
        return
    end

    CurrencyX.addBalanceByUsername(entry.seller, entry.price)
    CurrencyX.addBalance(player, -entry.price)
    player:getInventory():AddItem(entry.item)
    table.remove(listings, index)
    ModData.transmit(key)
    player:Say("Purchased " .. entry.item .. " for $" .. entry.price)
end

function AuctionHouseUI:askPrice(player, listings, key, selectedItem)
    local modal = ISTextBox:new(100, 100, 300, 150, "Set Price", "Enter price for " .. selectedItem:getName(), nil, nil, nil)
    modal:setTargetFunc(function(button, input)
        if button.internal ~= "OK" then return end
        local price = tonumber(input)
        if not price then
            player:Say("Invalid price.")
            return
        end

        table.insert(listings, {
            seller = player:getUsername(),
            item = selectedItem:getFullType(),
            count = 1,
            price = price
        })

        player:getInventory():Remove(selectedItem)
        ModData.transmit(key)
        player:Say("Listed " .. selectedItem:getName() .. " for $" .. price)
    end)
    modal:addToUIManager()
end


ISAuctionHouseWindow = ISPanel:derive("ISAuctionHouseWindow")

function ISAuctionHouseWindow:initialise()
    ISPanel.initialise(self)
    self.listBox = ISScrollingListBox:new(10, 30, self.width - 20, self.height - 60)
    self.listBox:initialise()
    self.listBox:instantiate()
    self.listBox.doDrawItem = self.drawItem
    self.listBox.drawBorder = true
    self:addChild(self.listBox)

    self.buyButton = ISButton:new(self.width / 2 - 40, self.height - 25, 80, 20, "Buy", self, ISAuctionHouseWindow.onBuy)
    self.buyButton:initialise()
    self:addChild(self.buyButton)
end

function ISAuctionHouseWindow:setData(player, listings, key)
    self.player = player
    self.listings = listings
    self.key = key
    self.listBox:clear()
    for i, entry in ipairs(listings) do
        local item = InventoryItemFactory.CreateItem(entry.item)
        self.listBox:addItem(entry.item, {
            index = i,
            displayName = item:getName(),
            texture = item:getTex(),
            count = entry.count,
            price = entry.price,
            seller = entry.seller,
        })
    end
end

function ISAuctionHouseWindow:drawItem(y, item, alt)
    local a = 0.9
    self:drawRectBorder(0, y, self.listBox.width, 40, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local entry = item.item
    if entry.texture then
        self:drawTextureScaled(entry.texture, 5, y + 5, 30, 30, 1)
    end
    self:drawText(entry.displayName .. " x" .. entry.count, 45, y + 5, 1, 1, 1, a, UIFont.Small)
    self:drawText("Price: $" .. entry.price .. " | Seller: " .. entry.seller, 45, y + 20, 0.8, 0.8, 0.8, a, UIFont.Small)
    return y + 40
end

function ISAuctionHouseWindow:onBuy()
    local selected = self.listBox.selected
    if not selected then return end
    local index = self.listBox.items[selected].item.index
    AuctionHouseUI:buyItem(self.player, self.listings, self.key, index)
    self:setVisible(false)
    self:removeFromUIManager()
end

AuctionHouseUI.show = function(player, listings, key)
    local w, h = 400, 400
    local win = ISAuctionHouseWindow:new(100, 100, w, h)
    win:initialise()
    win:addToUIManager()
    win:setData(player, listings, key)
end

function AuctionHouseUI:canListMore(player)
    local username = player:getUsername()
    local totalListings = 0
    for k, v in pairs(ModData.getTable()) do
        if string.startswith(k, "AuctionHouse_") then
            for _, entry in ipairs(v) do
                if entry.seller == username then
                    totalListings = totalListings + 1
                end
            end
        end
    end
    return totalListings < 30
end


function ISAuctionHouseWindow:initialise()
    ISPanel.initialise(self)

    self.searchBox = ISTextEntryBox:new("", 10, 5, self.width - 20, 20)
    self.searchBox:initialise()
    self.searchBox:instantiate()
    self.searchBox:setClearButton(true)
    self.searchBox.onTextChange = function() self:filterListings() end
    self:addChild(self.searchBox)

    self.listBox = ISScrollingListBox:new(10, 30, self.width - 20, self.height - 80)
    self.listBox:initialise()
    self.listBox:instantiate()
    self.listBox.doDrawItem = self.drawItem
    self.listBox.drawBorder = true
    self:addChild(self.listBox)

    self.buyButton = ISButton:new(self.width / 2 - 40, self.height - 40, 80, 20, "Buy", self, ISAuctionHouseWindow.onBuy)
    self.buyButton:initialise()
    self:addChild(self.buyButton)
end

function ISAuctionHouseWindow:filterListings()
    local query = self.searchBox:getInternalText():lower()
    self.listBox:clear()
    for i, entry in ipairs(self.listings) do
        local item = InventoryItemFactory.CreateItem(entry.item)
        if item:getName():lower():find(query, 1, true) then
            self.listBox:addItem(entry.item, {
                index = i,
                displayName = item:getName(),
                texture = item:getTex(),
                count = entry.count,
                price = entry.price,
                seller = entry.seller,
            })
        end
    end
end


function AuctionHouseUI:askPrice(player, listings, key, selectedItem)
    local modal = ISTextBox:new(100, 100, 300, 150, "Set Quantity", "Enter quantity to sell (max: " .. selectedItem:getContainer():getItems():getNumItems(selectedItem:getFullType()) .. ")", nil, nil, nil)
    modal:setTargetFunc(function(button, inputQty)
        if button.internal ~= "OK" then return end
        local qty = tonumber(inputQty)
        if not qty or qty < 1 then
            player:Say("Invalid quantity.")
            return
        end

        local priceModal = ISTextBox:new(100, 100, 300, 150, "Set Price", "Enter price for " .. qty .. "x " .. selectedItem:getName(), nil, nil, nil)
        priceModal:setTargetFunc(function(btn, inputPrice)
            if btn.internal ~= "OK" then return end
            local price = tonumber(inputPrice)
            if not price then
                player:Say("Invalid price.")
                return
            end

            table.insert(listings, {
                seller = player:getUsername(),
                item = selectedItem:getFullType(),
                count = qty,
                price = price
            })

            for i = 1, qty do
                local itemToRemove = player:getInventory():FindAndReturn(selectedItem:getFullType())
                if itemToRemove then
                    player:getInventory():Remove(itemToRemove)
                end
            end

            ModData.transmit(key)
            player:Say("Listed " .. qty .. "x " .. selectedItem:getName() .. " for $" .. price)
        end)
        priceModal:addToUIManager()
    end)
    modal:addToUIManager()
end

require "AuctionHouseNPC"
