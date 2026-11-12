# Walaa (ولاء) — Complete Feature List for a Similar Build

**Purpose:** reverse-engineered feature inventory of [walaa.com.sa](https://walaa.com.sa) and its merchant app, organized so it can be turned into a product backlog.

**Sources**

1. Public marketing site and all 17 English pages in its sitemap (claims, card types, positioning).
2. Merchant web app bundle (`app.walaa.com.sa/static/js/main.d34a25d0.js`), which contains the real admin UI vocabulary — screen names, field labels, campaign types, metrics, integration names.
3. App manifest and public endpoints.

**Confidence markers**

| Marker | Meaning |
|---|---|
| ✅ | Confirmed — explicit UI string, field, or documented claim in the product |
| 🟡 | Marketed — stated on the website, but implementation details are not public |
| 🧩 | Inferred — strongly implied by adjacent fields/screens, not directly seen |
| 🔮 | Announced roadmap — "coming soon" |

> ⚠️ A string in a JS bundle proves a feature exists in *some* build. It does not prove it is enabled on every plan, current, or generally available. Verify limits, pricing, and SLAs with the vendor.

---

## 1. Product at a glance

Walaa is a **multi-tenant, white-label digital loyalty platform for Saudi SMBs**. A merchant creates a loyalty program, designs a card, and the customer saves it to Apple Wallet / Google Wallet / Samsung Wallet — no customer app. Staff issue stamps/points from a scanner app; the merchant runs campaigns and reads analytics from a dashboard.

- **Customer side:** QR/link → join form → wallet pass → earn → redeem → receive push.
- **Merchant side:** dashboard + scanner PWA.
- **Platform side:** merchant/org administration, plans, billing.
- **Tagline:** "In their wallet. On their mind." / "ولاء في محفظتهم. وعلامتك على بالهم."
- **Powered by:** Wessal (وصال), positioned as Saudi tech.

### Roles

| Role | Surface | Job |
|---|---|---|
| Platform operator (Walaa) | Internal admin | Manage merchants, orgs, subscriptions, suspensions |
| Merchant owner/admin | Web dashboard (PWA) | Program setup, design, campaigns, analytics, billing, team |
| Staff / cashier | Scanner app | Scan customer QR, award stamps/points, redeem, undo |
| Customer | Wallet pass + join page | Join, hold card, earn, redeem, receive notifications |

---

## 2. Domain model (suggested)

```
Organisation (merchant)
├── Subscription / Plan / Invoice
├── TeamMember → Role (admin, staff)
├── Branch (location) → Counter (1–4)
├── Card / Program (stamp, points, cashback, gift, membership, multi-stamp, tiered)
│   ├── CardDesign (front/back, fields, colors, QR, per-tier variants)
│   ├── Tier (threshold, benefits, card design)
│   ├── Reward (milestone, catalog item, coupon, gift, ticket)
│   └── EarningRule / RedemptionRule (amount, expiry, limits)
├── Customer (member)
│   └── Pass (one per card) → balances, tier, wallet status, pass code
├── Transaction (earn / redeem / adjust / undo) → ledger
├── Campaign (type, audience, schedule, message)
├── Segment (prebuilt or rule-based)
├── Notification / Push (impressions, delivered)
├── ApiKey / Webhook / Integration (Foodics, Stripe)
└── AuditLog
```

Key invariants worth designing early: **every balance change is an append-only ledger entry**, **every redemption is idempotent**, and **passes are per customer per card, not per customer**.

---

## 3. Feature catalog

Priorities: **P0** = required for a credible clone · **P1** = competitive parity · **P2** = later / differentiator.

### 3.1 Loyalty program / card types

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Stamp card ✅ | Customer collects N stamps, unlocks reward | Configurable stamp count, stamp artwork/text, reward at milestone; "amount cost for a single stamp" | P0 |
| Points card ✅ | Points per riyal or per visit, redeem from reward catalog | Point value at redemption, points per riyal, unlock threshold, "not enough points" state | P0 |
| Cashback card ✅ | Percentage of spend credited back as store credit | Cashback %, balance, earn/spend ledger; not a cash withdrawal | P1 |
| Gift card ✅ | Prepaid value given as a gift | Gift value, description, pre-loaded balance, redemption; payment/delivery rules | P1 |
| Membership card 🧩 | Paid/recurring membership with balance/benefits | Membership amount, renewal, redeem; exact semantics need vendor confirmation | P2 |
| Multi-stamp card ✅ | 1–4 independent stamp counters on one card | Each counter has its own reward and stamp artwork ("Stamp counters 1-4") | P1 |
| Tiered points ✅ | Tiers with thresholds and benefits | Tier name, threshold (points/spend), auto-move customer on reach, card design per tier | P1 |
| Hybrid programs ✅ | e.g. stamps + points, points + tiers | UI strings "Stamp Points" and "Points + Tiers" | P2 |
| Referral / affiliation 🧩 | Reward for referring customers | "Affiliation Reward Type", "Minimum number of referrals to get Reward", "Use Affiliation" | P2 |
| Card lifecycle ✅ | Active/inactive, default card/design, expiry, allowed members | Per-card status, default design, expiry type/value, pass issuance quantity, branch scope ("Works at all branches") | P0 |

### 3.2 Wallet passes and card design

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Apple Wallet ✅ | Issue and update `.pkpass` | PassKit cert, pass type ID, web service for updates, APNs push | P0 |
| Google Wallet ✅ | Issue and update Google Wallet pass | Google Wallet issuer account, JWT, REST updates | P0 |
| Samsung Wallet ✅ | Third wallet target | Separate SDK/partner onboarding | P2 |
| Add-to-wallet flow ✅ | Landing page that installs the pass | Detect device/wallet, fallback, track wallet status | P0 |
| Pass code / user code ✅ | Unique customer identifier on the pass | QR/barcode payload plus human-readable code | P0 |
| Barcode formats ✅ | QR and PDF417 | `PKBarcodeFormatQR`, `PKBarcodeFormatPDF417` | P0 |
| Pass field editor ✅ | Header, primary, secondary, auxiliary, back fields | Map merchant fields to wallet template slots; custom back fields and pass-back metadata | P0 |
| Visual designer ✅ | Front/back, logo, icon, strip image, colors, fonts | Card/background/text/button colors, cover color/image, font color/weight, opacity | P0 |
| QR designer ✅ | Style, size, foreground/background color | Download QR code as asset | P1 |
| Multiple designs ✅ | Several designs per card, choose default | "At least one design is required", "Your Designs", "Total Designs" | P1 |
| Design per tier ✅ | Different card art for each tier | "Card design per tier" | P2 |
| Localization ✅ | Arabic/English pass rendering | RTL, Arabic preview ("Shown on a phone set to Arabic"), field-length limits | P0 |
| Wallet status ✅ | Whether customer actually added the pass | Track installed/not installed; useful for campaigns | P1 |
| Pass updates ✅ | Push changed balance/reward to existing passes | Wallet web service + device registration; handle removals | P0 |
| Download QR / print assets ✅ | Counter QR for joining | PDF/PNG export | P1 |

### 3.3 Enrollment and customer management

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| QR / link enrollment ✅ | Scan or open link to join | Unique per org/branch/campaign; short link; landing page | P0 |
| Join form builder ✅ | Collect customer fields at install | Custom fields (text, number, date, select), required flags, field order | P0 |
| Opt-in tracking ✅ | Record consent and source | "Opted in through", total campaign opt-in | P1 |
| Manual code entry ✅ | Join/redeem without camera | Staff types pass code | P0 |
| Cardholder list ✅ | Search and manage members | Search by name/code/phone/email; balances, last visit, wallet status | P0 |
| Customer profile ✅ | Contact details, birthday, gender, tags, custom fields | Birthday drives campaigns; tags drive segments | P0 |
| Bulk manage / CSV import ✅ | Import or update many cardholders | Column mapping, validation, error report | P1 |
| Pass issuance ✅ | Issue N passes / add members in bulk | "Pass issuance quantity", "Number of passes" | P1 |
| Allowed members ✅ | Limit who can join a given card | Allow-list / membership gating | P2 |

### 3.4 Earning and redemption

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Scan to earn ✅ | Staff scans pass QR and applies reward | Scanner PWA; confirm screen; shows customer + current balance | P0 |
| Award stamp / points / cashback ✅ | Apply the earning rule | Amount-based or visit-based; per counter | P0 |
| Reward redemption ✅ | Mark reward as used, decrement balance | Redemption code, confirm, receipt, history | P0 |
| Redemption rules ✅ | Multiple redemptions, once per day, expiry, min spend | "Allow Multiple Redemptions", "Redeem Once Per Day", expire type/value, threshold | P1 |
| Staff undo ✅ | Reverse a mistaken transaction | Configurable undo window ("How long staff can undo a transaction from the scanner") | P0 |
| Reward catalog ✅ | Define rewards customers can unlock/buy with points | Reward type, item, description, points needed, value | P1 |
| Reward milestones ✅ | Unlock rewards at stamp counts | "Define rewards customers unlock at stamp milestones" | P0 |
| Balance/history ✅ | Show current and past activity | Customer-facing pass + merchant customer profile | P0 |
| Redemption / expiry webhooks ✅ | Notify external systems | See integrations | P2 |

### 3.5 Branches, counters, staff, and scanner

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Multi-branch ✅ | Locations under one organisation | Branch CRUD, rename, address, city/district, map/geolocation, "All branches" filter | P1 |
| Branch performance ✅ | Compare locations | Revenue/visits/redemptions per branch; "No branch comparison available" empty state | P1 |
| Counters ✅ | Sub-locations inside a branch | 1–4 counters, each with its own reward and stamp artwork | P1 |
| Staff accounts ✅ | Separate logins for cashiers | Invite, role, suspend, remove | P0 |
| Roles / permissions ✅ | Admin vs staff access | "Role", "Add Admin", "Team", "Admins"; likely coarse-grained | P1 |
| Scanner app ✅ | Dedicated staff PWA | Camera QR scan, manual code, dashboard, undo, configurable scan-app settings | P0 |
| Branch-scoped staff ✅ | Restrict staff to branches | "Works at all branches" flag | P2 |
| Organization settings ✅ | Business profile and preferences | Brand/trade name, CR number, VAT, address, phone, email, website, industry, currency | P0 |

### 3.6 Campaigns and notifications

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Campaign builder ✅ | Create and schedule campaigns | Name, code, type, start/end, deal, audience, message | P1 |
| Stamp campaign ✅ | Bonus stamps / stamp-based offer | Campaign type enum | P1 |
| Points / loyalty campaign ✅ | Bonus points or point multiplier | Campaign type enum | P1 |
| Coupon campaign ✅ | Discount coupon with type and value | Fixed/percent, amount, code, redeem tracking | P1 |
| Ticket campaign 🧩 | Event/admission ticket campaign | "Event Tickets", ticket received/redeemed totals; semantics unclear | P2 |
| Membership campaign 🧩 | Membership acquisition/renewal | "Membership Campaign", "Total Membership Amount" | P2 |
| Wallet campaign ✅ | Campaign delivered through wallet pass | "walletcampaigns" internal key | P2 |
| Broadcast push ✅ | Send a message to all or selected customers | Title, body, preview, emoji, schedule date/time | P1 |
| Auto-push / automation ✅ | Rule-triggered pushes | "Set auto-push rules", "Send automated push notifications", automation settings | P1 |
| Birthday notification ✅ | Send X days before birthday | "Congratulation will be sent X day(s) before birthday" | P1 |
| Inactivity / win-back ✅ | Trigger after no visits (e.g. 30 days) | "customers inactive 30d", "No visit in 30+ days" | P1 |
| Next-visit reminder ✅ | Nudge after a visit | "Next visit reminder" | P2 |
| Geo-push / proximity ✅ | Notify near a branch | "Geo push within 100 metres (330 feet)", "Customers are notified near this branch" | P2 |
| iBeacon ✅ | Physical beacon triggers | UUID, major, minor, message | P2 |
| Scheduling / recurrence ✅ | Daily, monthly, on date, same day, never expire | Schedule and repeat fields | P1 |
| Delivery analytics ✅ | Impressions, delivered, opt-in counts | Track per campaign; wallet delivery is best-effort | P2 |
| Notification preview ✅ | Preview message on a phone mockup | Arabic/English preview | P1 |

### 3.7 Segmentation and CRM

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Prebuilt segments ✅ | Ready-made audiences | New, returning/recent, at-risk, dormant, high spenders, 2+ transactions, no visit 30+ days, birthdays this week, top customers | P1 |
| Rule-based segments 🧩 | Custom conditions on spend/visits/fields | Condition type + value; "Selected Segments" | P1 |
| Tags ✅ | Free-form labels on customers | "Contact Tags" | P1 |
| Custom fields ✅ | Merchant-defined customer attributes | Field name/type/value; also usable on pass | P1 |
| Last visit / spend / balance ✅ | Customer-level metrics | Shown in list and profile | P0 |

### 3.8 Analytics and reporting

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| KPI dashboard ✅ | Top-line program health | Active members, subscribers, new/returning, revenue, redemptions | P1 |
| Insight dashboard ✅ | Deeper trends and recommendations | "Insight", "Recommended Actions", "Retention Pulse" | P2 |
| Revenue analytics ✅ | Revenue attributed to loyalty activity | "Recorded Revenue", "Revenue performance from loyalty activity" | P1 |
| Repeat-visit analytics ✅ | Repeat customer rate/revenue | Definitions matter; show formula in UI | P1 |
| Average order value ✅ | Spend per transaction/customer | "Avg Order Value", "Monthly Spending" | P1 |
| Branch comparison ✅ | Rank/compare locations | Per-branch revenue, visits, redemptions | P2 |
| Campaign performance ✅ | Impressions, opt-ins, redemptions per campaign | Per-type totals | P1 |
| Reward / liability metrics ✅ | Stamps issued/redeemed, points earned/spent, coupons, gift/membership balances | Important for cost control | P1 |
| Customer analytics ✅ | Total, new, active, at-risk, dormant, top | Segment counts | P1 |
| Date filters ✅ | 7/30/90 days, last year, all time | Consistent timezone (Riyadh) | P1 |
| Export ✅ | CSV / PDF export | Invoices and reports | P2 |

### 3.9 Integrations and developer platform

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Foodics POS ✅ | Real-time loyalty automation | "Connect with Foodics POS", "Loyalty Adapter Secret" | P1 |
| Stripe ✅ | Payments for subscription billing | Likely for plans/invoices | P1 |
| REST API ✅ | Programmatic access | "API Docs", "Postman Docs" | P2 |
| API keys ✅ | Org-scoped keys | `X-API-KEY`, create/copy/regenerate | P2 |
| Webhooks ✅ | Redemption and expiry events | Create webhook, retries, signing, logs | P2 |
| Pass update webhooks 🧩 | Wallet device registration/update endpoints | Required by Apple PassKit web service | P0 (internal) |
| CSV import/export ✅ | Bulk data movement | Customers, reports | P1 |

### 3.10 Billing, plans, and platform admin

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Subscription plans ✅ | Monthly/annual plans | Plan entitlements, feature gating | P1 |
| Trial ✅ | Time-limited trial, cancel trial | "Cancel trial", "Next payment due" | P1 |
| Invoices ✅ | Billing history and invoice detail | Invoice number, search, PDF | P1 |
| Payment method ✅ | Card management | Via Stripe | P1 |
| Feature gating ✅ | "Please upgrade your plan to get full access" | Entitlement checks in API, not just UI | P1 |
| Account suspension ✅ | Suspend org/user | "Error 401 — Account Suspended" | P2 |
| Platform merchant admin ✅ | Internal overview of merchants | Merchant list/overview, orgs, admins, activity logs | P2 |
| Audit log ✅ | Who did what | "Logs", "Performed By" | P2 |
| White-label / rebranding ✅ | Operator branding | "Powered by Walaa", "Rebranding", org branding | P2 |

### 3.11 Customer-facing experience

| Feature | What it does | Build notes | Prio |
|---|---|---|---|
| Join via QR/link ✅ | One-step enrollment | No app install; must have a compatible wallet | P0 |
| Add to wallet ✅ | Install pass | Apple/Google/Samsung | P0 |
| Card display ✅ | Stamps/points/cashback/gift balance, rewards, tier | Wallet-rendered; layout limited by wallet | P0 |
| Redeem in store ✅ | Show QR/code, staff validates | Offline-friendly fallback | P0 |
| Push messages ✅ | Birthday, win-back, offers | Delivery depends on wallet/device settings | P1 |
| Arabic + English ✅ | Bilingual UI and passes | RTL correctness | P0 |
| Wallet pass update ✅ | Balance reflects immediately | Server-driven pass update | P0 |

### 3.12 Announced

| Feature | Status | Notes |
|---|---|---|
| Walaa AI 🔮 | Coming soon | "Next generation of Walaa with artificial intelligence"; no public details |

---

## 4. Suggested MVP → parity roadmap

### P0 — credible clone (single merchant, single branch)

1. Auth, organisation, one branch, team invite.
2. One program: **stamp card** + **points card**.
3. Apple Wallet + Google Wallet pass generation, Arabic/English design editor.
4. QR/link join with a small custom form.
5. Staff scanner PWA: scan → confirm → earn → redeem → undo.
6. Customer list with balances and history.
7. Basic dashboard: members, stamps/points issued/redeemed, redemptions.
8. Append-only ledger + idempotent redemption + audit trail.

### P1 — parity

- Multi-branch and counters, branch comparison.
- Cashback and gift cards; multi-stamp; tiered points.
- Campaigns: broadcast, birthday, inactivity; scheduling; segments.
- CSV import/export; roles; plan entitlements; Stripe billing.
- Foodics integration; better analytics and exports.

### P2 — differentiation

- Membership, ticket, and referral programs.
- Geo-push / iBeacon proximity.
- Public API + webhooks + developer docs.
- White-label/rebranding and platform merchant admin.
- AI features.

---

## 5. Hard parts / risks

| Area | Why it is hard | Mitigation |
|---|---|---|
| Apple Wallet | Certificates, pass type IDs, web service, APNs, device registration, pass signing | Build a pass service early; test on real devices |
| Google Wallet | Issuer account approval, JWT signing, object/class model | Abstract wallet provider interface |
| Wallet rendering limits | Field count/length, no RTL quirks, layout differs per wallet/OS | Design within constraints; preview on both |
| Notifications | Wallet push is best-effort; no read receipts | Set expectations; add opt-in + in-app alternative |
| Redemption correctness | Double-scan, offline, staff error | Idempotency keys, undo window, ledger, device time sync |
| Multi-tenancy | Data isolation, per-org branding, per-org keys | Org-scoped rows + RLS; never trust client org ID |
| Billing | Trials, proration, dunning, entitlements | Use Stripe Billing; entitlements in one service |
| Arabic | RTL, pluralization, date/currency formats | i18n from day one; pseudo-localization tests |
| Compliance | Saudi PDPL, consent, data residency | Consent records, retention policy, DPA |
| Scale | Pass updates and campaign sends are bursty | Queue + rate limit; batch wallet updates |

---

## 6. Open questions to confirm with the vendor

1. What are the plan limits (branches, members, pushes, campaigns, API calls)?
2. Which card types are live vs. legacy (membership, ticket, affiliation)?
3. Which POS systems besides Foodics are supported? Any e-commerce (Salla/Zid/Shopify)?
4. Is there a public API/webhook contract, or partner-only?
5. How is "Recorded Revenue" calculated, and how are refunds handled?
6. Are notifications sent via wallet only, or also SMS/email/WhatsApp?
7. What is the exact tier upgrade/downgrade logic and reset period?
8. Is gift-card value regulated (stored value) and who holds the funds?
9. Is white-label/rebranding available to resellers?
10. What are the data-retention, export, and PDPL commitments?

---

## 7. Source notes

- **Marketing claims:** `walaa.com.sa/en/` and the 15 guide pages under `/en/guides/` (stamps, points, cashback, gift cards, multi-stamp, tiered points, birthday/inactivity notifications, analytics, Foodics/integration caveats).
- **Product surface:** English UI strings extracted from the public merchant-app bundle, including navigation, form fields, campaign types, metrics, integration names, and error states.
- **PWA:** `app.walaa.com.sa/manifest.json` — standalone, portrait, theme `#ef4523`.
- **Not available publicly:** pricing, plan limits, API docs, screenshots of the dashboard, customer-side app (none exists), and any SLA.
