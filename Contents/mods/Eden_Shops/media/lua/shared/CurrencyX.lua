

Currency = Currency or {}

Currency.Wallets = {}


local list = SandboxVars.EdenShops.Wallets or  "Base.CreditCard;Base.Wallet;Base.KeyRing"



-----------------------            ---------------------------
Currency.BaseCoin = "Base.Money"
Currency.SpecialCoin = "Base.EdenCoin"

Currency.UseSpecialCoin = true
Currency.Coins[Currency.SpecialCoin] = {value = 0, specialCoin = true}
Currency.Coins[Currency.BaseCoin] = {value = 1}


Currency.CoinsTexture = {
	Coin = {
		texture = getTexture("media/textures/Item_Money.png"),
		scale = 15
	},
	SpecialCoin = {
		texture = getTexture("media/textures/Item_EdenCoin.png"),
		scale = 15
	},
}

local function isDBG()
	local dbg = false
	if getCore():getDebug() and isAdmin() then
		dbg = SandboxVars.EdenShops.DBG
	end
	return dbg
end

Events.OnCreatePlayer.Add(function()
	local items = {}

	for item in string.gmatch(list, "[^;]+") do
		Currency.Wallets[item] = true
		if isDBG() then
			print(item)
		end
	end
end)
