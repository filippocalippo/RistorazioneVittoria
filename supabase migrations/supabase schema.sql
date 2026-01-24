-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.allowed_cities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  cap text NOT NULL,
  attiva boolean DEFAULT true,
  ordine integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT allowed_cities_pkey PRIMARY KEY (id)
);
CREATE TABLE public.business_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  attiva boolean DEFAULT true,
  chiusura_temporanea boolean DEFAULT false,
  data_chiusura_da timestamp with time zone,
  data_chiusura_a timestamp with time zone,
  indirizzo text,
  citta text,
  cap text,
  provincia text,
  telefono text,
  email text,
  orari jsonb DEFAULT '{}'::jsonb,
  latitude numeric,
  longitude numeric,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT business_rules_pkey PRIMARY KEY (id)
);
CREATE TABLE public.categorie_menu (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  descrizione text,
  icona text,
  ordine integer DEFAULT 0,
  attiva boolean DEFAULT true,
  disattivazione_programmata boolean DEFAULT false,
  orario_disattivazione time without time zone,
  giorni_disattivazione ARRAY,
  data_disattivazione_da date,
  data_disattivazione_a date,
  ultimo_controllo_disattivazione timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categorie_menu_pkey PRIMARY KEY (id)
);
CREATE TABLE public.delivery_configuration (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tipo_calcolo_consegna text DEFAULT 'fisso'::text CHECK (tipo_calcolo_consegna = ANY (ARRAY['fisso'::text, 'per_km'::text])),
  costo_consegna_base numeric DEFAULT 3.00 CHECK (costo_consegna_base >= 0::numeric),
  costo_consegna_per_km numeric DEFAULT 0.50 CHECK (costo_consegna_per_km >= 0::numeric),
  raggio_consegna_km numeric DEFAULT 5.0 CHECK (raggio_consegna_km > 0::numeric),
  consegna_gratuita_sopra numeric DEFAULT 30.00 CHECK (consegna_gratuita_sopra >= 0::numeric),
  tempo_consegna_stimato_min integer DEFAULT 30 CHECK (tempo_consegna_stimato_min >= 10),
  tempo_consegna_stimato_max integer DEFAULT 60 CHECK (tempo_consegna_stimato_max >= 15),
  zone_consegna_personalizzate jsonb DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT delivery_configuration_pkey PRIMARY KEY (id)
);
CREATE TABLE public.delivery_zones (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  color_hex text NOT NULL CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'::text),
  polygon jsonb NOT NULL,
  display_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT delivery_zones_pkey PRIMARY KEY (id)
);
CREATE TABLE public.display_branding (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  mostra_allergeni boolean DEFAULT true,
  colore_primario text DEFAULT '#FF6B35'::text CHECK (colore_primario ~ '^#[0-9A-Fa-f]{6}$'::text),
  colore_secondario text DEFAULT '#004E89'::text CHECK (colore_secondario ~ '^#[0-9A-Fa-f]{6}$'::text),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT display_branding_pkey PRIMARY KEY (id)
);
CREATE TABLE public.ingredients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  descrizione text,
  prezzo numeric NOT NULL DEFAULT 0 CHECK (prezzo >= 0::numeric),
  categoria text,
  allergeni ARRAY DEFAULT '{}'::text[],
  ordine integer DEFAULT 0,
  attivo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ingredients_pkey PRIMARY KEY (id)
);
CREATE TABLE public.kitchen_management (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  stampa_automatica_ordini boolean DEFAULT false,
  mostra_note_cucina boolean DEFAULT true,
  alert_sonoro_nuovo_ordine boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT kitchen_management_pkey PRIMARY KEY (id)
);
CREATE TABLE public.menu_item_extra_ingredients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  menu_item_id uuid NOT NULL,
  ingredient_id uuid NOT NULL,
  price_override numeric CHECK (price_override >= 0::numeric),
  max_quantity integer DEFAULT 1 CHECK (max_quantity > 0),
  ordine integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT menu_item_extra_ingredients_pkey PRIMARY KEY (id),
  CONSTRAINT menu_item_extra_ingredients_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id),
  CONSTRAINT menu_item_extra_ingredients_ingredient_id_fkey FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id)
);
CREATE TABLE public.menu_item_included_ingredients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  menu_item_id uuid NOT NULL,
  ingredient_id uuid NOT NULL,
  ordine integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT menu_item_included_ingredients_pkey PRIMARY KEY (id),
  CONSTRAINT menu_item_included_ingredients_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id),
  CONSTRAINT menu_item_included_ingredients_ingredient_id_fkey FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id)
);
CREATE TABLE public.menu_item_sizes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  menu_item_id uuid NOT NULL,
  size_id uuid NOT NULL,
  display_name_override text,
  is_default boolean DEFAULT false,
  ordine integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT menu_item_sizes_pkey PRIMARY KEY (id),
  CONSTRAINT menu_item_sizes_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id),
  CONSTRAINT menu_item_sizes_size_id_fkey FOREIGN KEY (size_id) REFERENCES public.sizes_master(id)
);
CREATE TABLE public.menu_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  categoria_id uuid,
  nome text NOT NULL,
  descrizione text,
  prezzo numeric NOT NULL CHECK (prezzo >= 0::numeric),
  prezzo_scontato numeric CHECK (prezzo_scontato >= 0::numeric),
  immagine_url text,
  ingredienti ARRAY,
  allergeni ARRAY,
  valori_nutrizionali jsonb,
  disponibile boolean DEFAULT true,
  in_evidenza boolean DEFAULT false,
  ordine integer DEFAULT 0,
  product_configuration jsonb DEFAULT '{"defaultSizeId": null, "maxSupplements": null, "specialOptions": [], "allowSupplements": false, "allowSizeSelection": false}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT menu_items_pkey PRIMARY KEY (id),
  CONSTRAINT menu_items_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorie_menu(id)
);
CREATE TABLE public.notifiche (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  destinatario_id uuid,
  tipo text NOT NULL,
  titolo text NOT NULL,
  messaggio text NOT NULL,
  dati jsonb,
  letta boolean DEFAULT false,
  letta_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  ordine_id uuid,
  CONSTRAINT notifiche_pkey PRIMARY KEY (id),
  CONSTRAINT notifiche_destinatario_id_fkey FOREIGN KEY (destinatario_id) REFERENCES public.profiles(id),
  CONSTRAINT notifiche_ordine_id_fkey FOREIGN KEY (ordine_id) REFERENCES public.ordini(id)
);
CREATE TABLE public.order_management (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ordini_consegna_attivi boolean DEFAULT true,
  ordini_asporto_attivi boolean DEFAULT true,
  ordini_tavolo_attivi boolean DEFAULT true,
  ordine_minimo numeric DEFAULT 10.00 CHECK (ordine_minimo >= 0::numeric),
  tempo_preparazione_medio integer DEFAULT 30 CHECK (tempo_preparazione_medio > 0),
  tempo_slot_minuti integer DEFAULT 30 CHECK (tempo_slot_minuti = ANY (ARRAY[15, 30, 60])),
  pausa_ordini_attiva boolean DEFAULT false,
  capacity_takeaway_per_slot integer DEFAULT 50 CHECK (capacity_takeaway_per_slot > 0),
  capacity_delivery_per_slot integer DEFAULT 50 CHECK (capacity_delivery_per_slot > 0),
  accetta_pagamenti_contanti boolean DEFAULT true,
  accetta_pagamenti_carta boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_management_pkey PRIMARY KEY (id)
);
CREATE TABLE public.ordini (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cliente_id uuid,
  numero_ordine text NOT NULL UNIQUE,
  stato text NOT NULL DEFAULT 'pending'::text CHECK (stato = ANY (ARRAY['pending'::text, 'confirmed'::text, 'preparing'::text, 'ready'::text, 'delivering'::text, 'completed'::text, 'cancelled'::text])),
  tipo text NOT NULL CHECK (tipo = ANY (ARRAY['delivery'::text, 'takeaway'::text, 'dine_in'::text])),
  nome_cliente text NOT NULL,
  telefono_cliente text NOT NULL,
  email_cliente text,
  indirizzo_consegna text,
  citta_consegna text,
  cap_consegna text,
  latitude_consegna numeric,
  longitude_consegna numeric,
  note text,
  subtotale numeric NOT NULL CHECK (subtotale >= 0::numeric),
  costo_consegna numeric DEFAULT 0 CHECK (costo_consegna >= 0::numeric),
  sconto numeric DEFAULT 0 CHECK (sconto >= 0::numeric),
  totale numeric NOT NULL CHECK (totale >= 0::numeric),
  metodo_pagamento text CHECK (metodo_pagamento = ANY (ARRAY['cash'::text, 'card'::text, 'online'::text])),
  pagato boolean DEFAULT false,
  assegnato_cucina_id uuid,
  assegnato_delivery_id uuid,
  tempo_stimato_minuti integer,
  slot_prenotato_start timestamp with time zone,
  valutazione integer CHECK (valutazione >= 1 AND valutazione <= 5),
  recensione text,
  created_at timestamp with time zone DEFAULT now(),
  confermato_at timestamp with time zone,
  preparazione_at timestamp with time zone,
  pronto_at timestamp with time zone,
  in_consegna_at timestamp with time zone,
  completato_at timestamp with time zone,
  cancellato_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ordini_pkey PRIMARY KEY (id),
  CONSTRAINT ordini_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.profiles(id),
  CONSTRAINT ordini_assegnato_cucina_id_fkey FOREIGN KEY (assegnato_cucina_id) REFERENCES public.profiles(id),
  CONSTRAINT ordini_assegnato_delivery_id_fkey FOREIGN KEY (assegnato_delivery_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.ordini_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ordine_id uuid,
  menu_item_id uuid,
  nome_prodotto text NOT NULL,
  quantita integer NOT NULL DEFAULT 1 CHECK (quantita > 0),
  prezzo_unitario numeric NOT NULL CHECK (prezzo_unitario >= 0::numeric),
  subtotale numeric NOT NULL CHECK (subtotale >= 0::numeric),
  note text,
  varianti jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ordini_items_pkey PRIMARY KEY (id),
  CONSTRAINT ordini_items_ordine_id_fkey FOREIGN KEY (ordine_id) REFERENCES public.ordini(id),
  CONSTRAINT ordini_items_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text NOT NULL,
  nome text,
  cognome text,
  telefono text,
  ruolo text NOT NULL DEFAULT 'customer'::text CHECK (ruolo = ANY (ARRAY['customer'::text, 'manager'::text, 'kitchen'::text, 'delivery'::text])),
  avatar_url text,
  fcm_token text,
  fcm_tokens jsonb DEFAULT '[]'::jsonb,
  attivo boolean DEFAULT true,
  ultimo_accesso timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.sizes_master (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  slug text NOT NULL UNIQUE,
  descrizione text,
  price_multiplier numeric NOT NULL DEFAULT 1.0 CHECK (price_multiplier > 0::numeric),
  ordine integer DEFAULT 0,
  attivo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT sizes_master_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_addresses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  allowed_city_id uuid,
  etichetta text,
  indirizzo text NOT NULL,
  citta text NOT NULL,
  cap text NOT NULL,
  note text,
  is_default boolean DEFAULT false,
  latitude numeric,
  longitude numeric,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_addresses_pkey PRIMARY KEY (id),
  CONSTRAINT user_addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT user_addresses_allowed_city_id_fkey FOREIGN KEY (allowed_city_id) REFERENCES public.allowed_cities(id)
);