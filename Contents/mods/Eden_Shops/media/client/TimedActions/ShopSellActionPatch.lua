
--the code on this lua file is made by Xyberviri

require "TimedActions/ISBaseTimedAction"
local Nfunction = require "Nfunction"

function ShopSellAction:perform()
    local cartItems = self.shopUI.cartItems.items
    local playerInv = self.character:getInventory()
    local inventoryItems = {}
    local inventory = self.character:getInventory():getItems()
    for i = 0, inventory:size() -1 do
        local item = inventory:get(i)
        if not (item:isEquipped() or item:isFavorite()) then
            inventoryItems[item:getID()] = item
        end
    end
    local total = 0
    local totalSpecial = 0
    for k,v in pairs(cartItems) do
        local item = v.item
        local invItem = inventoryItems[item.id]
        if invItem then
            item.price = Nfunction.drainablePrice(invItem,item.priceFull)
            if item.specialCoin then
                totalSpecial = totalSpecial + item.price
            else
                total = total + item.price
            end
            if SandboxVars.Shops.SellLog then Nfunction.buildLogShop(invItem:getFullType()) end
            invItem:getContainer():Remove(invItem)
        end
    end
    local shopSquare = self.shop:getSquare()
    local coords = {
        x = shopSquare:getX(),
        y = shopSquare:getY(),
        z = shopSquare:getZ(),
    }
    if SandboxVars.Shops.SellLog then Nfunction.logShop(coords,"Sell") end
    local playerInv = self.character:getInventory()
-----------------------------------------------------------------
--           Patch this to be less Brrr because why not        --
-----------------------------------------------------------------
--[[Edit:Old Method
    if total > 0 then
        playerInv:AddItems(Currency.BaseCoin,total);

    end
]]--
--New Method
   while total > 0 do
        local max = 0
        local maxType = ""
        for itemType, data in pairs(Currency.Coins) do
            if total >= data.value and data.value >= max then
                max = data.value
                maxType = itemType
            end
        end
        if max == 0 then return end
        if maxType == "Base.Money" then return end --Probably not going to happen but just in case.

        --Optimized:
        local maxCount = math.floor(total / max)
        playerInv:AddItems(maxType,maxCount)
        total = total - (max*maxCount)

    end
-----------------------------------------------------------------
--                                          --Xyberviri#5609   --
-----------------------------------------------------------------
    if totalSpecial > 0 then
        playerInv:AddItems(Currency.SpecialCoin,totalSpecial);
    end
    if total > 0 or totalSpecial > 0 then self.character:playSound("CashRegister") end
    self.shopUI.cartItems:clear()
    ISBaseTimedAction.perform(self)
end