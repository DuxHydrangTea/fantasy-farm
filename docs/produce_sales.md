# Produce buyer

`ProduceBuyer` is a separate NPC immediately to the right of LaiBuon. Its
interaction point is 16 world pixels to the right of LaiBuon's interaction
point, at `(1757, 224)`. It uses the Farmer Buba sprite to distinguish it from
LaiBuon's Fisherman Fin sprite. Face the desired NPC and press E, or click its sprite to approach and open its
menu. The shared resolver highlights one eligible target and shows `Sell produce`
for this buyer; see [unified interaction](unified_interaction.md).

The buyer accepts the 42 products listed in
`resources/shops/produce_prices.tres`: 22 harvested crops, 10 harvested flowers
7 animal products and 3 types of honey. The catalog is a typed `ProducePriceCatalog`, containing
`ProducePrice` resources with an ItemDefinition and integer unit price. Seeds,
feed, tools and unknown products are outside this catalog.

Two actions are available:

- **Sell quantity:** choose a product, enter a positive whole quantity, then
  press the button showing that quantity and its total price. Items can span
  multiple inventory stacks. Quantities exceeding current stock are rejected.
- **Sell all produce:** sell every accepted product currently in the bag,
  including other product types. The button previews the combined price and
  its tooltip explains the scope or why the action is unavailable.

Prices are fixed. For example, carrots sell for 5 coins each, wheat for 4,
pumpkins for 18, harvested flowers for 20, chicken eggs for 8, cow milk for 24,
wool for 30 and truffles for 40. Adjust the catalog in Godot's Inspector to
rebalance; IDs and save data do not need changing.

`ProduceSaleService` stages a full copy of the bag, validates accepted product
IDs/types, stock and wallet capacity, then replaces the bag and credits the
wallet as one transaction. Observers see both models updated; reentrant sale
commands are blocked. If the wallet cannot hold the whole payment, no part of
the batch is sold. Each click checks current stock again; quotes are previews.

`TradeMenu` shares the modal lifecycle between ShopUI and ProduceSalesUI:
opening blocks world/inventory actions, closing releases the lock, and removing
the NPC or loading a save closes safely. Successful trades trigger thanks only
when the player ends the visit. Buyer and supplier keep separate catalogs and
commands. Existing `ShopMerchant.shop_ui` remains available for ShopUI scenes;
`ShopMerchant.menu` points to the active typed TradeMenu specialization.

The sales menu uses the independent UIScaleComponent, a scrolling item list,
scrolling details and two fixed action rows. English is the default; all new
messages also have Vietnamese translations. Selection and quantity survive
resizing and locale changes.

Wallet and remaining inventory already belong to the world save, so selling
produce requires no save schema migration. Tests cover multi-stack sales, bulk
sales, invalid/changed stock, exclusions, wallet overflow, reentry, typed input,
small-window clicks, both adjacent NPCs and save/load after a sale.

The catalog now includes Wild Honey (150 coins), Sunflower Honey (225) and Floral
Honey (300), bringing accepted products to 42. Hive items cannot be sold as
produce. See [beehives](beehives.md).
