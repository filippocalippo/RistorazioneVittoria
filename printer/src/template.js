const logger = require('./logger');

// Helper: Normalize text
function sanitizeText(input) {
  if (!input) return '';
  return String(input)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // remove diacritics
    .replace(/€/g, 'EUR') // replace euro symbol
    .replace(/\s+/g, ' ') // normalize spaces
    .trim();
}

// Helper: Print wrapped text with indentation
function printIndentedWrapped(printer, rawText, indentSpaces, maxWidth = 48) {
  const indent = ' '.repeat(indentSpaces);
  const clean = sanitizeText(rawText);
  if (!clean) return;

  const words = clean.split(' ');
  let currentLine = '';

  for (const word of words) {
    const tentative = currentLine ? `${currentLine} ${word}` : word;
    if ((indent + tentative).length > maxWidth && currentLine) {
      printer.text(indent + currentLine);
      currentLine = word;
    } else {
      currentLine = tentative;
    }
  }

  if (currentLine) {
    printer.text(indent + currentLine);
  }
}

// Helper: Convert size factor to printer size values
// ESC/POS uses integers 0-7 for magnification (0 = 1x, 1 = 2x, etc.)
function getSizeValues(factor) {
  const f = factor || 1;

  // Refined mapping for smoother transitions:
  // < 1.25       -> 0,0 (Normal 1x)
  // 1.25 - 1.74  -> 0,1 (Normal Width, Double Height) - "Tall"
  // 1.75 - 2.24  -> 1,1 (Double Width, Double Height) - "Big"
  // >= 2.25      -> 2,2 (Triple Size) - "Huge"

  if (f >= 2.25) return { width: 2, height: 2, factor: f };
  if (f >= 1.75) return { width: 1, height: 1, factor: f };
  if (f >= 1.25) return { width: 0, height: 1, factor: f };

  // Default to Normal (0,0)
  return { width: 0, height: 0, factor: f };
}

// Helper: Prepare items (parse variants)
function prepareItems(items) {
  return items.map(rawItem => {
    let parsedVariants = null;
    let sizeName = '';

    if (rawItem.varianti) {
      try {
        const v = typeof rawItem.varianti === 'string'
          ? JSON.parse(rawItem.varianti)
          : rawItem.varianti;
        parsedVariants = v;
        const size = v?.size;
        if (size && typeof size === 'object') {
          sizeName = size.name || size.nome || '';
        }
      } catch (err) {
        logger.warn(`Error parsing variants for item ${rawItem.id}: ${err.message}`);
      }
    }

    return {
      ...rawItem,
      _parsedVariants: parsedVariants,
      _sizeName: sizeName,
    };
  });
}

// Main Printing Function
// copyNumber: optional, 1-indexed copy number. If > 1, prints "ORDINE COPIA N" header
async function printReceipt(printer, order, items, config, copyNumber = 1) {
  const { template, printer: printerConfig, spacing = {}, textSizing = {}, qrCode = {} } = config;
  const width = printerConfig.width || 48;

  // Get text sizing with defaults
  const sizing = {
    headerTitle: textSizing.headerTitle ?? 1.2,
    headerSubtitle: textSizing.headerSubtitle ?? 1.0,
    orderType: textSizing.orderType ?? 1.2,
    orderNumber: textSizing.orderNumber ?? 1.2,
    orderTime: textSizing.orderTime ?? 1.0,
    sectionLabels: textSizing.sectionLabels ?? 1.0,
    customerInfo: textSizing.customerInfo ?? 1.0,
    deliveryAddress: textSizing.deliveryAddress ?? 1.0,
    categoryHeaders: textSizing.categoryHeaders ?? 1.0,
    productNames: textSizing.productNames ?? 1.0,
    productMods: textSizing.productMods ?? 0.9,
    prices: textSizing.prices ?? 1.0,
    total: textSizing.total ?? 1.2,
    notes: textSizing.notes ?? 1.0,
    footer: textSizing.footer ?? 1.0,
    copyHeader: textSizing.copyHeader ?? 1.75,
    modifiedHeader: textSizing.modifiedHeader ?? 1.75,
  };

  // Spacing configuration with defaults
  const headerMarginBottom = spacing.headerMarginBottom ?? 1;
  const customerMarginBottom = spacing.customerMarginBottom ?? 1;
  const deliveryMarginBottom = spacing.deliveryMarginBottom ?? 1;
  const itemsMarginTop = spacing.itemsMarginTop ?? 1;
  const itemsMarginBottom = spacing.itemsMarginBottom ?? 1;
  const categoryGap = spacing.categoryGap ?? 1;
  const footerMarginTop = spacing.footerMarginTop ?? 2;

  // QR Code settings with defaults
  const qrSettings = {
    enabled: qrCode.enabled ?? true,
    showOnlyDelivery: qrCode.showOnlyDelivery ?? true,
    size: qrCode.size ?? 6,
    label: qrCode.label ?? '',
    marginTop: qrCode.marginTop ?? 1,
    marginBottom: qrCode.marginBottom ?? 1,
  };

  // Helper to add blank lines
  const addBlankLines = (count) => {
    for (let i = 0; i < count; i++) {
      printer.text('');
    }
  };

  // Helper to set text size based on factor
  const setTextSize = (factor) => {
    const sizeVal = getSizeValues(factor);
    printer.size(sizeVal.width, sizeVal.height);
  };

  // Data extraction
  const numeroOrdine = order.numero_ordine || order.id;
  const tipo = order.tipo_ordine || order.tipo || '';
  const tipoLabel = tipo === 'delivery' ? 'CONSEGNA' : (tipo === 'takeaway' ? 'ASPORTO' : 'ORDINE');

  const scheduledTime = order.slot_prenotato_start
    ? new Date(order.slot_prenotato_start).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })
    : '';

  const consegnaTime = order.slot_prenotato_start
    ? new Date(order.slot_prenotato_start).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })
    : null;

  // Fallback to order creation time if no scheduled time
  const createdAtTime = order.created_at
    ? new Date(order.created_at).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })
    : null;

  // --- MODIFIED ORDER HEADER ---
  // An order is considered modified if updated_at is significantly after created_at (more than 60 seconds)
  const createdAt = order.created_at ? new Date(order.created_at).getTime() : 0;
  const updatedAt = order.updated_at ? new Date(order.updated_at).getTime() : 0;
  const isModified = updatedAt > 0 && (updatedAt - createdAt) > 60000; // 60 seconds threshold

  if (isModified) {
    printer.align('ct');
    setTextSize(sizing.modifiedHeader);
    printer.text('');
    printer.text(sanitizeText('*** ORDINE MODIFICATO ***'));
    printer.text('');
    setTextSize(1);
  }

  // --- COPY HEADER (for copies beyond the first) ---
  if (copyNumber > 1) {
    printer.align('ct');
    setTextSize(sizing.copyHeader);
    printer.text('');
    printer.text(sanitizeText(`*** COPIA ${copyNumber} ***`));
    printer.text('');
    setTextSize(1);
  }

  // --- HEADER ---
  printer.align('ct');
  if (template.headerTitle) {
    setTextSize(sizing.headerTitle);
    printer.text(sanitizeText(template.headerTitle));
  }
  if (template.headerSubtitle) {
    setTextSize(sizing.headerSubtitle);
    printer.text(sanitizeText(template.headerSubtitle));
  }

  setTextSize(sizing.orderType);
  printer.text(sanitizeText(tipoLabel));

  setTextSize(sizing.orderNumber);
  printer.text(sanitizeText(`ORDINE #${numeroOrdine}`));

  // Times
  if (template.showOrderTime) {
    setTextSize(sizing.orderTime);
    if (consegnaTime) {
      printer.text(sanitizeText(`CONSEGNA: ${consegnaTime}`));
    } else if (createdAtTime) {
      printer.text(sanitizeText(`ORA ORDINE: ${createdAtTime}`));
    }
  }

  // Header spacing
  setTextSize(1);
  addBlankLines(headerMarginBottom);

  printer.align('lt');

  // --- CUSTOMER ---
  if (template.showCustomerName || template.showCustomerPhone) {
    setTextSize(sizing.sectionLabels);
    printer.text('CLIENTE');
    setTextSize(sizing.customerInfo);
    if (template.showCustomerName && order.nome_cliente) {
      printer.text(sanitizeText(order.nome_cliente));
    }
    if (template.showCustomerPhone && order.telefono_cliente) {
      printer.text(sanitizeText(`TEL: ${order.telefono_cliente}`));
    }
  }

  // Customer section spacing
  setTextSize(1);
  addBlankLines(customerMarginBottom);

  // --- DELIVERY ---
  if (tipo === 'delivery' && template.showDeliveryAddress) {
    setTextSize(sizing.sectionLabels);
    printer.text('CONSEGNA');
    setTextSize(sizing.deliveryAddress);
    if (order.indirizzo_consegna) {
      printer.text(sanitizeText(order.indirizzo_consegna));
    }
    const cityLine = [order.cap_consegna, order.citta_consegna].filter(Boolean).join(' ');
    if (cityLine) {
      printer.text(sanitizeText(cityLine));
    }
    if (consegnaTime) {
      printer.text(sanitizeText(`ORARIO: ${consegnaTime}`));
    }
    if (order.zone) {
      printer.text(sanitizeText(`ZONA: ${order.zone}`));
    }
    setTextSize(1);
    addBlankLines(deliveryMarginBottom);
  }

  // Items section top spacing
  addBlankLines(itemsMarginTop);
  setTextSize(sizing.sectionLabels);
  printer.text('ORDINE');
  setTextSize(1);

  // --- ITEMS ---
  const preparedItems = prepareItems(items);

  // Group by Size (Course)
  const itemsBySize = new Map();
  for (const item of preparedItems) {
    const groupKey = item._sizeName || 'SENZA TAGLIA';
    if (!itemsBySize.has(groupKey)) itemsBySize.set(groupKey, []);
    itemsBySize.get(groupKey).push(item);
  }

  let isFirstCategory = true;
  for (const [sizeHeader, sizeItems] of itemsBySize.entries()) {
    if (!isFirstCategory && template.showCategoryDividers !== false) {
      addBlankLines(categoryGap);
    }
    isFirstCategory = false;

    if (template.showCategoryDividers !== false) {
      printer.text('-'.repeat(Math.min(30, width)));
    }
    setTextSize(sizing.categoryHeaders);
    printer.text(sanitizeText(sizeHeader.toUpperCase()));
    setTextSize(1);
    printer.text('');

    for (const item of sizeItems) {
      const qta = item.quantita || 1;
      const nomeProdotto = item.nome_prodotto || '';
      let lineName;

      // Handle Split Pizza Naming
      if (nomeProdotto.includes('(Diviso)')) {
        const baseName = nomeProdotto.replace(' (Diviso)', '').trim();
        const parts = baseName.split(' + ');
        if (parts.length === 2) {
          lineName = `${qta}x 1/2 ${parts[0]} 1/2 ${parts[1]}`;
        } else {
          lineName = `${qta}x ${baseName}`;
        }
      } else {
        lineName = `${qta}x ${nomeProdotto}`;
      }

      // Product name with optional price
      setTextSize(sizing.productNames);
      if (template.showPrices && item.prezzo_unitario != null) {
        const unitPrice = Number(item.prezzo_unitario);
        if (!Number.isNaN(unitPrice)) {
          const lineSubtotal = unitPrice * qta;
          setTextSize(sizing.prices);
          const lineWithPrice = `${lineName} - EUR ${lineSubtotal.toFixed(2)}`;
          printer.text(sanitizeText(lineWithPrice));
        } else {
          printer.text(sanitizeText(lineName));
        }
      } else {
        printer.text(sanitizeText(lineName));
      }

      // Variants / Mods
      if (item._parsedVariants) {
        try {
          const v = item._parsedVariants;
          const specialOptions = Array.isArray(v?.specialOptions) ? v.specialOptions : [];
          const isSplitProduct = specialOptions.length === 2 &&
            specialOptions[0]?.id === 'split_first' &&
            specialOptions[1]?.id === 'split_second';

          setTextSize(sizing.productMods);
          if (isSplitProduct) {
            const [first, second] = specialOptions;

            const extractMods = desc => {
              if (!desc) return '';
              const start = desc.indexOf('(');
              const end = desc.lastIndexOf(')');
              if (start === -1 || end === -1 || end <= start) return '';
              return desc.slice(start + 1, end).trim();
            };

            const firstMods = extractMods(first.description || '');
            const secondMods = extractMods(second.description || '');

            if (firstMods) {
              printer.text(`  > ${sanitizeText(first.name || 'Prima meta')}`);
              printIndentedWrapped(printer, firstMods, 4, width);
            }
            if (secondMods) {
              printer.text(`  > ${sanitizeText(second.name || 'Seconda meta')}`);
              printIndentedWrapped(printer, secondMods, 4, width);
            }

            // Print note from variants for split products (if not already in item.note)
            if (template.showNotes && v?.note && !item.note) {
              setTextSize(sizing.notes);
              printer.text(sanitizeText(`  NOTE: ${v.note}`));
            }
          } else {
            const added = v?.addedIngredients ?? [];
            const removed = v?.removedIngredients ?? [];
            const modsTokens = [];

            for (const ing of added) {
              const name = ing.name ?? ing.nome ?? '';
              const quantity = ing.quantity ?? 1;
              if (name) modsTokens.push(`+ ${name}${quantity > 1 ? ' x' + quantity : ''}`);
            }
            for (const ing of removed) {
              const name = ing.name ?? ing.nome ?? '';
              if (name) modsTokens.push(`- ${name}`);
            }

            if (modsTokens.length) {
              printIndentedWrapped(printer, modsTokens.join(', '), 5, width);
            }
          }
        } catch (err) {
          logger.warn(`Error printing variants: ${err.message}`);
        }
      }

      if (template.showNotes && item.note) {
        setTextSize(sizing.notes);
        printer.text(sanitizeText(`  NOTE: ${item.note}`));
      }
      setTextSize(1);
      printer.text('');
    }
  }

  if (template.showCategoryDividers !== false) {
    printer.text('-'.repeat(Math.min(30, width)));
  }

  // Items section bottom spacing
  addBlankLines(itemsMarginBottom);

  // --- DELIVERY FEE & TOTAL ---
  if (template.showPrices && order.totale != null) {
    printer.align('rt');
    // Show delivery fee if present
    if (order.costo_consegna != null && Number(order.costo_consegna) > 0) {
      setTextSize(sizing.total);
      printer.text(sanitizeText(`COSTO CONSEGNA ${Number(order.costo_consegna).toFixed(2)} EUR`));
    }
    setTextSize(sizing.total);
    printer.text(sanitizeText(`TOTALE EUR ${Number(order.totale).toFixed(2)}`));
    printer.align('lt');
    setTextSize(1);
  }

  // --- FOOTER NOTES ---
  if (template.showNotes && order.note) {
    printer.text('');
    setTextSize(sizing.notes);
    printer.text('NOTE ORDINE:');
    printer.text(sanitizeText(order.note));
    setTextSize(1);
  }

  // --- FOOTER TEXT ---
  if (template.footerText) {
    addBlankLines(footerMarginTop);
    printer.align('ct');
    setTextSize(sizing.footer);
    printer.text(sanitizeText(template.footerText));
    setTextSize(1);
  }

  // --- QR CODE FOR DRIVER ASSIGNMENT ---
  const shouldShowQR = qrSettings.enabled &&
    (!qrSettings.showOnlyDelivery || tipo === 'delivery');

  if (shouldShowQR) {
    addBlankLines(qrSettings.marginTop);
    printer.align('ct');

    if (qrSettings.label) {
      printer.text(sanitizeText(qrSettings.label));
    }

    try {
      // Use qrimage (raster) for reliability (native qrcode caused hangs)
      // We wrap it in a Promise because qrimage uses an async callback
      await new Promise((resolve, reject) => {
        printer.qrimage((order.id || numeroOrdine).toString(), {
          type: 'png',
          size: 8,       // ADJUST QR SIZE HERE (Pixel size per module). Was 4.
          mode: 'normal' // Printer raster mode
        }, (err) => {
          if (err) reject(err);
          else resolve();
        });
      });

      addBlankLines(qrSettings.marginBottom);
    } catch (err) {
      logger.warn(`Error printing QR code: ${err.message}`);
    }
  }

  // Ensure enough feed before cut so QR/footer isn't sliced
  addBlankLines(6);
  printer.cut();
}


// Cancelled Order Receipt
async function printCancelledReceipt(printer, order, config) {
  const { printer: printerConfig, textSizing = {} } = config;
  const width = printerConfig.width || 48;

  // Get sizing values
  const sizing = {
    headerTitle: textSizing.headerTitle ?? 1.2,
    orderNumber: textSizing.orderNumber ?? 1.2,
    sectionLabels: textSizing.sectionLabels ?? 1.0,
    customerInfo: textSizing.customerInfo ?? 1.0,
    deliveryAddress: textSizing.deliveryAddress ?? 1.0,
    notes: textSizing.notes ?? 1.0,
  };

  // Helper to add blank lines
  const addBlankLines = (count) => {
    for (let i = 0; i < count; i++) {
      printer.text('');
    }
  };

  // Helper to set text size
  const setTextSize = (factor) => {
    const sizeVal = getSizeValues(factor);
    printer.size(sizeVal.width, sizeVal.height);
  };

  // Data extraction
  const numeroOrdine = order.numero_ordine || order.id;
  const tipo = order.tipo_ordine || order.tipo || '';
  const tipoLabel = tipo === 'delivery' ? 'CONSEGNA' : (tipo === 'takeaway' ? 'ASPORTO' : 'ORDINE');

  const scheduledTime = order.slot_prenotato_start
    ? new Date(order.slot_prenotato_start).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })
    : '';

  const cancelledTime = order.cancellato_at
    ? new Date(order.cancellato_at).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })
    : '';

  // --- HEADER ---
  printer.align('ct');
  setTextSize(sizing.headerTitle);
  printer.text('');
  printer.text('ORDINE CANCELLATO');
  printer.text('');

  // Switch to content size for the rest of the ticket
  setTextSize(1);
  printer.text(sanitizeText(tipoLabel));
  setTextSize(sizing.orderNumber);
  printer.text(sanitizeText(`ORDINE #${numeroOrdine}`));
  setTextSize(1);

  if (scheduledTime) {
    printer.text(sanitizeText(`ORARIO PRENOTATO: ${scheduledTime}`));
  }
  if (cancelledTime) {
    printer.text(sanitizeText(`ORA ANNULLAMENTO: ${cancelledTime}`));
  }

  printer.text('');
  printer.align('lt');

  // --- CUSTOMER INFO ---
  setTextSize(sizing.sectionLabels);
  printer.text('CLIENTE');
  setTextSize(sizing.customerInfo);
  if (order.nome_cliente) {
    printer.text(sanitizeText(order.nome_cliente));
  }
  if (order.telefono_cliente) {
    printer.text(sanitizeText(`TEL: ${order.telefono_cliente}`));
  }
  if (order.email_cliente) {
    printer.text(sanitizeText(`EMAIL: ${order.email_cliente}`));
  }
  setTextSize(1);

  // --- DELIVERY INFO (if applicable) ---
  if (tipo === 'delivery') {
    printer.text('');
    setTextSize(sizing.sectionLabels);
    printer.text('INDIRIZZO CONSEGNA');
    setTextSize(sizing.deliveryAddress);
    if (order.indirizzo_consegna) {
      printer.text(sanitizeText(order.indirizzo_consegna));
    }
    const cityLine = [order.cap_consegna, order.citta_consegna].filter(Boolean).join(' ');
    if (cityLine) {
      printer.text(sanitizeText(cityLine));
    }
    setTextSize(1);
  }

  printer.text('');
  printer.text('-'.repeat(Math.min(30, width)));

  // Show delivery fee if present
  if (order.costo_consegna != null && Number(order.costo_consegna) > 0) {
    printer.text(sanitizeText(`COSTO CONSEGNA ${Number(order.costo_consegna).toFixed(2)} EUR`));
  }
  if (order.totale != null) {
    printer.text(sanitizeText(`TOTALE: EUR ${Number(order.totale).toFixed(2)}`));
  }

  // --- CANCELLATION REASON (if available) ---
  if (order.note) {
    printer.text('');
    setTextSize(sizing.notes);
    printer.text('NOTE:');
    printer.text(sanitizeText(order.note));
    setTextSize(1);
  }

  printer.text('');
  printer.text('-'.repeat(Math.min(30, width)));

  // Footer with same size as header
  printer.align('ct');
  setTextSize(sizing.headerTitle);
  printer.text('');
  printer.text('ORDINE CANCELLATO');
  setTextSize(1);

  // Ensure enough feed before cut so QR/footer isn't sliced
  addBlankLines(6);
  printer.cut();
}

// Pagato (Paid) Receipt - prints once when order is marked as paid
async function printPagatoReceipt(printer, order, items, config) {
  const { template, printer: printerConfig, textSizing = {} } = config;
  const width = printerConfig.width || 48;

  // Get sizing values
  const sizing = {
    headerTitle: textSizing.headerTitle ?? 1.2,
    orderNumber: textSizing.orderNumber ?? 1.2,
    sectionLabels: textSizing.sectionLabels ?? 1.0,
    customerInfo: textSizing.customerInfo ?? 1.0,
    categoryHeaders: textSizing.categoryHeaders ?? 1.0,
    productNames: textSizing.productNames ?? 1.0,
    total: textSizing.total ?? 1.2,
  };

  // Helper to add blank lines
  const addBlankLines = (count) => {
    for (let i = 0; i < count; i++) {
      printer.text('');
    }
  };

  // Helper to set text size
  const setTextSize = (factor) => {
    const sizeVal = getSizeValues(factor);
    printer.size(sizeVal.width, sizeVal.height);
  };

  // Data extraction
  const numeroOrdine = order.numero_ordine || order.id;
  const tipo = order.tipo_ordine || order.tipo || '';
  const tipoLabel = tipo === 'delivery' ? 'CONSEGNA' : (tipo === 'takeaway' ? 'ASPORTO' : 'ORDINE');

  // === TOP "PAGATO" HEADER ===
  printer.align('ct');
  setTextSize(2.5); // Extra large
  printer.text('');
  printer.text('');
  printer.text(sanitizeText('*** PAGATO ***'));
  printer.text('');
  setTextSize(1);

  // === ORDER INFO ===
  printer.text('-'.repeat(Math.min(30, width)));
  setTextSize(sizing.orderType ?? 1.2);
  printer.text(sanitizeText(tipoLabel));
  setTextSize(sizing.orderNumber);
  printer.text(sanitizeText(`ORDINE #${numeroOrdine}`));
  setTextSize(1);
  printer.text('');

  // === CUSTOMER ===
  printer.align('lt');
  if (order.nome_cliente) {
    setTextSize(sizing.sectionLabels);
    printer.text('CLIENTE');
    setTextSize(sizing.customerInfo);
    printer.text(sanitizeText(order.nome_cliente));
    if (order.telefono_cliente) {
      printer.text(sanitizeText(`TEL: ${order.telefono_cliente}`));
    }
    setTextSize(1);
    printer.text('');
  }

  // === ITEMS ===
  const preparedItems = prepareItems(items);

  // Group by Size (Course)
  const itemsBySize = new Map();
  for (const item of preparedItems) {
    const groupKey = item._sizeName || 'SENZA TAGLIA';
    if (!itemsBySize.has(groupKey)) itemsBySize.set(groupKey, []);
    itemsBySize.get(groupKey).push(item);
  }

  setTextSize(sizing.sectionLabels);
  printer.text('ORDINE');
  setTextSize(1);

  for (const [sizeHeader, sizeItems] of itemsBySize.entries()) {
    printer.text('-'.repeat(Math.min(30, width)));
    setTextSize(sizing.categoryHeaders);
    printer.text(sanitizeText(sizeHeader.toUpperCase()));
    setTextSize(1);
    printer.text('');

    for (const item of sizeItems) {
      const qta = item.quantita || 1;
      const nomeProdotto = item.nome_prodotto || '';
      let lineName;

      // Handle Split Pizza Naming
      if (nomeProdotto.includes('(Diviso)')) {
        const baseName = nomeProdotto.replace(' (Diviso)', '').trim();
        const parts = baseName.split(' + ');
        if (parts.length === 2) {
          lineName = `${qta}x 1/2 ${parts[0]} 1/2 ${parts[1]}`;
        } else {
          lineName = `${qta}x ${baseName}`;
        }
      } else {
        lineName = `${qta}x ${nomeProdotto}`;
      }

      setTextSize(sizing.productNames);
      printer.text(sanitizeText(lineName));
      setTextSize(1);
    }
  }

  printer.text('-'.repeat(Math.min(30, width)));
  printer.text('');

  // === DELIVERY FEE & TOTAL ===
  if (order.totale != null) {
    printer.align('rt');
    // Show delivery fee if present
    if (order.costo_consegna != null && Number(order.costo_consegna) > 0) {
      setTextSize(sizing.total);
      printer.text(sanitizeText(`COSTO CONSEGNA ${Number(order.costo_consegna).toFixed(2)} EUR`));
    }
    setTextSize(sizing.total);
    printer.text(sanitizeText(`TOTALE EUR ${Number(order.totale).toFixed(2)}`));
    setTextSize(1);
    printer.align('lt');
  }

  printer.text('');

  // === BOTTOM "PAGATO" FOOTER ===
  printer.align('ct');
  printer.text('-'.repeat(Math.min(30, width)));
  setTextSize(2.5); // Extra large
  printer.text('');
  printer.text(sanitizeText('*** PAGATO ***'));
  printer.text('');
  setTextSize(1);

  // Ensure enough feed before cut
  addBlankLines(6);
  printer.cut();
}

module.exports = {
  printReceipt,
  printCancelledReceipt,
  printPagatoReceipt,
  sanitizeText
};
