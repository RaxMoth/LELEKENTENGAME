# Customer area — the back window

Customers queue in the back yard; the player sets prices and sells or
declines at the window. Sales earn cash and reputation and add heat.

## What this area owns

| Files | What |
|---|---|
| `SalesWindow.tscn`, `sales_window.gd` | The front: queue, the sale rules (accept / counter / refuse), dealers, score from sales |
| `customer_flow.gd` | Who comes when: day / night rates, reputation, prices → demand, customer type gates |
| `Customer.tscn`, `customer.gd` | A pooled customer (walk, wait, leave) with an order bubble and patience bar |
| `SalesBoard.tscn`, `sales_board.gd` | The board inside the window |
| `Ressources/Customers/` | Customer types (wants, budget, haggling, patience, weights, gates) |
| `Ressources/Upgrades/Sales/` | Sales upgrades + `sales_upgrades.tres` catalog |
| `Scripts/Game/sales_math.gd`, `customer_order.gd` | Pure sale rules (unit-tested in `Tests/Unit/operation_math_test.gd`) |
| `Tests/Smoke/sales_checks.gd` | This area's smoke checks |

## What it uses from outside

`context.operation` (`get_unlocked_recipes`, prices, `get_deliverable_tier`,
`complete_sale`, `get_upgrade_value(Types.UPGRADE_QUEUE / PATIENCE)`),
`context.day_cycle` (day / night), `context.rig` (the board is a
WorldScreen — pointers click it on their own). Nothing else.

## Adding things

- **Customer type:** a `CustomerTypeData` in `Ressources/Customers/`, add it
  to `CustomerFlow.customer_types` in `SalesWindow.tscn`.
- **Sale rule:** pure math in `SalesMath` (with a unit test), used by
  `SalesWindow`.
- **Upgrade:** `UpgradeData` in `Ressources/Upgrades/Sales/`, add it to
  `sales_upgrades.tres`, id in the Sales block of `Types`.
