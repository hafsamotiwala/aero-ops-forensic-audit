# AeroOps: Flight Telemetry & Multi-Domain Operations Leakage Engine 

An enterprise-grade analytical data warehouse auditing over **513,000 active commercial flight records** integrated relationally with the official **ICAO Aircraft Engine Emissions Databank**. This project applies forensic SQL analytics to expose hidden operational cash drains, environmental carbon tax liabilities, retail catering spoilage, and fleet supply chain bottlenecks across the commercial aviation network.

---

##  Multi-Domain Operations Architecture

```text
                           ┌────────────────────────────────────────┐
                           │   AEROOPS PERFORMANCE DATA WAREHOUSE   │
                           └───────────────────┬────────────────────┘
                                               │
         ┌───────────────────┬─────────────────┼──────────────────┬──────────────────┐
         ▼                   ▼                 ▼                  ▼                  ▼
  [DOMAIN A: FUEL]   [DOMAIN B: SUPPLY] [DOMAIN C: FOOD]   [DOMAIN D: CREW]   [DOMAIN E: FLIGHTS]
  • Taxi-Out Bleeds   • Trapped Capital  • Spoilage Rates  • Deadhead Ratios  • Cancellation Logs
  • Carbon Penalties  • AOG Leakages     • Margin Paradox  • Compliance Lags  • Sunk Revenue
```

---

##  Tech Stack & Warehouse Architecture
*   **Data Processing:** Python (Pandas) / latin1 stream optimization, data type casting, and duplicate removal handling.
*   **Database Engine:** MySQL Server 8.0 (Advanced CTEs, Mathematical Window Functions, and `LOAD DATA INFILE` automation).
*   **Data Modeling Standard:** Optimized Star Schema design built for sub-second executive aggregations.

###  Relational Schema Map

```text
    ┌─────────────────────────┐             ┌─────────────────────────┐
    │     dim_engine          │             │    dim_aircraft         │
    │   (Engine Specs Dim)    │             │   (Aircraft Fleet Dim)  │
    └────────────┬────────────┘             └────────────┬────────────
                 │                                       │
                 └───────────────────┬───────────────────┘
                                     │ (Linked via relational keys)
                                     ▼
                        ┌─────────────────────────┐
                        │     fact_flights        │
                        │    (Core Flight Fact)   │
                        └─────────────────────────┘
```

---

##  Core Operational Visualizations & Insights

### 1. Ground Fuel Burnout & Cash Destruction (Domain A)
By enforcing a **4-minute mandatory engine stabilization buffer**, this audit exposes the exact cost of traffic congestion, stripping away the visual insulation of traditional "On-Time" schedules.

| Airline | Monitored Flights | Avg Taxi-Out Mins | Total Wasted Fuel (kg) | Total Financial Loss (USD) |
| :--- | :--- | :--- | :--- | :--- |
| **AA** | 144 | 19.56 | 68,946 | \$68,489.00 |
| **DL** | 104 | 22.86 | 50,319 | \$49,985.66 |
| **UA** | 80 | 20.46 | 33,054 | \$32,834.89 |
| **WN** | 146 | 11.69 | 27,937 | \$27,751.66 |

```text
Airlines Ground Cash Destruction (USD)
======================================
AA  [████████████████████████████████] \$68,489.00
DL  [███████████████████████] \$49,985.66
UA  [██████████████] \$32,834.89
WN  [████████████] \$27,751.66
```

### 2. The Perishable Catering Margin Paradox (Domain C)
Short-haul, Buy-on-Board (BoB) meal programs face a brutal **54% to 57% weekly spoilage rate** due to card-payment friction and narrow cabin service windows. This simulation replaces fresh food with non-perishable options, mirroring the **flynas** operational framework.

| Airline | Fresh Meals Loaded | Total Meals Sold | Current Fresh Margin (USD) | Simulated Packaged Margin (USD) | Capital Reclaimed (USD) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DL** | 667,100 | 92,812 | -\$1,888,206.00 | +\$696,090.00 | **+\$2,584,296.00** |
| **AA** | 596,682 | 83,002 | -\$1,689,045.00 | +\$622,515.00 | **+\$2,311,560.00** |

### 3. Out-of-Stock Hangar AOG Revenue Leakages (Domain B)
When critical components run out of stock locally, aircraft sit grounded in **AOG (Aircraft on Ground)** status, bleeding an asset-inactivity penalty of **\$25,000.00 USD per day**.

```text
Out-of-Stock AOG Revenue Revenue Losses (USD)
==============================================
ORD (Chicago O'Hare)    [██████████████████████████████] \$1,500,000.00
DFW (Dallas/Fort Worth) [█████████████████████████] \$1,275,000.00
ATL (Hartsfield-Jackson)[█████████████████████] \$1,075,000.00
```

---

##  Repository Folder Structure
```text
├── README.md
└── /scripts
    ├── 01_warehouse_ingestion.sql  # Database init, Star Schema DDL, and Infile loads
    ├── 02_fuel_leakage_audit.sql   # Taxi delays, engine wide-body metrics, carbon tax
    ├── 03_retail_catering_audit.sql# Retail food loops, waste tracking, margin paradox
    ├── 04_crew_compliance_audit.sql# Positioning deadhead revenue loss, data sync lags
    └── 05_fleet_supply_chain.sql   # ABC inventory analysis, AOG leaks, automated ROP triggers
```

---

##  Deployment Instructions
1. Run the script inside `/data_pipeline` to filter out unused columns from the raw source files.
2. Open MySQL Workbench and run `scripts/01_warehouse_ingestion.sql` to deploy base tables and establish references.
3. Move your optimized data files directly to your server's secure local path (`secure_file_priv`).
4. Execute individual analytics blocks inside the `/scripts` directory sequentially to generate executive telemetry performance metrics.
