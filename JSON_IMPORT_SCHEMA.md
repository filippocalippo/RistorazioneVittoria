# JSON Menu Import Schema Reference

Use this schema to generate JSON for importing menus into the Rotante application. The importer supports advanced features like bulk ingredient selection, price overrides, and on-the-fly creation of categories and sizes.

## Root Structure

```json
{
  "categories": [ ... ],
  "ingredients": [ ... ],
  "sizes": [ ... ],
  "products": [ ... ]
}
```

---

## 1. Categories
Defines the sections of the menu.

```json
{
  "name": "Pizze Rosse",  // Required: Unique name
  "order": 1              // Optional: Display order (default: 0)
}
```

## 2. Ingredients
Defines available ingredients that can be used in products.

```json
{
  "name": "Mozzarella",       // Required: Unique name
  "price": 1.5,               // Optional: Base price for adding this ingredient (default: 0.0)
  "category": "Latticini",    // Optional: Grouping for shortcuts
  "allergens": ["Latte"]      // Optional: List of allergens
}
```

## 3. Sizes
Defines global size variants.

```json
{
  "name": "Maxi",             // Required: Unique name
  "price_multiplier": 2.0     // Optional: Multiplier applied to base product price (default: 1.0)
}
```

## 4. Products (The Core)
Defines the menu items. This is where the powerful features live.

### Basic Product
```json
{
  "name": "Margherita",
  "category": "Pizze Rosse",      // Must match a defined category name
  "price": 6.0,                   // Base price
  "description": "Tomato & Mozzarella",
  "allergens": ["Glutine", "Latte"],
  "included_ingredients": ["Pomodoro", "Mozzarella"] // List of ingredient names
}
```

### Advanced Product with Overrides & Shortcuts
This example demonstrates all power user features.

```json
{
  "name": "Custom Pizza",
  "category": "Speciali",
  "price": 10.0,
  
  // SIZES
  // Can be simple strings OR objects with overrides
  "sizes": [
    "Normale",                                   // Uses global multiplier
    { "name": "Maxi", "price_override": 18.0 }   // OVERRIDE: Ignores multiplier, sets exact price
  ],

  // EXTRA INGREDIENTS (Add-ons)
  // Supports mixed types: Strings, Objects, Shortcuts
  "extra_ingredients": [
    "ALL",                                       // SHORTCUT 1: Adds ALL known ingredients
    
    // "CATEGORY:Verdure",                       // SHORTCUT 2: Adds all ingredients from 'Verdure' category
    
    // SPECIFIC OVERRIDES (Place these AFTER 'ALL' to override specific items)
    { 
      "name": "Tartufo", 
      "price_override": 5.0,                     // Changes price just for this product
      "max_quantity": 2                          // Limits how many can be added
    }
  ]
}
```

---

## Full Example for AI Context

Copy this block to give to an AI as a template:

```json
{
  "categories": [
    { "name": "Pizze Classiche", "order": 1 },
    { "name": "Bibite", "order": 2 }
  ],
  "ingredients": [
    { "name": "Mozzarella", "price": 1.5, "category": "Latticini", "allergens": ["Latte"] },
    { "name": "Pomodoro", "price": 0.0, "category": "Salse" },
    { "name": "Prosciutto", "price": 2.0, "category": "Affettati" }
  ],
  "sizes": [
    { "name": "Normale", "price_multiplier": 1.0 },
    { "name": "Maxi", "price_multiplier": 2.0 }
  ],
  "products": [
    {
      "name": "Margherita",
      "category": "Pizze Classiche",
      "price": 6.0,
      "description": "La regina delle pizze",
      "allergens": ["Glutine", "Latte"],
      "included_ingredients": ["Pomodoro", "Mozzarella"],
      "sizes": ["Normale", "Maxi"],
      "extra_ingredients": [
        "ALL", 
        { "name": "Mozzarella", "price_override": 1.0 }
      ]
    },
    {
      "name": "Coca Cola",
      "category": "Bibite",
      "price": 3.0,
      "sizes": [],
      "extra_ingredients": []
    }
  ]
}
```
