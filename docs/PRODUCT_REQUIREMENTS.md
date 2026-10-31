# AWTAD RETAIL — Product Scope and Execution

Canonical product-scope and execution document for this repository.

This file is the single source of truth for recovered requirements, repository evidence, status, and the remaining implementation sequence. It does not replace code. If this document and the code disagree, the code is the current implementation; this document records the intended product scope and the gap.

## 1. Document control

| Field | Value |
| --- | --- |
| Status | Recovered draft, reconciled with verified reports and settings default-currency UI. Documentation only. Not an implementation approval. |
| Created from | Branch `m1-customer-flow-verify`, original inspect HEAD `94405fbfddd054eeafc345791ffbf49f11ad87a9` |
| Reconciled to | HEAD `bc3a90096ed3e16046799b5bd6b2a6a5040897d2` (`feat(settings): add default-currency selector`; parent `9c50c15`) |
| Inspected on | 2026-10-25 |
| Working tree | As of this documentation update: branch `m1-customer-flow-verify` was at `da88249` and in sync with origin; this file was already tracked. This row is a snapshot, not a live tracking field. |
| PR | [#1](https://github.com/tahaalialyatim-wq/-taha/pull/1) OPEN, MERGEABLE. |
| CI evidence | Latest PR CI on `da88249`: [41220520126](https://github.com/tahaalialyatim-wq/-taha/actions/runs/41220520126). `flutter analyze` step conclusion success; log **No issues found!** (9.5s). Historical: `flutter test` **84 passed** on `bc3a900` ([41147675989](https://github.com/tahaalialyatim-wq/-taha/actions/runs/41147675989)). Earlier: `40214398790` / `40214383695` on `9c50c15` (75 passed); `40212555902` on `8d557db` (71 passed); `40208327314` on `94405fb` (68 passed). |
| APK | `.github/workflows/android-apk.yml` builds on push to `main` only. Skipped on pull requests. Not authorized from this document. Local APK cannot be produced in this environment (`apps/awtad_mobile/README.md`). |

### How to read status

| Status | Meaning |
| --- | --- |
| VERIFIED | Present in the repository and covered by tests and/or a named CI run. |
| IMPLEMENTED | Present in the repository without dedicated verification named below. |
| PARTIAL | Some of the requirement exists; a named gap remains. |
| STUB | A type, identifier, or comment exists; no workflow. |
| UNREACHABLE | No implementation path in the current tree. |
| PLANNED | Recovered from prior product discussion or this recovery directive. No repository evidence that it was implemented or that a later milestone approved it. |
| DEFERRED | Known, intentionally not in the current authorized implementation slice. |

Conversation claims are labeled **recovered intent**. They are not treated as proof of the current mobile implementation.

Do not treat exploratory ideas as approved commitments. Contacts picker and Android `READ_CONTACTS` are **not** approved scope.

## 2. Inspected documentation

| Path | Role |
| --- | --- |
| `apps/awtad_mobile/README.md` | Mobile client layout, SQLite sales UoW, external APK instructions. Not a product roadmap. |
| Repository root | This file is the product-scope source of truth. No other roadmap or milestone notes. |
| `.github/workflows/m1-customer-tests.yml` | Analyze + test on `workflow_dispatch` and PRs to `main`. `flutter analyze` is `continue-on-error: true`. |
| `.github/workflows/android-apk.yml` | Release APK on push to `main`. |
| Git history | Recovery baseline `98e439c`; Flutter client `ab22484`; M1, M2, and M7 commit subjects below. |

No other markdown product documentation existed. This file is the smallest appropriate source of truth. Do not add overlapping requirement documents.

### Milestone identifiers supported by git

Preserve only identifiers that appear in commit subjects:

| ID | Evidence | Scope |
| --- | --- | --- |
| M1 | `88bb0a0`, `9332d0e`, `baa0610`, `21a41e4` | Customer account UI reachability, per-action feedback, test-only CI. |
| M2 | `c1352a7`, `029c1ed`, `1a1e4fe`, `0c2b3ba`, `b54f5e5`, `6adb866`, `288e0a7` | Default currency persistence, inventory/sales/payment currency, purchase-cost snapshot and gross profit, non-negative inventory prices. |
| M7 | `94405fb` (`fix(m7): prevent duplicate customer phones`) | Application-level merchant-scoped duplicate phone protection. **Completed. Do not reopen without concrete evidence.** |

Reports currency/profit work is committed as `8d557db` (`fix(reports): separate sales totals by currency`) and `9c50c15` (`feat(reports): add per-currency gross profit`). Settings default-currency UI is `bc3a900` (`feat(settings): add default-currency selector`). Those subjects are not M-numbered. There are no M3–M6 or M8+ commits. Do not invent that history.

## 3. Product and architecture (repository evidence)

AWTAD RETAIL is a reconstructed Dart baseline (`awtad_retail`) plus a Flutter Android client (`apps/awtad_mobile`).

| Layer | Path | Role |
| --- | --- | --- |
| Shared domain | `lib/domain/` | Money, catalog, inventory, customer, ledger types, sale. |
| Shared application | `lib/application/` | Repositories, cash/credit sale services, ledger write services, in-memory `RetailStore`. |
| Shared data | `lib/data/catalog/` | Reconstructed `grocery-v1` starter catalog fixture. |
| Flutter/Android | `apps/awtad_mobile/` | Arabic RTL merchant UI, SQLite persistence, schema v3. |
| Owner / web administration | — | **Absent.** No web app, no owner dashboard, no subscription services. |

The mobile session hardcodes `RetailSession.defaultMerchant = MerchantId('merchant-1')` (`apps/awtad_mobile/lib/core/database/retail_session.dart`). Merchant isolation is enforced in repositories when a merchant id is supplied; the UI does not select merchants.

SQLite schema version is `3` (`apps/awtad_mobile/lib/core/database/database_service.dart`): v1 operational tables, v2 `store_settings`, v3 nullable `sale_lines.unit_cost_*` snapshot columns. Customers PK is `(merchant_id, customer_id)`. `phone` is nullable TEXT with **no unique index**.

## 4. Requirements

Each item records expected behavior, surface, status, evidence, dependencies, acceptance criteria, and unresolved decisions.

---

### A. Customer and supplier accounting

#### A1. Customer receivables and credit balances

**Requirement.** Track what a customer owes the merchant and what the merchant owes the customer, per currency, in integer minor units. Positive balance = customer owes merchant. Zero = settled. Negative = customer credit.

**Recovered intent.** Distinguish advances from payments.

**Repository evidence vs intent.** The domain has **no advance type**. Allowed types are `openingBalance`, `credit`, and `payment` (`lib/domain/customer/customer_account_entry_type.dart`). Overpayment is stored as `payment` and yields a negative balance. Tests state this explicitly: `test/application/record_customer_payment_service_test.dart` (“overpayment is stored as a customer credit, not an advance type”). `RecordCustomerPaymentService` “never an advance type”.

Arabic UI labels: عليه (owes), له (in favor), تسوية (settled) in `customer_detail_screen.dart` and `debts_screen.dart`.

| Field | Value |
| --- | --- |
| Surface | Shared domain + application; Flutter customer detail and debts screens |
| Status | VERIFIED for receivables and payment-created customer credit. There is **no** separate advance workflow. Treating “advance” as a distinct entry type would contradict current domain rules unless a new approved design replaces them. |
| Evidence | `lib/domain/customer/customer_account_balance.dart`, `customer_account_entry_type.dart`, `lib/application/customer/record_customer_payment_service.dart`, `test/application/record_customer_payment_service_test.dart`, `apps/awtad_mobile/lib/presentation/screens/customer_detail_screen.dart`, CI run `40208327314` |
| Dependencies | Merchant-scoped customer record; append-only ledger |
| Acceptance | Per-currency signed integer balance; overpay remains type `payment`; no currency conversion |
| Unresolved | Whether product language should say “advance” or “customer credit”. Current code chose customer credit via payment. |

#### A2. Append-only customer ledger and reconciliation

**Requirement.** Customer account history is append-only. No update or delete of entries. Duplicate entry ids per merchant are rejected. At most one opening balance per merchant + customer + currency, and it must be first in that scope. Further amounts owed use `credit`. Accounts may start with `credit` or `payment`. Currencies are independent. Missing customers must not invent a zero balance.

**Reconciliation (recovered intent).** Ability to review history and confirm the computed balance matches entries.

| Field | Value |
| --- | --- |
| Surface | Shared domain + application; SQLite `SqliteLedgerRepository`; Flutter customer detail history list |
| Status | VERIFIED for append-only rules, opening-balance constraints, merchant isolation, overflow guard. PARTIAL for a dedicated reconciliation workflow (none exists beyond displaying entries and derived balances). |
| Evidence | `lib/application/customer/customer_account_ledger_repository.dart`, `customer_account_ledger_exceptions.dart`, `apps/awtad_mobile/lib/core/database/sqlite_ledger_repository.dart`, `test/application/customer_account_ledger_repository_test.dart`, `apps/awtad_mobile/test/customer_account_flow_test.dart` |
| Dependencies | Customer repository; integer money |
| Acceptance | No update/remove API; duplicate id rejected; second opening balance rejected; opening not-first rejected; getBalance matches append-order arithmetic; other currencies ignored |
| Unresolved | Formal reconciliation report, period close, or statement-vs-ledger matching is not specified in code. |

#### A3. Opening balances and customer payments (merchant mobile)

**Requirement.** Record a one-time opening balance per currency when the account has no entries in that currency. Record explicit payments with a chosen currency. Credit sales append a `credit` ledger entry atomically with stock decrement and sale persistence.

| Field | Value |
| --- | --- |
| Surface | Shared services + Flutter customer detail; credit sale UoW |
| Status | VERIFIED |
| Evidence | `record_opening_balance_service.dart`, `record_customer_payment_service.dart`, `credit_sale_service.dart`, `sqlite_sale_unit_of_work.dart`, `customer_detail_screen.dart`, `customer_detail_payment_currency_test.dart`, `customer_account_flow_test.dart`, M1 commits |
| Dependencies | A1, A2, currency selection (B3) |
| Acceptance | Opening disabled once entries exist for that currency; payment requires explicit currency when multiple debts exist; credit sale rolls back as one SQLite transaction |
| Unresolved | None for the implemented slice. |

#### A4. Duplicate customer phone (M7)

**Requirement.** Within one merchant, a non-null phone may belong to at most one customer. Comparison is exact on the already-trimmed phone string. Null/blank phones remain allowed (blank becomes null via `Customer` trim). The same phone may exist for different merchants. Updating a customer to keep its own phone is allowed. No schema unique index.

| Field | Value |
| --- | --- |
| Surface | Shared `CustomerRepository.requireUniquePhone`; in-memory store; SQLite customer repository |
| Status | **VERIFIED. Completed at `94405fb`. Do not reopen without concrete evidence.** |
| Evidence | Commit `94405fbfddd054eeafc345791ffbf49f11ad87a9`. `lib/application/customer/customer_repository.dart`, `customer_exceptions.dart`, `apps/awtad_mobile/lib/core/database/sqlite_customer_repository.dart`, `apps/awtad_mobile/test/database_service_lifecycle_test.dart`, `test/application/customer_repository_test.dart`, `test/application/in_memory_retail_store_test.dart`, `test/public_api_test.dart`. CI `40208327314`. Schema still has no unique index on `customers.phone`. |
| Dependencies | Customer trim of phone |
| Acceptance | Duplicate add/update throws `DuplicateCustomerPhoneException` with original type/stack; follow-up valid writes succeed; cross-merchant same phone allowed |
| Unresolved | Customer **edit UI** is not in the customers screen (create-only). Repository `update` exists. Edit UI is not evidenced as an approved remaining M7 task. |

#### A5. Contacts picker / device permissions

**Requirement.** Not approved.

| Field | Value |
| --- | --- |
| Surface | Would be Flutter/Android |
| Status | DEFERRED / not in approved scope |
| Evidence | No contacts package in `apps/awtad_mobile/pubspec.yaml`. Manifests have no `READ_CONTACTS`. `customers_screen.dart` is manual name/phone fields only. |
| Unresolved | Do not start without a new explicit approval. |

#### A6. Supplier accounts, supplier opening balances, credit purchases, supplier payments

**Requirement (recovered intent).** Supplier payables, opening balances, credit purchases, and supplier payments, isolated per merchant, consistent with customer accounting.

| Field | Value |
| --- | --- |
| Surface | None beyond a value object |
| Status | STUB |
| Evidence | `lib/domain/inventory/supplier_id.dart` and public API export only. No supplier entity, repository, ledger, screen, or table. `MerchantInventoryItem` has no supplier field. |
| Dependencies | Integer money, merchant isolation, likely a supplier ledger analogous to A2 |
| Acceptance | Not specified in repository. Must be designed before implementation. |
| Unresolved | Account model, entry types, whether purchases increment stock and supplier debt atomically, multi-currency rules. **Not an approved implementation slice.** |

#### A7. Purchase and return workflows

**Requirement (recovered intent).** Record purchases (stock in, cost, optional supplier credit) and returns.

| Field | Value |
| --- | --- |
| Surface | Inventory has `purchasePrice`; sales snapshot that cost onto `SaleLine.unitPurchaseCost`. No purchase document, no stock-in from supplier, no sales return, no purchase return. |
| Status | UNREACHABLE as a workflow. PARTIAL only as a cost field on inventory and a historical snapshot on sale lines. |
| Evidence | `merchant_inventory_item.dart`, `sale_line.dart`, `database_service.dart` `_createV3`, inventory screen purchase-price fields |
| Unresolved | Purchase invoice identity, returns, restock, ledger impact. **Not evidenced as an approved next milestone.** |

#### A8. Merchant isolation and accounting consistency

**Requirement.** Inventory, customers, sales, and ledger entries are merchant-scoped. Wrong-merchant reads return null/false. Wrong-merchant mutations throw `MerchantMismatchException`. Credit sale commits stock + sale + ledger credit in one transaction, or none.

| Field | Value |
| --- | --- |
| Surface | Shared repositories + SQLite UoW |
| Status | VERIFIED at repository/UoW layer. PARTIAL in the mobile app because the UI always uses `merchant-1`. |
| Evidence | `MerchantMismatchException` in `inventory_exceptions.dart`; customer/inventory/sale/ledger repositories; `sqlite_sale_unit_of_work.dart` `BEGIN IMMEDIATE`; tests in `inventory_repository_test.dart`, `customer_repository_test.dart`, `in_memory_retail_store_test.dart`, `complete_sale_service_test.dart`, `credit_sale_service_test.dart` |
| Acceptance | Cross-merchant reads empty; mutations throw; credit sale atomic |
| Unresolved | Multi-merchant mobile login/session is absent. |

---

### B. Currency, pricing, and profit

#### B1. Integer money and YER precision

**Requirement.** All money is integer minor units with an explicit `CurrencyCode`. No `double`, no implicit default currency, no FX conversion.

**Recovered intent.** YER precision and integer handling.

| Field | Value |
| --- | --- |
| Surface | Shared domain |
| Status | VERIFIED for integer minor units and explicit currency. |
| Evidence | `lib/domain/money/money.dart`, `currency_code.dart`, `test/domain/currency_money_test.dart`. Overflow checks on sale total and ledger balance. Gross-profit margin uses `BigInt` only (`sale_line.dart` `GrossProfitMargin`). |
| Acceptance | Equality includes amount and currency; no conversion APIs |
| Unresolved | ISO YER has no subunit; SAR/USD use 1/100. The code uses the same integer minor-unit model for YER, SAR, and USD. Whether YER minor units mean 1 YER or a 1/100 subunit is **not documented in code**. UI copy uses “وحدات صغرى” (minor units). Reports no longer use “(هللة)” (B2/B4 at `9c50c15`). |

#### B2. Supported currencies and no mixed-currency totals

**Requirement.** Supported codes: YER, SAR, USD. A sale’s lines must share `Sale.currency`. Ledger balances are per currency. Totals and profit must not mix currencies.

| Field | Value |
| --- | --- |
| Surface | Domain `Sale` / `SaleLine`; sales screen; home screen; reports screen |
| Status | VERIFIED in domain, cash/credit sale services, sales UI, home, and reports. Reports bucket sales by `line.unitSellingPrice.currency` and never sum YER+SAR+USD minor units. |
| Evidence | `lib/domain/sale/sale.dart` line-currency validation; `sales_screen.dart` mixed-cart guard; `home_screen.dart` per-`CurrencyCode` revenue/profit; `reports_screen.dart` per-currency cards; `test/domain/sale_test.dart`; `apps/awtad_mobile/test/sales_screen_test.dart`; `home_screen_test.dart`; `apps/awtad_mobile/test/reports_screen_test.dart` (empty, single-currency, multi-currency). Commits `8d557db`, `9c50c15`. CI [40214398790](https://github.com/tahaalialyatim-wq/-taha/actions/runs/40214398790) and [40214383695](https://github.com/tahaalialyatim-wq/-taha/actions/runs/40214383695): 75 tests passed. |
| Dependencies | B1 |
| Acceptance | Reject mixed-currency sale lines; UI must not display a single number that adds YER+SAR+USD minor units; reports follow the same per-currency rule as home |
| Unresolved | None for mixed-currency sales totals. Empty currencies still show `0 {code}` with no coverage warning (same as home). |

#### B3. Persisted default currency and per-document currency selection

**Requirement.** A merchant may persist a store-wide default currency as a **pre-fill only**. It must not rewrite existing inventory, sales, or ledger currencies. Inventory add/edit, sales, and customer payments must select a currency. Payments with multiple outstanding currencies require an explicit choice.

| Field | Value |
| --- | --- |
| Surface | SQLite `store_settings`; inventory, sales, customer-detail screens; settings screen |
| Status | VERIFIED for persistence, inventory/sales/payment pre-fill, and settings UI save/load of YER/SAR/USD (`bc3a900`, CI [41147675989](https://github.com/tahaalialyatim-wq/-taha/actions/runs/41147675989)). Suggestion API remains unused. |
| Evidence | M2 commits `c1352a7`, `029c1ed`, `1a1e4fe`, `0c2b3ba`, `b54f5e5`; settings `bc3a900`. `sqlite_store_settings_repository.dart`; `settings_screen.dart` (`readDefaultCurrency` / `saveDefaultCurrency`; null/invalid/read-write failures); `app_shell.dart` passes `session`; theme/RTL/language controls preserved. Tests: `apps/awtad_mobile/test/settings_screen_test.dart`; `database_service_lifecycle_test.dart` (reopen persist, merchant isolation, invalid stored value not rewritten). Prefill screens and their tests were not changed by `bc3a900`. |
| Dependencies | B1, schema v2 |
| Acceptance | Default is pre-fill; mixed payment currencies force a choice; saving default does not mutate historical rows |
| Unresolved | Settings UI uses `RetailSession.defaultMerchant`. Save-failure persistence after database reopen is not explicitly verified. Prefill behavior in inventory/sales/payments was not changed by this feature. `suggestDefaultCurrency` remains unused and has no UI confirmation flow. |

#### B4. Purchase cost, selling price, genuine gross profit

**Requirement.** Inventory may store selling and purchase prices (null and zero allowed; negative rejected). At sale time, current inventory purchase price is snapshotted onto the sale line. Gross profit = selling total − snapshot cost in the same currency. Missing or foreign-currency cost makes profit **unknown**, not zero. Home and reports show per-currency revenue, gross profit, and incomplete-cost coverage from persisted `SaleLine` snapshots. Profit is gross only (no expenses).

| Field | Value |
| --- | --- |
| Surface | Shared domain + inventory update validation; Flutter inventory, home; reports |
| Status | VERIFIED for snapshot, profit math, home visibility, reports per-currency cost/profit, and non-negative price updates (M2 `6adb866`, `288e0a7`; reports `8d557db`, `9c50c15`). |
| Evidence | `sale_line.dart` `lineCost` / `grossProfit`; `complete_sale_service.dart`; `credit_sale_service.dart`; `merchant_inventory_repository.dart` `requireNonNegativePrices`; `home_screen.dart`; `reports_screen.dart` (cost/profit from snapshots; unknown → `—`; partial known sums labeled `(جزئي)`; coverage warning). Tests: `test/domain/sale_test.dart`, `home_screen_test.dart`, `inventory_repository_test.dart`, `apps/awtad_mobile/test/reports_screen_test.dart` (unknown, partial, foreign-cost, historical snapshot). Schema v3. CI [40214398790](https://github.com/tahaalialyatim-wq/-taha/actions/runs/40214398790) and [40214383695](https://github.com/tahaalialyatim-wq/-taha/actions/runs/40214383695) on `9c50c15`: 75 tests passed. |
| Dependencies | B1, B2 |
| Acceptance | Unknown cost ≠ 0 profit; mixed cost/sell currency ⇒ unknown; negative inventory prices rejected; coverage warning when any line lacks cost; later inventory-cost edits must not change historical report profit |
| Unresolved | Net profit / expenses are out of current code. Live inventory prices must not drive historical profit (stock cards remain quantity-only). |

---

### C. Owner administration and subscription lifecycle

These items are **recovered intent** from the recovery directive. There is **no** repository evidence they were implemented, and no git milestone that approved them.

Owner-side administration is distinct from merchant-facing Flutter/Android. Do not fold them into `apps/awtad_mobile` without an explicit architecture decision.

#### C1. Owner/admin dashboard and merchant management

| Field | Value |
| --- | --- |
| Surface | Owner administration (not the merchant mobile app) |
| Status | UNREACHABLE / PLANNED as recovered intent |
| Evidence | None. `MerchantId` is a value object only. Mobile hardcodes `merchant-1`. No users, roles, or admin UI. |
| Acceptance | Not specified in repository |
| Unresolved | Platform (web vs other), auth, merchant provisioning API vs local-only app |

#### C2. Subscription activation, renewal, activation codes, status, expiration

| Field | Value |
| --- | --- |
| Surface | Owner administration |
| Status | UNREACHABLE / PLANNED as recovered intent |
| Evidence | None in Dart, SQLite, or workflows |
| Unresolved | Code format, delivery channel, online vs offline activation |

#### C3. 10-calendar-day grace period; suspend without deleting merchant data

**Recovered intent.** After expiration, 10 calendar days of grace; then suspend. Suspension must not delete merchant data.

| Field | Value |
| --- | --- |
| Surface | Owner administration + merchant client enforcement |
| Status | PLANNED as recovered intent. No code. |
| Evidence | None in repository. Calendar vs 24-hour-day, timezone, and clock source are unspecified. |
| Acceptance (recovered, not implemented) | Expired + within 10 calendar days: still usable. After grace: blocked writes or login; data retained and restorable if reactivated. |
| Unresolved | Timezone; whether grace applies per activation or per merchant; what “suspend” blocks on a local SQLite device if the owner service is unreachable. |

Do not treat C1–C3 as the next coding task unless newly approved. They are blocked on product/platform decisions and are not M1/M2/M7.

---

### D. Customer communications and documents

`Customer` documentation states there is **no** invoice, SMS, or PDF state on the customer record (`lib/domain/customer/customer.dart`). `LanguageCode` supports `ar` and `en` only (`lib/domain/language/language_code.dart`). `Store` has `defaultLanguage`. The mobile UI is Arabic RTL; settings language tile is hardcoded “العربية” and disabled.

#### D1. Arabic and English customer statements

| Field | Value |
| --- | --- |
| Surface | Shared language type; merchant documents (absent) |
| Status | STUB (`LanguageCode`, `Store.defaultLanguage`). No statement generator. |
| Evidence | `lib/domain/language/language_code.dart`, `lib/domain/store/store.dart`, `settings_screen.dart` |
| Unresolved | Statement contents, period, whether English is merchant-facing or document-only |

#### D2. PDF generation and printing

| Field | Value |
| --- | --- |
| Surface | Flutter/Android (recovered intent) |
| Status | UNREACHABLE |
| Evidence | No PDF package. Customer type forbids PDF state on the record. |
| Unresolved | Library choice, templates, printer vs share sheet |

#### D3. Direct WhatsApp sharing

| Field | Value |
| --- | --- |
| Surface | Flutter/Android (recovered intent) |
| Status | UNREACHABLE |
| Evidence | None |
| Unresolved | `whatsapp://` vs official API; which document is shared |

#### D4. SMS messaging

| Field | Value |
| --- | --- |
| Surface | Unspecified |
| Status | UNREACHABLE. Provider/dependency **unresolved**. |
| Evidence | Customer type says no SMS state. No SMS packages or gateways. |
| Unresolved | Device SMS vs gateway; sender ID; cost; whether in scope at all. Classify as **not committed** until a provider decision exists. |

#### D5. Invoice generation and numbering

| Field | Value |
| --- | --- |
| Surface | Home screen uses the word “فواتير” for **sale count** (`home_screen.dart` `invoice-count`). There is no `Invoice` type, number sequence, or document. `SaleId` is an opaque id. |
| Status | UNREACHABLE as invoicing. Sale persistence is VERIFIED separately. |
| Evidence | `lib/domain/sale/sale.dart`, `home_screen.dart`, comment in `customer_account_entry.dart` that entries do not embed Invoice objects |
| Unresolved | Number format, reset rules, tax fields, whether sale id is the invoice number |

---

### E. Data protection and operations

#### E1. Backup and restore

| Field | Value |
| --- | --- |
| Surface | Operations / Flutter |
| Status | UNREACHABLE |
| Evidence | None. SQLite file is `awtad_retail.sqlite` under app documents (`database_service.dart`). No export/import UI or documented backup procedure. |
| Unresolved | File copy vs encrypted export; restore into a newer schema; multi-device |

#### E2. Data integrity and merchant-data isolation

| Field | Value |
| --- | --- |
| Surface | SQLite init + repositories |
| Status | PARTIAL / VERIFIED for local integrity checks and repository isolation |
| Evidence | `PRAGMA foreign_keys = ON`, `journal_mode = WAL`, `integrity_check` on init; schema version guard; merchant-scoped keys; atomic sale UoW. No remote sync. |
| Acceptance | Init fails closed on integrity check; unsupported schema version throws `DatabaseInitException` |
| Unresolved | Backup (E1); encryption at rest; cloud sync |

#### E3. Other evidenced product capabilities (not in A–D)

| Capability | Status | Evidence |
| --- | --- | --- |
| Arabic RTL merchant shell with six destinations (home, sales, inventory, customers, debts, reports) plus settings/about | IMPLEMENTED (destinations VERIFIED by `app_destinations_test.dart`) | `app_destinations.dart`, `app_shell.dart` |
| Cash and credit sale through `CompleteSaleService` / `CreditSaleService` only | VERIFIED | `apps/awtad_mobile/README.md`, sale services, sales screen tests |
| Grocery starter catalog `grocery-v1` (9 categories, 45 products, reconstructed identities) | IMPLEMENTED in shared data; **not wired** to the mobile app | `lib/data/catalog/grocery_starter_catalog.dart` notes reconstructed identities; no `apps/` references |
| Theme seed and dark mode | IMPLEMENTED | `settings_screen.dart` |
| APK CI on `main` | IMPLEMENTED, DEFERRED for this branch | `android-apk.yml`; skipped on PR |

## 5. Dependency-aware sequence to release readiness

This is an execution order, not a claim that later items are approved. Preserve M1/M2/M7 as completed slices. Do not invent M3–M6.

### Completed (do not reopen)

1. Reconstructed domain/application baseline (`98e439c`) and in-memory atomic cash/credit commit (`d49ecb3`).
2. Flutter Android client, SQLite v1, APK CI (`ab22484` and follow-up CI host fixes).
3. **M1** customer opening-balance and payment UI + test CI.
4. **M2** default currency persistence; inventory/sales/payment currency; purchase-cost snapshot and home gross profit; non-negative inventory prices.
5. **M7** duplicate customer phones at `94405fb`.
6. Reports per-currency sales totals (`8d557db`) and per-currency cost + gross profit from persisted sale-line snapshots (`9c50c15`). CI 75 tests on `9c50c15`.
7. Settings default-currency selector (`bc3a900`). CI [41147675989](https://github.com/tahaalialyatim-wq/-taha/actions/runs/41147675989): analyze no issues; **84 tests passed**.

### Remaining merchant-app work evidenced in this tree

Order is dependency-aware. Each step needs explicit implementation approval.

| Order | Task | Why this order | Suggested acceptance |
| --- | --- | --- | --- |
| 1 | Release verification / APK | Settings default-currency UI is closed at `bc3a900`. Remaining merchant-app M2 UI gap in this tree is release packaging, if authorized. Requires merge to `main` or an explicit APK-workflow approval. This environment cannot build locally. | `flutter test` green; APK artifact from `android-apk.yml`; no contacts/permissions scope creep. |

### Recovered intent not evidenced as approved next work

Do not start these from this document alone:

- Supplier accounts and purchase/return documents (A6, A7)
- Owner dashboard and subscription/grace/suspension (C)
- Statements, PDF, print, WhatsApp, SMS, invoice numbering (D)
- Backup/restore (E1)
- Contacts picker (A5)
- Wiring starter catalog into the mobile app
- Multi-merchant login
- Customer edit UI (repository exists; UI approval missing)

Suggested later dependency order **if** those product areas are newly approved:

1. Confirm accounting model for suppliers and whether “advance” remains out of domain.
2. Shared supplier ledger (mirror A2) before UI.
3. Purchase UoW (stock + cost + optional supplier credit) before returns.
4. Document/statement layer after ledger completeness; then PDF/share.
5. Owner/subscription platform as a separate surface; merchant client only enforces status.
6. Backup/restore after schema stability.

## 6. Missing historical details that could not be recovered

The repository has no prior requirements file. The following could not be recovered from git, code, or CI:

- Original AWTAD product spec, Figma, or milestone plan (M3–M6 meaning).
- Whether “advance” was a distinct approved type later replaced by payment-created credit.
- YER minor-unit convention (1 YER vs 1/100).
- Invoice numbering scheme.
- SMS provider, WhatsApp mechanism, PDF library.
- Subscription code format, clock/timezone for the 10-calendar-day grace period, and suspend UX on an offline device.
- Backup encryption and restore policy.
- Whether grocery catalog identities must match a lost historical catalog (`grocery_starter_catalog.dart` says they are a reconstructed fixture).
- Any approved contacts-picker decision (none found; treated as not approved).

## 7. Recommended next implementation task

**Not started.** Documentation only.

Recommended next **implementation** task, pending approval:

Release verification / APK (section 5 order 1), only if newly authorized. Settings default-currency save/load is VERIFIED at `bc3a900`. Reports per-currency sales, cost, and gross profit remain VERIFIED at `9c50c15`.

Acceptance criteria:

- Do not change schema, permissions, ledger rules, M7 phone uniqueness, reports aggregation, or settings currency behavior.
- APK only from `android-apk.yml` on `main`, if approved.
- Stop for review before PR merge or further features.

Do not implement until approved.
