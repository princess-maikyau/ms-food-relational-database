# Relational Database Design

*SQLite database and business-question SQL for an M&S Food cold-chain case study*

A 9-entity, 3NF relational database modelling a supermarket food retailer's cold-chain supply, inventory, and sales operations, with SQL queries answering seven business questions on waste, stockouts, and supplier cold-chain performance — built for the *Data Management* module of Warwick Business School's MSc Business Analytics.

## Business problem

A food retailer (modelled on M&S Food) needs to understand where it's losing money to spoilage and stockouts, and whether those losses trace back to supplier cold-chain reliability. Doing that requires a schema that connects four things that are usually tracked separately: what's in stock store-by-store, what's being sold, what suppliers are delivering (and how reliably, temperature-wise), and what ends up wasted.

## Schema

Nine entities in third normal form (3NF) — see [`assets/erd_diagram.jpg`](assets/erd_diagram.jpg) for the full entity-relationship diagram:

| Entity | Purpose |
|---|---|
| `Store` | Store locations, type, region |
| `Supplier` | Supplier details, cold-chain certification, contract dates, tier rating |
| `Category` | Product category, temperature zone, typical shelf life |
| `Product` | SKU-level catalogue: category, supplier, cost/retail price, storage temperature range |
| `Customer` | Customer postcode district, registration, age band, preferred store |
| `Inventory` | Daily store × product snapshots: stock on hand, reorder point, waste units, stockout flag |
| `Delivery` | Supplier → store deliveries: scheduled vs. actual date, delay, arrival temperature, rejected units |
| `DeliveryLine` | Line-item detail within each delivery: units ordered/received, expiry date, temperature-excursion flag |
| `SalesTransaction` | Store-level sales: product, customer, units sold, price, promotion flag |

The database ships here as a ready-to-query SQLite file (`db/ms_food.db`) with synthetic data sized for coursework use (500 stores, 500 suppliers, 800 products, 1,000 customers, 5,500 sales transactions, 1,300 deliveries, and 27,000 inventory snapshots).

## Business questions & key findings

All seven queries are in [`queries/analysis_queries.sql`](queries/analysis_queries.sql) and run directly against `db/ms_food.db`.

1. **Highest total waste (units & cost)** — a small set of SKUs drives a disproportionate share of waste cost; the top item alone accounts for over £5,000 in wasted stock.
2. **Highest stockout frequency** — stockout rates across the top SKUs cluster around 2–3% of store-days, concentrated in a handful of products rather than spread evenly.
3. **High waste *and* high stockout risk** — cross-referencing (1) and (2) surfaces SKUs that are simultaneously over-ordered (driving waste) and under-available (driving stockouts) — a sign of demand-forecasting or replenishment-cadence problems rather than pure demand volatility.
4. **On-time delivery performance by supplier** — on-time rates for the weakest suppliers fall as low as ~58%, well below what a cold-chain food business can safely plan around.
5. **Temperature excursion rate by supplier** — some suppliers show temperature-excursion rates above 70% of delivery lines, a direct food-safety and shelf-life risk.
6. **Mean & variance of delivery delay by supplier** — ranks suppliers not just on average delay but on *consistency*; several suppliers with middling average delays show very high variance, meaning delivery timing is unpredictable even when it's acceptable on average.
7. **Composite cold-chain supplier tiering** — combines on-time rate, excursion rate, and delay variance into a single weighted score to classify every supplier into Tier 1/2/3, giving procurement a single ranked view instead of three separate metrics to reconcile by hand.

Together, these turn four operational data streams (inventory, sales, deliveries, delivery-line detail) into a single diagnostic: which products are losing money, and which suppliers are the likely root cause.

## Repository structure

```
db/
  ms_food.db              # SQLite database (schema + synthetic data)
queries/
  analysis_queries.sql    # The 7 business-question SQL queries
assets/
  erd_diagram.jpg         # Entity-relationship diagram
```

## Running it

No setup required beyond SQLite (built into Python's standard library):

```bash
sqlite3 db/ms_food.db < queries/analysis_queries.sql
```

or, from Python:

```python
import sqlite3
con = sqlite3.connect("db/ms_food.db")
for row in con.execute("SELECT * FROM Supplier LIMIT 5"):
    print(row)
```

## Tech stack

SQLite · SQL (CTEs, window-style aggregation, composite scoring)

> **Disclaimer:** not affiliated with or endorsed by Marks & Spencer. M&S Food is used only as a case-study setting; all data in this repository is synthetic.

## Attribution

**Team project.** Completed as group coursework (Group 35, Data Management, MSc Business Analytics, Warwick Business School). The code and analysis in this repository are the team's shared work, published with full credit to the group to show the project; this is not a claim of sole authorship.

## License

MIT — see [LICENSE](LICENSE).
