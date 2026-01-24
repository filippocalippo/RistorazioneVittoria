# Stripe PaymentIntent Edge Function

Creates Stripe PaymentIntent for secure payment processing using Server-Side Price Calculation.

## Deployment

```bash
# Deploy the function
supabase functions deploy create-payment-intent

# Set the Stripe secret key (use your test key for development)
supabase secrets set STRIPE_SECRET_KEY=sk_test_your_secret_key
```

## Usage

### Request
```json
POST /functions/v1/create-payment-intent
Content-Type: application/json
Authorization: Bearer <supabase-anon-key>

{
  "items": [
    {
      "menuItemId": "uuid-123",
      "quantity": 2,
      "sizeId": "uuid-size-456",
      "extraIngredients": [
        { "ingredientId": "uuid-ing-789", "quantity": 1 }
      ]
    }
  ],
  "orderType": "delivery",
  "deliveryLatitude": 36.95,
  "deliveryLongitude": 14.50,
  "currency": "eur",
  "customerEmail": "customer@example.com",
  "metadata": {
    "custom_field": "value"
  }
}
```

### Response
```json
{
  "clientSecret": "pi_xxx_secret_xxx",
  "paymentIntentId": "pi_xxx",
  "amount": 2550,
  "currency": "eur",
  "calculatedTotal": 25.50,
  "calculatedSubtotal": 22.50,
  "calculatedDeliveryFee": 3.00
}
```

## Security Features
- **Server-Side Pricing**: Prices are fetched from the database, ignoring any prices sent by the client.
- **Inventory Validation**: Checks if items are available (though full stock deduction happens at order creation).
- **Delivery Fee Calculation**: Calculates fee based on distance from pizzeria to delivery coordinates.
- **Minimum Order Check**: Enforces minimum order amount server-side.

## Testing with curl

```bash
curl -X POST 'https://your-project.supabase.co/functions/v1/create-payment-intent' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "items": [{"menuItemId": "YOUR_ITEM_UUID", "quantity": 1}],
    "orderType": "takeaway"
  }'
```
