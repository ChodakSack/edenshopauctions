
-- AuctionHouseNPC.lua
-- Adds Auctioneer NPC to open the Auction House

require "AuctionHouse"

local function OpenAuctionHouse()
    AuctionHouse.Open()
end

-- Example: Add Auctioneer NPC at a fixed tile
local function SpawnAuctioneer()
    local square = getCell():getGridSquare(6500, 5300, 0) -- Example coords
    if not square then
        print("[AuctionHouseNPC] ERROR: Could not find square to place Auctioneer NPC.")
        return
    end

    local npc = IsoMannequin.new(nil, "Auctioneer", nil)
    square:AddSpecialObject(npc)
    print("[AuctionHouseNPC] Auctioneer NPC spawned at 6500x5300x0.")

    -- Add context menu on right-clicking the NPC
    Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
        for _, obj in ipairs(worldobjects) do
            if obj == npc then
                context:addOption("Open Auction House", obj, function()
                    OpenAuctionHouse()
                end)
            end
        end
    end)
end

Events.OnGameStart.Add(SpawnAuctioneer)
