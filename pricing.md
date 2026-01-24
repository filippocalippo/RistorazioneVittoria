# Pricing Strategy
## Rotante SaaS - Pizzeria Management Platform

**Document Version:** 1.0
**Date:** January 2026
**Market:** Italy (Primary), EU (Secondary)

---

## Executive Summary

This document outlines a comprehensive pricing strategy for Rotante, a multi-tenant SaaS platform for pizzeria management. The pricing is designed to:

1. **Attract small pizzerias** with a free tier to build market share
2. **Scale with customer success** through usage-based components
3. **Maximize lifetime value** of professional and enterprise customers
4. **Remain competitive** in the Italian market

### Recommended Pricing Tiers

| Tier | Monthly Price | Target Customer | Key Differentiator |
|------|---------------|-----------------|-------------------|
| **Free** | €0 | New/Very small pizzerias | Get started, limited features |
| **Starter** | €29/month | Small pizzerias | Core features, online ordering |
| **Professional** | €79/month | Growing pizzerias | Full features, analytics |
| **Enterprise** | €199/month | Multi-location/Franchises | White-label, API, priority support |

---

## Table of Contents

1. [Market Analysis](#1-market-analysis)
2. [Competitive Landscape](#2-competitive-landscape)
3. [Pricing Philosophy](#3-pricing-philosophy)
4. [Tier Breakdown](#4-tier-breakdown)
5. [Feature Matrix](#5-feature-matrix)
6. [Transaction Fees](#6-transaction-fees)
7. [Add-Ons & Upsells](#7-add-ons--upsells)
8. [Discount Strategy](#8-discount-strategy)
9. [Revenue Projections](#9-revenue-projections)
10. [Pricing Psychology](#10-pricing-psychology)
11. [Implementation Recommendations](#11-implementation-recommendations)

---

## 1. Market Analysis

### Target Market: Italian Pizzerias

| Segment | Est. Count | Monthly Revenue | Tech Adoption | Price Sensitivity |
|---------|------------|-----------------|---------------|-------------------|
| Small (1-2 staff) | ~25,000 | €5,000-15,000 | Low | Very High |
| Medium (3-5 staff) | ~15,000 | €15,000-40,000 | Medium | High |
| Large (6-10 staff) | ~5,000 | €40,000-100,000 | Medium-High | Medium |
| Chain/Franchise | ~500 | €100,000+ | High | Low |

**Total Addressable Market (TAM):** ~45,500 pizzerias in Italy
**Serviceable Addressable Market (SAM):** ~35,000 (those open to digital tools)
**Serviceable Obtainable Market (SOM):** ~3,500 (10% in 3 years)

### Key Market Insights

1. **Cash-heavy industry**: Many pizzerias still prefer cash, but COVID accelerated digital payment adoption
2. **Delivery boom**: 35% of pizzeria revenue now comes from delivery (up from 15% pre-COVID)
3. **Labor shortage**: Automation and efficiency tools are increasingly valued
4. **Low margins**: Average pizzeria operates on 5-15% net margins
5. **Seasonal variation**: Summer months see 20-30% lower orders in cities

### Customer Willingness to Pay

Based on Italian market research:
- **Small pizzerias**: €20-40/month for comprehensive solution
- **Medium pizzerias**: €50-100/month with proven ROI
- **Large pizzerias**: €100-250/month for premium features
- **Chains**: €150-500/month per location + volume discounts

---

## 2. Competitive Landscape

### Direct Competitors (Italy)

| Competitor | Pricing | Strengths | Weaknesses |
|------------|---------|-----------|------------|
| **Tilby** | €50-150/month | Well-known, POS hardware | Complex, expensive hardware |
| **Cassa in Cloud** | €29-99/month | Good UI, reliable | Limited delivery features |
| **Deliverart** | €49-149/month | Delivery focused | No POS, limited menu mgmt |
| **Ristomanager** | €39-119/month | Comprehensive | Outdated interface |
| **TheFork Manager** | Commission-based | Large reach | High fees, no ownership |

### Indirect Competitors

| Type | Examples | Threat Level |
|------|----------|--------------|
| Generic POS | Square, SumUp | Medium - lack restaurant features |
| Delivery Platforms | Glovo, JustEat, Deliveroo | High - but high commission (15-30%) |
| Excel/Paper | Manual systems | Low - but hard to displace |

### Competitive Positioning

**Rotante Differentiators:**
1. **Purpose-built for pizzerias**: Split pizzas, toppings management, dough tracking
2. **All-in-one**: Menu, orders, delivery, kitchen, inventory in one platform
3. **Lower cost than aggregators**: Own your customer data, no per-order commission
4. **Modern tech stack**: Fast, works on any device, real-time updates

---

## 3. Pricing Philosophy

### Core Principles

1. **Land and Expand**: Free tier to acquire, upsell to paid tiers
2. **Value-Based Pricing**: Price based on value delivered, not cost
3. **Predictable Revenue**: Subscription-first with small usage component
4. **Fair Scaling**: Price increases with customer success
5. **No Surprises**: Transparent pricing, no hidden fees

### Pricing Model: Hybrid SaaS

```
Total Monthly Cost = Base Subscription + Transaction Fees + Add-Ons
```

**Base Subscription**: Fixed monthly fee per tier
**Transaction Fees**: Small percentage on online payments (processed through Stripe Connect)
**Add-Ons**: Optional features purchased separately

### Why This Model?

| Component | Rationale |
|-----------|-----------|
| Base Subscription | Provides predictable revenue, covers infrastructure costs |
| Transaction Fees | Aligns our success with customer success, covers payment processing |
| Add-Ons | Allows customization without tier complexity |

---

## 4. Tier Breakdown

### Free Tier

**Target:** Very small pizzerias testing digital tools, seasonal businesses

**Price:** €0/month forever

**Limits:**
- 1 staff account (owner only)
- 50 menu items maximum
- 100 orders/month maximum
- Basic features only
- Rotante branding required
- Community support only

**Included Features:**
- Menu management (basic)
- Order taking (manual entry)
- Basic order history
- Mobile app access

**Not Included:**
- Online ordering
- Delivery management
- Kitchen display
- Analytics
- Inventory
- API access

**Purpose:**
- Customer acquisition
- Build trust and familiarity
- Natural upgrade path when limits hit

---

### Starter Tier

**Target:** Small pizzerias ready to go digital

**Price:** €29/month (€290/year with annual billing - 2 months free)

**Limits:**
- 3 staff accounts
- 100 menu items
- 500 orders/month
- Standard support (email, 48h response)

**Included Features:**
Everything in Free, plus:
- Online ordering (web widget)
- Customer management
- Delivery zone configuration
- Basic delivery tracking
- Order notifications (email)
- Basic reporting
- Receipt customization
- "Powered by Rotante" branding

**Key Value Proposition:**
> "Replace expensive delivery platform commissions. Pay €29/month instead of 20-30% per order."

**ROI Calculation for Customer:**
- Average order value: €25
- Commission on delivery platform: €5-7.50 (20-30%)
- Break-even: 5-6 orders per month
- Typical small pizzeria: 100+ delivery orders/month
- **Monthly savings: €450-720**

---

### Professional Tier

**Target:** Growing pizzerias serious about efficiency

**Price:** €79/month (€790/year with annual billing)

**Limits:**
- 10 staff accounts
- Unlimited menu items
- 2,000 orders/month
- Priority support (email, 24h response)

**Included Features:**
Everything in Starter, plus:
- Kitchen display system (KDS)
- Delivery driver app
- Delivery optimization
- Advanced analytics dashboard
- Inventory management (basic)
- Promotional banners
- Customer loyalty tracking
- Push notifications
- QR code ordering
- Multiple delivery zones
- Custom branding (no "Powered by")
- Scheduled orders
- Order reminders

**Key Value Proposition:**
> "Run your pizzeria like a pro. See what's selling, manage your kitchen, track deliveries in real-time."

**ROI Calculation for Customer:**
- Time saved on order management: 2 hours/day
- Staff efficiency improvement: 15%
- Order error reduction: 25%
- Customer satisfaction increase: measurable

---

### Enterprise Tier

**Target:** Multi-location pizzerias, franchises, high-volume operations

**Price:** €199/month per location (€1,990/year with annual billing)
- Volume discounts: 10% for 3-5 locations, 20% for 6+ locations

**Limits:**
- Unlimited staff accounts
- Unlimited menu items
- Unlimited orders
- Dedicated support (phone, 4h response)

**Included Features:**
Everything in Professional, plus:
- Multi-location management
- Centralized menu control
- Cross-location analytics
- Advanced inventory (with suppliers)
- API access
- Webhooks
- White-label option
- Custom domain
- SSO/SAML integration
- Dedicated account manager
- Custom integrations
- SLA guarantee (99.9% uptime)
- Data export tools
- Advanced user permissions

**Key Value Proposition:**
> "Scale your pizzeria empire. Manage multiple locations from one dashboard with enterprise-grade features."

---

## 5. Feature Matrix

| Feature | Free | Starter | Professional | Enterprise |
|---------|:----:|:-------:|:------------:|:----------:|
| **Core** |
| Menu management | Basic | Full | Full | Full |
| Order taking | Manual | Online | Online | Online |
| Order history | 30 days | 1 year | Unlimited | Unlimited |
| Mobile app | View | Full | Full | Full |
| **Online Ordering** |
| Web ordering widget | - | Basic | Advanced | Custom |
| QR code ordering | - | - | Yes | Yes |
| Scheduled orders | - | - | Yes | Yes |
| Order customization | Basic | Full | Full | Full |
| **Delivery** |
| Delivery zones | 1 | 3 | Unlimited | Unlimited |
| Delivery tracking | - | Basic | Real-time | Real-time |
| Driver app | - | - | Yes | Yes |
| Route optimization | - | - | - | Yes |
| **Kitchen** |
| Kitchen display | - | - | Yes | Yes |
| Order tickets | - | Basic | Advanced | Advanced |
| Prep time tracking | - | - | Yes | Yes |
| **Analytics** |
| Basic reports | - | Yes | Yes | Yes |
| Advanced analytics | - | - | Yes | Yes |
| Cross-location analytics | - | - | - | Yes |
| Custom reports | - | - | - | Yes |
| **Inventory** |
| Stock tracking | - | - | Basic | Advanced |
| Low stock alerts | - | - | Yes | Yes |
| Supplier management | - | - | - | Yes |
| **Marketing** |
| Promotional banners | - | - | Yes | Yes |
| Customer database | - | Basic | Full | Full |
| Loyalty program | - | - | - | Yes |
| **Integrations** |
| API access | - | - | - | Yes |
| Webhooks | - | - | - | Yes |
| Third-party POS | - | - | - | Yes |
| Accounting export | - | - | Yes | Yes |
| **Branding** |
| Custom colors | - | - | Yes | Yes |
| Remove Rotante branding | - | - | Yes | Yes |
| White-label | - | - | - | Yes |
| Custom domain | - | - | - | Yes |
| **Support** |
| Documentation | Yes | Yes | Yes | Yes |
| Community forum | Yes | Yes | Yes | Yes |
| Email support | - | 48h | 24h | 4h |
| Phone support | - | - | - | Yes |
| Dedicated manager | - | - | - | Yes |
| **Limits** |
| Staff accounts | 1 | 3 | 10 | Unlimited |
| Menu items | 50 | 100 | Unlimited | Unlimited |
| Orders/month | 100 | 500 | 2,000 | Unlimited |
| Locations | 1 | 1 | 1 | Unlimited |

---

## 6. Transaction Fees

### Payment Processing (via Stripe Connect)

When customers accept online payments through Rotante:

| Component | Rate | Notes |
|-----------|------|-------|
| Stripe processing | 1.5% + €0.25 | European cards |
| Stripe processing | 2.9% + €0.25 | Non-European cards |
| Rotante platform fee | 0.5% | Our revenue |
| **Total to customer** | **2.0% + €0.25** | European cards |

**Comparison to Alternatives:**
- Delivery platforms (Glovo, JustEat): 15-30% commission
- Direct card terminal: 1.5-2% + monthly fee
- **Rotante: 2% + subscription = significantly cheaper**

### When Transaction Fees Apply

- Online card payments through Rotante checkout
- QR code payments
- In-app payments from customer app

### When Transaction Fees Do NOT Apply

- Cash payments (recorded manually)
- Payments through external terminals
- Bank transfers

### Example Monthly Cost

**Medium pizzeria scenario:**
- Monthly subscription: €79 (Professional)
- Online orders: 300 at €25 average = €7,500
- Transaction fees: €7,500 × 2% + €0.25 × 300 = €225
- **Total monthly cost: €304**

**Versus JustEat at 25% commission:**
- Commission: €7,500 × 25% = €1,875
- **Savings with Rotante: €1,571/month**

---

## 7. Add-Ons & Upsells

### Premium Add-Ons

| Add-On | Price | Available For | Description |
|--------|-------|---------------|-------------|
| **Extra Staff Seats** | €5/seat/month | All tiers | Beyond tier limit |
| **Extra Locations** | €49/location/month | Professional | Multi-location for Pro tier |
| **SMS Notifications** | €0.05/SMS | Starter+ | Order confirmations via SMS |
| **Priority Support** | €29/month | Starter | Upgrade to 24h email response |
| **Custom Integration** | €499 one-time | Enterprise | Custom API integration work |
| **Onboarding Package** | €199 one-time | All tiers | White-glove setup assistance |
| **Training Session** | €99/hour | All tiers | Remote staff training |
| **Data Migration** | €299 one-time | All tiers | Import from other systems |

### Hardware (Optional, Sold Separately)

| Hardware | Price | Notes |
|----------|-------|-------|
| Tablet Stand | €49 | For kitchen display |
| Receipt Printer | €129 | Bluetooth thermal printer |
| Card Reader | €39 | Stripe Terminal |
| Starter Kit | €199 | Tablet stand + printer + reader |

### Revenue Optimization Features (Future)

| Feature | Pricing Model | Target |
|---------|---------------|--------|
| **Marketing Automation** | €19/month add-on | Professional+ |
| **Advanced Loyalty** | €29/month add-on | Professional+ |
| **Table Reservations** | €19/month add-on | All tiers |
| **Catering Module** | €39/month add-on | Professional+ |

---

## 8. Discount Strategy

### Standard Discounts

| Discount Type | Amount | Conditions |
|---------------|--------|------------|
| Annual billing | 2 months free (~17%) | Pay annually upfront |
| Multi-location | 10% | 3-5 locations |
| Multi-location | 20% | 6+ locations |
| Referral credit | €50 | Both parties, after 3 months |
| Non-profit | 25% | Registered non-profits |

### Promotional Discounts (Use Sparingly)

| Promotion | Discount | When to Use |
|-----------|----------|-------------|
| First month free | 100% off month 1 | New customer acquisition |
| 3 months at 50% | 50% × 3 months | Competitive win-back |
| Free upgrade trial | 1 month higher tier | Upsell existing customers |

### Discount Guidelines

**DO:**
- Offer annual billing discount (improves cash flow, reduces churn)
- Provide volume discounts for enterprise
- Give referral bonuses (low CAC acquisition)

**DON'T:**
- Discount monthly pricing easily (sets bad precedent)
- Offer lifetime deals (unsustainable)
- Give discounts without time limits

### Grandfathering Policy

Existing customers keep their pricing when we increase prices:
- For 12 months after price increase announcement
- As long as they remain continuously subscribed
- Applies to base tier price only, not add-ons

---

## 9. Revenue Projections

### Assumptions

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| Free users | 500 | 1,500 | 3,000 |
| Conversion to paid | 15% | 20% | 25% |
| Starter customers | 60 | 200 | 450 |
| Professional customers | 15 | 75 | 225 |
| Enterprise locations | 2 | 15 | 60 |
| Annual billing % | 30% | 40% | 50% |
| Monthly churn | 4% | 3% | 2.5% |

### Revenue Projections

#### Year 1

| Revenue Stream | Calculation | Monthly | Annual |
|----------------|-------------|---------|--------|
| Starter subscriptions | 60 × €29 | €1,740 | €20,880 |
| Professional subscriptions | 15 × €79 | €1,185 | €14,220 |
| Enterprise subscriptions | 2 × €199 | €398 | €4,776 |
| Transaction fees | €50k volume × 0.5% | €250 | €3,000 |
| Add-ons & services | Estimated | €200 | €2,400 |
| **Total** | | **€3,773** | **€45,276** |

#### Year 2

| Revenue Stream | Monthly (End of Year) | Annual |
|----------------|----------------------|--------|
| Starter subscriptions | €5,800 | €52,200 |
| Professional subscriptions | €5,925 | €53,325 |
| Enterprise subscriptions | €2,985 | €26,865 |
| Transaction fees | €1,000 | €9,000 |
| Add-ons & services | €800 | €7,200 |
| **Total** | **€16,510** | **€148,590** |

#### Year 3

| Revenue Stream | Monthly (End of Year) | Annual |
|----------------|----------------------|--------|
| Starter subscriptions | €13,050 | €117,450 |
| Professional subscriptions | €17,775 | €159,975 |
| Enterprise subscriptions | €11,940 | €107,460 |
| Transaction fees | €3,500 | €31,500 |
| Add-ons & services | €2,000 | €18,000 |
| **Total** | **€48,265** | **€434,385** |

### Key Metrics Targets

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| MRR (end of year) | €3,773 | €16,510 | €48,265 |
| ARR | €45k | €198k | €579k |
| Average Revenue Per User | €49 | €55 | €62 |
| Customer Acquisition Cost | €150 | €120 | €100 |
| Lifetime Value (36 mo) | €1,470 | €1,980 | €2,232 |
| LTV:CAC Ratio | 9.8:1 | 16.5:1 | 22.3:1 |

---

## 10. Pricing Psychology

### Anchoring Strategy

Present Enterprise tier first on pricing page to anchor high:
```
Enterprise: €199/month
Professional: €79/month (MOST POPULAR)
Starter: €29/month
Free: €0
```

This makes Professional look like great value compared to Enterprise.

### Decoy Effect

Professional tier is designed as the "decoy" to make the value proposition clear:
- Starter → Professional jump: €50 for 10x more features
- Professional → Enterprise jump: €120 for API/white-label

Most customers land on Professional (our target).

### Price Framing

Present costs in multiple ways:
- "Less than €1/day" (Starter)
- "Less than the cost of one pizza per month" (Starter)
- "Save €1,500+/month vs delivery platforms" (value framing)

### Social Proof

On pricing page, show:
- "Join 500+ pizzerias across Italy"
- "Average customer saves €800/month"
- Customer testimonials with photos

### Urgency (Use Sparingly)

- "Annual plan: Lock in current pricing"
- Grandfather clause creates natural urgency before price increases

### Reducing Friction

- 14-day free trial of any paid tier (no credit card)
- Easy upgrade/downgrade
- Prorated billing
- Cancel anytime

---

## 11. Implementation Recommendations

### Phase 1: Launch Pricing (Months 1-6)

**Start with simpler pricing:**
- Free tier (build user base)
- Professional tier only at €49/month (capture early adopters)
- No transaction fees initially (reduce friction)

**Why:** Validate product-market fit before optimizing revenue.

### Phase 2: Tier Expansion (Months 6-12)

**Add tiers:**
- Introduce Starter at €29/month
- Increase Professional to €79/month
- Grandfather existing customers at €49
- Begin 0.5% transaction fee

### Phase 3: Enterprise & Add-Ons (Year 2)

**Expand offerings:**
- Launch Enterprise tier
- Introduce add-on marketplace
- Launch hardware partnerships
- Consider usage-based pricing for high-volume

### Pricing Page Best Practices

1. **Lead with value, not features**: "Save money. Save time. Grow your business."
2. **Clear tier comparison**: Feature matrix with checkmarks
3. **Highlight recommended tier**: "Most Popular" badge on Professional
4. **FAQ section**: Address common objections
5. **Calculator tool**: "See how much you'll save" interactive widget
6. **Trust signals**: Security badges, customer logos, testimonials

### Sales Process by Tier

| Tier | Sales Motion |
|------|--------------|
| Free | Self-service, no sales involvement |
| Starter | Self-service with chat support |
| Professional | Self-service or guided demo |
| Enterprise | Sales-assisted, custom proposals |

### Handling Price Objections

| Objection | Response |
|-----------|----------|
| "Too expensive" | Calculate ROI vs delivery platform fees |
| "Competitor is cheaper" | Focus on pizzeria-specific features |
| "I'm too small" | Recommend Free tier, show growth path |
| "Need more features" | Discuss Enterprise or custom solutions |
| "Can't commit long-term" | Offer monthly billing, easy cancellation |

---

## Appendix A: Localization Considerations

### Italy-Specific Factors

- **VAT**: All prices should be + 22% IVA (show both)
- **Invoicing**: Must support Italian electronic invoicing (Fattura Elettronica)
- **Payment methods**: Support Bancomat, PostePay, Satispay
- **Seasonal pricing**: Consider lower summer rates for tourist areas

### Future EU Expansion

When expanding beyond Italy:
- Research local competitors in each market
- Consider purchasing power parity adjustments
- Spain/Portugal: Similar pricing
- Germany/France: 20-30% premium possible
- Eastern Europe: 30-40% discount needed

---

## Appendix B: Pricing Change Protocol

### When to Change Prices

**Raise prices when:**
- LTV:CAC ratio exceeds 5:1 consistently
- Significant new features added
- Market validates higher willingness to pay
- Costs increase substantially

**Lower prices when:**
- Conversion rates drop significantly
- Competitors undercut meaningfully
- Entering new market segment

### Communication Protocol

1. **60 days notice** for any price increase
2. **Email announcement** to all affected customers
3. **Grandfathering option** for loyal customers
4. **FAQ update** on pricing page
5. **Sales team briefing** for objection handling

### Price Testing

Before major pricing changes:
- A/B test pricing page with new vs old prices
- Survey existing customers on willingness to pay
- Analyze competitor pricing movements
- Model revenue impact scenarios

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| MRR | Monthly Recurring Revenue |
| ARR | Annual Recurring Revenue |
| ARPU | Average Revenue Per User |
| CAC | Customer Acquisition Cost |
| LTV | Customer Lifetime Value |
| Churn | % of customers who cancel per period |
| Net Revenue Retention | Revenue from existing customers YoY |
| Expansion Revenue | Additional revenue from existing customers |

---

**Document Prepared By:** Claude AI
**Review Required By:** CEO, Sales Lead, Finance
**Next Review Date:** 6 months post-launch
