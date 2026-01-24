const path = require('path');
const express = require('express');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const logger = require('./src/logger');
const { loadConfig, saveConfig, getConfig } = require('./src/config');
const { printReceipt, printCancelledReceipt, printPagatoReceipt } = require('./src/template');
const { enqueuePrintJob, withPrinter } = require('./src/printer-service');

const app = express();
const PORT = process.env.PORT || 3001;

// ---- Supabase client ----
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  logger.warn('MISSING SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Polling disabled.');
}

const supabase = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  : null;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ---- API: Orders ----
app.get('/api/orders', async (req, res) => {
  try {
    const orders = await fetchAllOrders();
    res.json({ ok: true, orders });
  } catch (err) {
    logger.error(`API /api/orders error: ${err.message}`);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.get('/api/orders/:id/items', async (req, res) => {
  const orderId = req.params.id;
  try {
    const items = await fetchOrderItems(orderId);
    res.json({ ok: true, items });
  } catch (err) {
    logger.error(`API items error ${orderId}: ${err.message}`);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post('/api/orders/:id/print', async (req, res) => {
  const orderId = req.params.id;
  try {
    const order = await fetchOrderById(orderId);
    if (!order) return res.status(404).json({ ok: false, error: 'Order not found' });

    const items = await fetchOrderItems(orderId);
    const config = getConfig();
    const copies = config.printer.copies || 1;

    // Print all copies
    for (let copyNum = 1; copyNum <= copies; copyNum++) {
      await enqueuePrintJob(() => withPrinter(printer => printReceipt(printer, order, items, config, copyNum)));
    }

    logger.info(`Order ${orderId} printed (${copies} copies)`);
    res.json({ ok: true, copies });
  } catch (err) {
    logger.error(`API print error ${orderId}: ${err.message}`);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ---- API: Settings ----
app.get('/api/settings', (req, res) => {
  res.json({ ok: true, config: getConfig() });
});

app.post('/api/settings', async (req, res) => {
  try {
    const newConfig = await saveConfig(req.body);
    res.json({ ok: true, config: newConfig });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post('/api/test-print', async (req, res) => {
  try {
    const config = getConfig();
    const copies = config.printer.copies || 1;

    const dummyOrder = {
      id: 'TEST-001',
      numero_ordine: '99',
      created_at: new Date().toISOString(),
      tipo_ordine: 'takeaway',
      nome_cliente: 'Mario Rossi',
      telefono_cliente: '333 1234567',
      note: 'Test stampante',
      totale: 15.50
    };
    const dummyItems = [
      { nome_prodotto: 'Margherita', quantita: 1, prezzo_unitario: 6.00, varianti: { size: { name: 'Piatto' } } },
      { nome_prodotto: 'Coca Cola', quantita: 2, prezzo_unitario: 2.50, varianti: { size: { name: 'Bibite' } } }
    ];

    // Print all copies
    for (let copyNum = 1; copyNum <= copies; copyNum++) {
      await enqueuePrintJob(() => withPrinter(printer => printReceipt(printer, dummyOrder, dummyItems, config, copyNum)));
    }

    logger.info(`Test print completed (${copies} copies)`);
    res.json({ ok: true, copies });
  } catch (err) {
    logger.error(`Test print error: ${err.message}`);
    res.status(500).json({ ok: false, error: err.message });
  }
});


// ---- Supabase Logic ----
async function fetchAllOrders() {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('ordini')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(20);
  if (error) throw error;
  return data || [];
}

async function fetchOrderById(orderId) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('ordini')
    .select('*')
    .eq('id', orderId)
    .single();
  if (error) throw error;
  return data;
}

async function fetchOrderItems(orderId) {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('ordini_items')
    .select('*, menu_items!inner(categoria_id, nome, categorie_menu!inner(nome))')
    .order('categoria_id', { referencedTable: 'menu_items', ascending: true })
    .eq('ordine_id', orderId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data || [];
}

async function fetchOrdersToPrint() {
  if (!supabase) return [];
  // Calculate today's date range (local time)
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
  const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);

  const { data, error } = await supabase
    .from('ordini')
    .select('*')
    .in('stato', ['ready', 'confirmed'])
    .eq('printed', false)
    .gte('slot_prenotato_start', startOfDay.toISOString())
    .lt('slot_prenotato_start', endOfDay.toISOString())
    .order('slot_prenotato_start', { ascending: true })
    .limit(5);
  if (error) {
    logger.error(`Fetch orders to print error: ${error.message}`);
    return [];
  }
  return data || [];
}

async function markOrderPrinted(orderId) {
  if (!supabase) return;
  const { error } = await supabase.from('ordini').update({ printed: true }).eq('id', orderId);
  if (error) logger.error(`Error marking order ${orderId} printed: ${error.message}`);
}

async function fetchCancelledOrdersToPrint() {
  if (!supabase) return [];
  // Calculate today's date range (local time)
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
  const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);

  const { data, error } = await supabase
    .from('ordini')
    .select('*')
    .eq('stato', 'cancelled')
    .eq('is_cancelled_printed', false)
    .gte('slot_prenotato_start', startOfDay.toISOString())
    .lt('slot_prenotato_start', endOfDay.toISOString())
    .order('slot_prenotato_start', { ascending: true })
    .limit(5);
  if (error) {
    logger.error(`Fetch cancelled orders to print error: ${error.message}`);
    return [];
  }
  return data || [];
}

async function markCancelledOrderPrinted(orderId) {
  if (!supabase) return;
  const { error } = await supabase.from('ordini').update({ is_cancelled_printed: true }).eq('id', orderId);
  if (error) logger.error(`Error marking cancelled order ${orderId} printed: ${error.message}`);
}

async function fetchPagatoOrdersToPrint() {
  if (!supabase) return [];
  // Calculate today's date range (local time)
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
  const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);

  const { data, error } = await supabase
    .from('ordini')
    .select('*')
    .eq('pagato', true)
    .eq('is_pagato_printed', false)
    .gte('created_at', startOfDay.toISOString())
    .lt('created_at', endOfDay.toISOString())
    .order('created_at', { ascending: true })
    .limit(5);
  if (error) {
    logger.error(`Fetch pagato orders to print error: ${error.message}`);
    return [];
  }
  return data || [];
}

async function markPagatoOrderPrinted(orderId) {
  if (!supabase) return;
  const { error } = await supabase.from('ordini').update({ is_pagato_printed: true }).eq('id', orderId);
  if (error) logger.error(`Error marking pagato order ${orderId} printed: ${error.message}`);
}

async function processPendingOrders() {
  try {
    // Process confirmed orders
    const orders = await fetchOrdersToPrint();
    if (orders.length > 0) {
      logger.info(`Found ${orders.length} orders to print`);
      const config = getConfig();
      const copies = config.printer.copies || 1;

      for (const order of orders) {
        try {
          const items = await fetchOrderItems(order.id);

          // Print all copies
          for (let copyNum = 1; copyNum <= copies; copyNum++) {
            await enqueuePrintJob(() => withPrinter(printer => printReceipt(printer, order, items, config, copyNum)));
          }

          await markOrderPrinted(order.id);
          logger.info(`Order ${order.id} printed successfully (${copies} copies)`);
        } catch (err) {
          logger.error(`Failed to print order ${order.id}: ${err.message}`);
        }
      }
    }

    // Process cancelled orders
    const cancelledOrders = await fetchCancelledOrdersToPrint();
    if (cancelledOrders.length > 0) {
      logger.info(`Found ${cancelledOrders.length} cancelled orders to print`);
      const config = getConfig();
      // Cancelled orders typically only need 1 copy

      for (const order of cancelledOrders) {
        try {
          await enqueuePrintJob(() => withPrinter(printer => printCancelledReceipt(printer, order, config)));
          await markCancelledOrderPrinted(order.id);
          logger.info(`Cancelled order ${order.id} printed successfully`);
        } catch (err) {
          logger.error(`Failed to print cancelled order ${order.id}: ${err.message}`);
        }
      }
    }

    // Process pagato (paid) orders - prints exactly ONE copy regardless of settings
    const pagatoOrders = await fetchPagatoOrdersToPrint();
    if (pagatoOrders.length > 0) {
      logger.info(`Found ${pagatoOrders.length} pagato orders to print`);
      const config = getConfig();

      for (const order of pagatoOrders) {
        try {
          const items = await fetchOrderItems(order.id);
          // Print exactly 1 copy for pagato receipts (ignores copies setting)
          await enqueuePrintJob(() => withPrinter(printer => printPagatoReceipt(printer, order, items, config)));
          await markPagatoOrderPrinted(order.id);
          logger.info(`Pagato order ${order.id} printed successfully (1 copy)`);
        } catch (err) {
          logger.error(`Failed to print pagato order ${order.id}: ${err.message}`);
        }
      }
    }
  } catch (err) {
    logger.error(`Process pending orders loop error: ${err.message}`);
  }
}

// ---- Initialization ----
loadConfig().then(() => {
  app.listen(PORT, () => {
    logger.info(`Printer server listening on http://localhost:${PORT}`);
    if (supabase) {
      logger.info('Starting Supabase polling...');
      setInterval(processPendingOrders, 2000); // Poll every 2s
    }
  });
});
