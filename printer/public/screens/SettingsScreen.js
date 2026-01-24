import React, { useEffect, useState, useMemo } from 'https://esm.sh/react@18';

const e = React.createElement;

// Sample order data for preview
const SAMPLE_ORDER = {
  id: 'abc-123-def-456',
  numero_ordine: '42',
  tipo_ordine: 'delivery',
  created_at: new Date().toISOString(),
  slot_prenotato_start: new Date(Date.now() + 3600000).toISOString(),
  nome_cliente: 'Mario Rossi',
  telefono_cliente: '333 1234567',
  indirizzo_consegna: 'Via Roma 123',
  cap_consegna: '00100',
  citta_consegna: 'Roma',
  note: 'Suonare al citofono 2',
  totale: 28.50,
  zone: 'Zona Rossa'
};

const SAMPLE_ITEMS = [
  { nome_prodotto: 'Margherita', quantita: 1, prezzo_unitario: 7.00, _sizeName: 'Pizza' },
  { nome_prodotto: 'Diavola', quantita: 2, prezzo_unitario: 8.50, _sizeName: 'Pizza', _mods: '+ Olive, + Funghi' },
  { nome_prodotto: 'Coca Cola 33cl', quantita: 2, prezzo_unitario: 2.50, _sizeName: 'Bevande' },
];

// Default config structure
const DEFAULT_CONFIG = {
  printer: { encoding: 'CP858', width: 48, copies: 1 },
  textSizing: {
    headerTitle: 1.2,
    headerSubtitle: 1.0,
    orderType: 1.2,
    orderNumber: 1.2,
    orderTime: 1.0,
    sectionLabels: 1.0,
    customerInfo: 1.0,
    deliveryAddress: 1.0,
    categoryHeaders: 1.0,
    productNames: 1.0,
    productMods: 0.9,
    prices: 1.0,
    total: 1.2,
    notes: 1.0,
    footer: 1.0,
    copyHeader: 1.2
  },
  template: {
    headerTitle: 'PIZZERIA ROTANTE',
    headerSubtitle: '',
    footerText: 'Grazie per averci scelto!',
    showCustomerName: true,
    showCustomerPhone: true,
    showDeliveryAddress: true,
    showOrderTime: true,
    showNotes: true,
    showPrices: true,
    showCategoryDividers: true,
    compactMode: false
  },
  spacing: {
    headerMarginBottom: 1,
    customerMarginBottom: 1,
    deliveryMarginBottom: 1,
    itemsMarginTop: 1,
    itemsMarginBottom: 1,
    categoryGap: 1,
    footerMarginTop: 2
  },
  qrCode: {
    enabled: true,
    showOnlyDelivery: true,
    size: 6,
    label: '',
    marginTop: 1,
    marginBottom: 1
  }
};

export default function SettingsScreen() {
  const [config, setConfig] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState({ type: '', message: '' });
  const [activeTab, setActiveTab] = useState('template');
  const [previewType, setPreviewType] = useState('delivery'); // 'delivery' | 'takeaway'
  const [showCopyPreview, setShowCopyPreview] = useState(false);

  useEffect(() => {
    loadSettings();
  }, []);

  async function loadSettings() {
    try {
      const res = await fetch('/api/settings');
      const data = await res.json();
      if (data.ok) {
        // Deep merge with defaults to ensure all properties exist
        const cfg = deepMerge(DEFAULT_CONFIG, data.config);
        setConfig(cfg);
      } else {
        throw new Error(data.error);
      }
    } catch (err) {
      console.error(err);
      setStatus({ type: 'error', message: 'Error loading settings: ' + err.message });
    } finally {
      setLoading(false);
    }
  }

  function deepMerge(target, source) {
    const result = { ...target };
    for (const key of Object.keys(source || {})) {
      if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        result[key] = deepMerge(target[key] || {}, source[key]);
      } else if (source[key] !== undefined) {
        result[key] = source[key];
      }
    }
    return result;
  }

  async function handleSave() {
    setSaving(true);
    setStatus({ type: '', message: '' });
    try {
      const res = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config)
      });
      const data = await res.json();
      if (data.ok) {
        setConfig(deepMerge(DEFAULT_CONFIG, data.config));
        setStatus({ type: 'success', message: 'Settings saved successfully!' });
        setTimeout(() => setStatus({ type: '', message: '' }), 3000);
      } else {
        throw new Error(data.error);
      }
    } catch (err) {
      setStatus({ type: 'error', message: 'Error saving: ' + err.message });
    } finally {
      setSaving(false);
    }
  }

  async function handleTestPrint() {
    setStatus({ type: '', message: 'Sending test print...' });
    try {
      const res = await fetch('/api/test-print', { method: 'POST' });
      const data = await res.json();
      if (data.ok) {
        setStatus({ type: 'success', message: 'Test print sent!' });
        setTimeout(() => setStatus({ type: '', message: '' }), 3000);
      } else {
        throw new Error(data.error);
      }
    } catch (err) {
      setStatus({ type: 'error', message: 'Error printing: ' + err.message });
    }
  }

  const handleChange = (section, key, value) => {
    setConfig(prev => ({
      ...prev,
      [section]: {
        ...prev[section],
        [key]: value
      }
    }));
  };

  if (loading) {
    return e('div', { className: 'settings-page' },
      e('div', { className: 'settings-loading' },
        e('div', { className: 'spinner' }),
        e('span', null, 'Loading settings...')
      )
    );
  }

  // Tab content components
  const tabs = [
    { id: 'template', label: 'Template', icon: '📝' },
    { id: 'textSizing', label: 'Text Sizing', icon: '🔤' },
    { id: 'spacing', label: 'Spacing', icon: '↕️' },
    { id: 'qrCode', label: 'QR Code', icon: '📱' },
    { id: 'printer', label: 'Printer', icon: '🖨️' }
  ];

  return e('div', { className: 'settings-page' },
    // Left: Settings Panel
    e('div', { className: 'settings-panel' },
      e('div', { className: 'settings-panel-header' },
        e('h1', { className: 'settings-title' }, 'Receipt Settings'),
        e('p', { className: 'settings-subtitle' }, 'Configure every aspect of your receipts')
      ),

      // Tabs
      e('div', { className: 'settings-tabs' },
        tabs.map(tab =>
          e('button', {
            key: tab.id,
            className: `settings-tab ${activeTab === tab.id ? 'active' : ''}`,
            onClick: () => setActiveTab(tab.id)
          },
            e('span', { className: 'tab-icon' }, tab.icon),
            e('span', null, tab.label)
          )
        )
      ),

      // Tab Content
      e('div', { className: 'settings-content' },
        activeTab === 'template' && e(TemplateSettings, { config, handleChange }),
        activeTab === 'textSizing' && e(TextSizingSettings, { config, handleChange }),
        activeTab === 'spacing' && e(SpacingSettings, { config, handleChange }),
        activeTab === 'qrCode' && e(QRCodeSettings, { config, handleChange }),
        activeTab === 'printer' && e(PrinterSettings, { config, handleChange, handleTestPrint })
      ),

      // Action Bar
      e('div', { className: 'settings-actions' },
        status.message && e('span', {
          className: `settings-status ${status.type}`
        }, status.message),
        e('button', {
          className: 'button button-primary',
          onClick: handleSave,
          disabled: saving
        }, saving ? 'Saving...' : 'Save Changes')
      )
    ),

    // Right: Preview
    e('div', { className: 'preview-panel' },
      e('div', { className: 'preview-header' },
        e('div', { className: 'preview-title-block' },
          e('h2', null, 'Live Preview'),
          e('span', { className: 'preview-hint' }, 'Real-time preview of your receipt')
        ),
        e('div', { className: 'preview-controls' },
          e('button', {
            className: `preview-type-btn ${previewType === 'delivery' ? 'active' : ''}`,
            onClick: () => setPreviewType('delivery')
          }, '🚚 Delivery'),
          e('button', {
            className: `preview-type-btn ${previewType === 'takeaway' ? 'active' : ''}`,
            onClick: () => setPreviewType('takeaway')
          }, '🛍️ Takeaway'),
          config.printer.copies > 1 && e('button', {
            className: `preview-type-btn ${showCopyPreview ? 'active' : ''}`,
            onClick: () => setShowCopyPreview(!showCopyPreview)
          }, '📄 Copy Header')
        )
      ),
      e('div', { className: 'preview-container' },
        e(ReceiptPreview, { config, orderType: previewType, showCopy: showCopyPreview })
      )
    )
  );
}

// --- Template Settings Tab ---
function TemplateSettings({ config, handleChange }) {
  return e('div', { className: 'settings-section-content' },
    // Header Section
    e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '📋'),
        e('span', null, 'Header')
      ),
      e('div', { className: 'form-group' },
        e('label', null, 'Title'),
        e('input', {
          className: 'input',
          type: 'text',
          value: config.template.headerTitle || '',
          onChange: ev => handleChange('template', 'headerTitle', ev.target.value),
          placeholder: 'e.g. PIZZERIA ROTANTE'
        })
      ),
      e('div', { className: 'form-group' },
        e('label', null, 'Subtitle'),
        e('input', {
          className: 'input',
          type: 'text',
          value: config.template.headerSubtitle || '',
          onChange: ev => handleChange('template', 'headerSubtitle', ev.target.value),
          placeholder: 'Optional tagline'
        })
      )
    ),

    // Footer Section
    e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '👋'),
        e('span', null, 'Footer')
      ),
      e('div', { className: 'form-group' },
        e('label', null, 'Footer Text'),
        e('input', {
          className: 'input',
          type: 'text',
          value: config.template.footerText || '',
          onChange: ev => handleChange('template', 'footerText', ev.target.value),
          placeholder: 'e.g. Grazie per averci scelto!'
        })
      )
    ),

    // Visibility Toggles
    e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '👁️'),
        e('span', null, 'Display Options')
      ),
      e('div', { className: 'toggle-grid' },
        e(ToggleRow, {
          label: 'Customer Name',
          checked: config.template.showCustomerName,
          onChange: v => handleChange('template', 'showCustomerName', v)
        }),
        e(ToggleRow, {
          label: 'Customer Phone',
          checked: config.template.showCustomerPhone,
          onChange: v => handleChange('template', 'showCustomerPhone', v)
        }),
        e(ToggleRow, {
          label: 'Delivery Address',
          checked: config.template.showDeliveryAddress,
          onChange: v => handleChange('template', 'showDeliveryAddress', v)
        }),
        e(ToggleRow, {
          label: 'Order Time',
          checked: config.template.showOrderTime,
          onChange: v => handleChange('template', 'showOrderTime', v)
        }),
        e(ToggleRow, {
          label: 'Prices',
          checked: config.template.showPrices,
          onChange: v => handleChange('template', 'showPrices', v)
        }),
        e(ToggleRow, {
          label: 'Notes',
          checked: config.template.showNotes,
          onChange: v => handleChange('template', 'showNotes', v)
        }),
        e(ToggleRow, {
          label: 'Category Dividers',
          checked: config.template.showCategoryDividers !== false,
          onChange: v => handleChange('template', 'showCategoryDividers', v)
        })
      )
    )
  );
}

// --- Text Sizing Settings Tab ---
function TextSizingSettings({ config, handleChange }) {
  const textSizing = config.textSizing || {};

  const sizingGroups = [
    {
      title: 'Header Section',
      icon: '📋',
      items: [
        { key: 'headerTitle', label: 'Header Title', description: 'Business name at the top' },
        { key: 'headerSubtitle', label: 'Header Subtitle', description: 'Tagline below title' },
        { key: 'orderType', label: 'Order Type', description: 'CONSEGNA / ASPORTO label' },
        { key: 'orderNumber', label: 'Order Number', description: 'ORDINE #XX' },
        { key: 'orderTime', label: 'Order Time', description: 'Delivery/pickup time' },
      ]
    },
    {
      title: 'Customer Section',
      icon: '👤',
      items: [
        { key: 'sectionLabels', label: 'Section Labels', description: 'CLIENTE, CONSEGNA, ORDINE headers' },
        { key: 'customerInfo', label: 'Customer Info', description: 'Name and phone number' },
        { key: 'deliveryAddress', label: 'Delivery Address', description: 'Address details' },
      ]
    },
    {
      title: 'Products Section',
      icon: '🍕',
      items: [
        { key: 'categoryHeaders', label: 'Category Headers', description: 'PIZZA, BEVANDE, etc.' },
        { key: 'productNames', label: 'Product Names', description: 'Item names in the order' },
        { key: 'productMods', label: 'Modifications', description: 'Added/removed ingredients' },
        { key: 'prices', label: 'Prices', description: 'Individual item prices' },
      ]
    },
    {
      title: 'Footer Section',
      icon: '📝',
      items: [
        { key: 'total', label: 'Total', description: 'Order total amount' },
        { key: 'notes', label: 'Notes', description: 'Order notes and item notes' },
        { key: 'footer', label: 'Footer Text', description: 'Thank you message' },
        { key: 'copyHeader', label: 'Copy Header', description: 'ORDINE COPIA N header' },
      ]
    }
  ];

  return e('div', { className: 'settings-section-content' },
    e('div', { className: 'settings-hint-banner' },
      e('span', { className: 'hint-icon' }, '💡'),
      e('span', null, 'Adjust text size for each section. Values: 0.8 (smaller) - 1.0 (normal) - 1.5 (larger). Changes reflect instantly in the preview.')
    ),

    sizingGroups.map(group =>
      e('div', { key: group.title, className: 'settings-group' },
        e('div', { className: 'settings-group-header' },
          e('span', { className: 'group-icon' }, group.icon),
          e('span', null, group.title)
        ),
        group.items.map(item =>
          e(SizingSlider, {
            key: item.key,
            label: item.label,
            description: item.description,
            value: textSizing[item.key] ?? 1.0,
            onChange: v => handleChange('textSizing', item.key, v),
            min: 0.8,
            max: 1.5,
            step: 0.01
          })
        )
      )
    )
  );
}

// --- Spacing Settings Tab ---
function SpacingSettings({ config, handleChange }) {
  const spacing = config.spacing || {};

  return e('div', { className: 'settings-section-content' },
    e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '📏'),
        e('span', null, 'Section Spacing')
      ),
      e('p', { className: 'settings-hint' },
        'Control the spacing between different sections of the receipt. Values represent empty lines.'
      ),

      e(SpacingSlider, {
        label: 'After Header',
        description: 'Space after title and order type',
        value: spacing.headerMarginBottom ?? 1,
        onChange: v => handleChange('spacing', 'headerMarginBottom', v),
        min: 0,
        max: 4
      }),

      e(SpacingSlider, {
        label: 'After Customer Info',
        description: 'Space after customer name/phone',
        value: spacing.customerMarginBottom ?? 1,
        onChange: v => handleChange('spacing', 'customerMarginBottom', v),
        min: 0,
        max: 4
      }),

      e(SpacingSlider, {
        label: 'After Delivery Address',
        description: 'Space after delivery details (delivery orders)',
        value: spacing.deliveryMarginBottom ?? 1,
        onChange: v => handleChange('spacing', 'deliveryMarginBottom', v),
        min: 0,
        max: 4
      }),

      e(SpacingSlider, {
        label: 'Before Items',
        description: 'Space before product list',
        value: spacing.itemsMarginTop ?? 1,
        onChange: v => handleChange('spacing', 'itemsMarginTop', v),
        min: 0,
        max: 4
      }),

      e(SpacingSlider, {
        label: 'Between Categories',
        description: 'Space between product categories',
        value: spacing.categoryGap ?? 1,
        onChange: v => handleChange('spacing', 'categoryGap', v),
        min: 0,
        max: 3
      }),

      e(SpacingSlider, {
        label: 'After Items',
        description: 'Space after product list (before total)',
        value: spacing.itemsMarginBottom ?? 1,
        onChange: v => handleChange('spacing', 'itemsMarginBottom', v),
        min: 0,
        max: 4
      }),

      e(SpacingSlider, {
        label: 'Before Footer',
        description: 'Space before footer message',
        value: spacing.footerMarginTop ?? 2,
        onChange: v => handleChange('spacing', 'footerMarginTop', v),
        min: 0,
        max: 4
      })
    )
  );
}

// --- QR Code Settings Tab ---
function QRCodeSettings({ config, handleChange }) {
  const qrCode = config.qrCode || {};

  return e('div', { className: 'settings-section-content' },
    e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '📱'),
        e('span', null, 'QR Code Settings')
      ),
      e('p', { className: 'settings-hint' },
        'Configure the QR code that drivers can scan to assign orders to themselves.'
      ),

      e('div', { className: 'toggle-grid single-column' },
        e(ToggleRow, {
          label: 'Enable QR Code',
          checked: qrCode.enabled !== false,
          onChange: v => handleChange('qrCode', 'enabled', v)
        }),
        e(ToggleRow, {
          label: 'Show Only on Delivery Orders',
          checked: qrCode.showOnlyDelivery !== false,
          onChange: v => handleChange('qrCode', 'showOnlyDelivery', v)
        })
      )
    ),

    qrCode.enabled !== false && e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '⚙️'),
        e('span', null, 'QR Code Appearance')
      ),

      e('div', { className: 'form-group' },
        e('label', null, 'QR Code Label'),
        e('input', {
          className: 'input',
          type: 'text',
          value: qrCode.label || '',
          onChange: ev => handleChange('qrCode', 'label', ev.target.value),
          placeholder: 'e.g. Scansiona per assegnare'
        }),
        e('span', { className: 'form-hint' }, 'Optional text shown above the QR code')
      ),

      e(SpacingSlider, {
        label: 'QR Code Size',
        description: 'Size of the QR code (1 = small, 10 = large)',
        value: qrCode.size ?? 6,
        onChange: v => handleChange('qrCode', 'size', v),
        min: 1,
        max: 10
      }),

      e(SpacingSlider, {
        label: 'Margin Above',
        description: 'Blank lines before QR code',
        value: qrCode.marginTop ?? 1,
        onChange: v => handleChange('qrCode', 'marginTop', v),
        min: 0,
        max: 4
      }),

      e(SpacingSlider, {
        label: 'Margin Below',
        description: 'Blank lines after QR code',
        value: qrCode.marginBottom ?? 1,
        onChange: v => handleChange('qrCode', 'marginBottom', v),
        min: 0,
        max: 4
      })
    )
  );
}

// --- Printer Settings Tab ---
function PrinterSettings({ config, handleChange, handleTestPrint }) {
  return e('div', { className: 'settings-section-content' },
    e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '⚙️'),
        e('span', null, 'Printer Configuration')
      ),

      e('div', { className: 'form-group' },
        e('label', null, 'Paper Width'),
        e('div', { className: 'input-with-suffix' },
          e('input', {
            className: 'input',
            type: 'number',
            value: config.printer.width || 48,
            onChange: ev => handleChange('printer', 'width', parseInt(ev.target.value) || 48),
            min: 32,
            max: 80
          }),
          e('span', { className: 'input-suffix' }, 'chars')
        ),
        e('span', { className: 'form-hint' }, 'Standard thermal: 48 (58mm) or 80 (80mm) characters')
      ),

      e('div', { className: 'form-group' },
        e('label', null, 'Default Copies'),
        e('input', {
          className: 'input',
          type: 'number',
          value: config.printer.copies || 1,
          onChange: ev => handleChange('printer', 'copies', parseInt(ev.target.value) || 1),
          min: 1,
          max: 5
        }),
        e('span', { className: 'form-hint' }, 'Each copy after the first will have "ORDINE COPIA N" header')
      ),

      e('div', { className: 'form-group' },
        e('label', null, 'Character Encoding'),
        e('select', {
          className: 'input',
          value: config.printer.encoding || 'CP858',
          onChange: ev => handleChange('printer', 'encoding', ev.target.value)
        },
          e('option', { value: 'CP858' }, 'CP858 (Western European)'),
          e('option', { value: 'CP437' }, 'CP437 (US)'),
          e('option', { value: 'CP850' }, 'CP850 (Western European)'),
          e('option', { value: 'CP1252' }, 'CP1252 (Windows)')
        ),
        e('span', { className: 'form-hint' }, 'Character encoding for the printer')
      )
    ),

    e('div', { className: 'settings-group' },
      e('div', { className: 'settings-group-header' },
        e('span', { className: 'group-icon' }, '🧪'),
        e('span', null, 'Test Print')
      ),
      e('p', { className: 'settings-hint' },
        'Send a test receipt to verify your printer settings. Make sure to save your settings first!'
      ),
      e('button', {
        className: 'button button-ghost test-print-btn',
        onClick: handleTestPrint
      },
        e('span', null, '🖨️'),
        e('span', null, 'Send Test Print')
      )
    )
  );
}

// --- Toggle Row Component ---
function ToggleRow({ label, checked, onChange }) {
  return e('div', { className: 'toggle-row' },
    e('span', { className: 'toggle-label' }, label),
    e('button', {
      className: `toggle-switch ${checked ? 'active' : ''}`,
      onClick: () => onChange(!checked),
      type: 'button'
    },
      e('span', { className: 'toggle-knob' })
    )
  );
}

// --- Spacing Slider Component ---
function SpacingSlider({ label, description, value, onChange, min, max }) {
  return e('div', { className: 'spacing-control' },
    e('div', { className: 'spacing-header' },
      e('span', { className: 'spacing-label' }, label),
      e('span', { className: 'spacing-value' }, `${value} line${value !== 1 ? 's' : ''}`)
    ),
    e('span', { className: 'spacing-description' }, description),
    e('div', { className: 'spacing-slider-container' },
      e('input', {
        type: 'range',
        className: 'spacing-slider',
        min,
        max,
        value,
        onChange: ev => onChange(parseInt(ev.target.value))
      }),
      e('div', { className: 'spacing-marks' },
        Array.from({ length: max - min + 1 }, (_, i) =>
          e('span', { key: i, className: 'spacing-mark' }, min + i)
        )
      )
    )
  );
}

// --- Sizing Slider Component (for text sizing) ---
function SizingSlider({ label, description, value, onChange, min, max, step }) {
  const displayValue = (value || 1).toFixed(2);
  const sizeLabel = value < 1 ? 'Smaller' : value > 1.2 ? 'Larger' : 'Normal';

  return e('div', { className: 'sizing-control' },
    e('div', { className: 'sizing-header' },
      e('div', { className: 'sizing-label-group' },
        e('span', { className: 'sizing-label' }, label),
        e('span', { className: 'sizing-description' }, description)
      ),
      e('span', { className: `sizing-value ${value < 1 ? 'small' : value > 1.2 ? 'large' : ''}` },
        `${displayValue}x (${sizeLabel})`
      )
    ),
    e('div', { className: 'sizing-slider-container' },
      e('input', {
        type: 'range',
        className: 'sizing-slider',
        min,
        max,
        step,
        value: value || 1,
        onChange: ev => onChange(parseFloat(ev.target.value))
      })
    )
  );
}

// --- Receipt Preview Component ---
function ReceiptPreview({ config, orderType, showCopy }) {
  const template = config.template || {};
  const spacing = config.spacing || {};
  const textSizing = config.textSizing || {};
  const printerConfig = config.printer || {};
  const qrCode = config.qrCode || {};

  const order = { ...SAMPLE_ORDER, tipo_ordine: orderType };
  const items = SAMPLE_ITEMS;

  const tipoLabel = orderType === 'delivery' ? 'CONSEGNA' : 'ASPORTO';
  const consegnaTime = new Date(order.slot_prenotato_start).toLocaleTimeString('it-IT', {
    hour: '2-digit',
    minute: '2-digit'
  });

  // Group items by size
  const itemsBySize = useMemo(() => {
    const map = new Map();
    for (const item of items) {
      const key = item._sizeName || 'Altro';
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(item);
    }
    return map;
  }, [items]);

  const blankLines = count => Array.from({ length: count }, (_, i) =>
    e('div', { key: `blank-${i}`, className: 'receipt-line blank' }, '\u00A0')
  );

  // Convert text sizing to CSS class
  const getSizeClass = (factor) => {
    if (factor >= 1.5) return 'xlarge';
    if (factor >= 1.2) return 'large';
    if (factor <= 0.8) return 'small';
    return '';
  };

  // Get CSS style for sizing
  const getSizeStyle = (factor) => {
    const baseFontSize = 12;
    return { fontSize: `${Math.round(baseFontSize * (factor || 1))}px` };
  };

  // Whether to show QR code
  const showQRCode = qrCode.enabled !== false &&
    (!qrCode.showOnlyDelivery || orderType === 'delivery');

  return e('div', { className: 'receipt-paper' },
    e('div', { className: 'receipt-content' },

      // === COPY HEADER (shown when toggle is on) ===
      showCopy && printerConfig.copies > 1 && e('div', { className: 'receipt-section copy-header-section' },
        e('div', {
          className: `receipt-line center bold ${getSizeClass(textSizing.copyHeader)} copy-header`,
          style: getSizeStyle(textSizing.copyHeader)
        }, `*** ORDINE COPIA 2 ***`),
        e('div', { className: 'receipt-line blank' })
      ),

      // === HEADER SECTION ===
      e('div', { className: 'receipt-section header-section' },
        template.headerTitle && e('div', {
          className: `receipt-line center bold ${getSizeClass(textSizing.headerTitle)}`,
          style: getSizeStyle(textSizing.headerTitle)
        }, template.headerTitle),
        template.headerSubtitle && e('div', {
          className: `receipt-line center ${getSizeClass(textSizing.headerSubtitle)}`,
          style: getSizeStyle(textSizing.headerSubtitle)
        }, template.headerSubtitle),
        e('div', {
          className: `receipt-line center bold ${getSizeClass(textSizing.orderType)}`,
          style: getSizeStyle(textSizing.orderType)
        }, tipoLabel),
        e('div', {
          className: `receipt-line center bold ${getSizeClass(textSizing.orderNumber)}`,
          style: getSizeStyle(textSizing.orderNumber)
        }, `ORDINE #${order.numero_ordine}`),
        template.showOrderTime && e('div', {
          className: `receipt-line center ${getSizeClass(textSizing.orderTime)}`,
          style: getSizeStyle(textSizing.orderTime)
        }, `CONSEGNA: ${consegnaTime}`)
      ),

      blankLines(spacing.headerMarginBottom || 1),

      // === CUSTOMER SECTION ===
      (template.showCustomerName || template.showCustomerPhone) && e('div', { className: 'receipt-section customer-section' },
        e('div', {
          className: `receipt-line bold ${getSizeClass(textSizing.sectionLabels)}`,
          style: getSizeStyle(textSizing.sectionLabels)
        }, 'CLIENTE'),
        template.showCustomerName && order.nome_cliente && e('div', {
          className: `receipt-line ${getSizeClass(textSizing.customerInfo)}`,
          style: getSizeStyle(textSizing.customerInfo)
        }, order.nome_cliente),
        template.showCustomerPhone && order.telefono_cliente && e('div', {
          className: `receipt-line ${getSizeClass(textSizing.customerInfo)}`,
          style: getSizeStyle(textSizing.customerInfo)
        }, `TEL: ${order.telefono_cliente}`)
      ),

      blankLines(spacing.customerMarginBottom || 1),

      // === DELIVERY ADDRESS ===
      orderType === 'delivery' && template.showDeliveryAddress && e('div', { className: 'receipt-section delivery-section' },
        e('div', {
          className: `receipt-line bold ${getSizeClass(textSizing.sectionLabels)}`,
          style: getSizeStyle(textSizing.sectionLabels)
        }, 'CONSEGNA'),
        order.indirizzo_consegna && e('div', {
          className: `receipt-line ${getSizeClass(textSizing.deliveryAddress)}`,
          style: getSizeStyle(textSizing.deliveryAddress)
        }, order.indirizzo_consegna),
        e('div', {
          className: `receipt-line ${getSizeClass(textSizing.deliveryAddress)}`,
          style: getSizeStyle(textSizing.deliveryAddress)
        }, `${order.cap_consegna} ${order.citta_consegna}`),
        e('div', {
          className: `receipt-line ${getSizeClass(textSizing.deliveryAddress)}`,
          style: getSizeStyle(textSizing.deliveryAddress)
        }, `ORARIO: ${consegnaTime}`),
        order.zone && e('div', {
          className: `receipt-line ${getSizeClass(textSizing.deliveryAddress)}`,
          style: getSizeStyle(textSizing.deliveryAddress)
        }, `ZONA: ${order.zone}`),
        blankLines(spacing.deliveryMarginBottom || 1)
      ),

      // === ORDER ITEMS SECTION ===
      e('div', { className: 'receipt-section items-section' },
        blankLines(spacing.itemsMarginTop || 1),
        e('div', {
          className: `receipt-line bold ${getSizeClass(textSizing.sectionLabels)}`,
          style: getSizeStyle(textSizing.sectionLabels)
        }, 'ORDINE'),
        Array.from(itemsBySize.entries()).map(([sizeHeader, sizeItems], groupIdx) =>
          e('div', { key: sizeHeader, className: 'receipt-size-group' },
            groupIdx > 0 && template.showCategoryDividers !== false && blankLines(spacing.categoryGap || 1),
            template.showCategoryDividers !== false && e('div', { className: 'receipt-line separator' }, '-'.repeat(30)),
            e('div', {
              className: `receipt-line bold ${getSizeClass(textSizing.categoryHeaders)}`,
              style: getSizeStyle(textSizing.categoryHeaders)
            }, sizeHeader.toUpperCase()),
            e('div', { className: 'receipt-line blank' }),
            sizeItems.map((item, idx) => {
              const lineTotal = (item.prezzo_unitario * item.quantita).toFixed(2);
              return e('div', { key: idx, className: 'receipt-item' },
                e('div', {
                  className: `receipt-line ${getSizeClass(textSizing.productNames)}`,
                  style: getSizeStyle(template.showPrices ? textSizing.prices : textSizing.productNames)
                },
                  template.showPrices
                    ? `${item.quantita}x ${item.nome_prodotto} - EUR ${lineTotal}`
                    : `${item.quantita}x ${item.nome_prodotto}`
                ),
                item._mods && e('div', {
                  className: `receipt-line indent muted ${getSizeClass(textSizing.productMods)}`,
                  style: getSizeStyle(textSizing.productMods)
                }, item._mods)
              );
            })
          )
        ),
        template.showCategoryDividers !== false && e('div', { className: 'receipt-line separator' }, '-'.repeat(30)),
        blankLines(spacing.itemsMarginBottom || 1)
      ),

      // === TOTAL ===
      template.showPrices && e('div', { className: 'receipt-section total-section' },
        e('div', {
          className: `receipt-line right bold ${getSizeClass(textSizing.total)}`,
          style: getSizeStyle(textSizing.total)
        }, `TOTALE EUR ${order.totale.toFixed(2)}`)
      ),

      // === ORDER NOTES ===
      template.showNotes && order.note && e('div', { className: 'receipt-section notes-section' },
        e('div', { className: 'receipt-line blank' }),
        e('div', {
          className: `receipt-line ${getSizeClass(textSizing.notes)}`,
          style: getSizeStyle(textSizing.notes)
        }, 'NOTE ORDINE:'),
        e('div', {
          className: `receipt-line ${getSizeClass(textSizing.notes)}`,
          style: getSizeStyle(textSizing.notes)
        }, order.note)
      ),

      // === FOOTER ===
      template.footerText && e('div', { className: 'receipt-section footer-section' },
        blankLines(spacing.footerMarginTop || 2),
        e('div', {
          className: `receipt-line center ${getSizeClass(textSizing.footer)}`,
          style: getSizeStyle(textSizing.footer)
        }, template.footerText)
      ),

      // === QR CODE PREVIEW ===
      showQRCode && e('div', { className: 'receipt-section qr-section' },
        blankLines(qrCode.marginTop || 1),
        e('div', { className: 'receipt-line center' },
          qrCode.label && e('div', { className: 'qr-label' }, qrCode.label),
          e('div', {
            className: 'qr-preview',
            style: {
              width: `${40 + (qrCode.size || 6) * 8}px`,
              height: `${40 + (qrCode.size || 6) * 8}px`
            }
          },
            e('div', { className: 'qr-pattern' },
              // Simple QR code visual representation
              Array.from({ length: 7 }, (_, row) =>
                e('div', { key: row, className: 'qr-row' },
                  Array.from({ length: 7 }, (_, col) =>
                    e('div', {
                      key: col,
                      className: `qr-cell ${getQRCellClass(row, col)}`
                    })
                  )
                )
              )
            )
          )
        ),
        blankLines(qrCode.marginBottom || 1)
      ),

      // Tear line
      e('div', { className: 'receipt-tear' },
        e('div', { className: 'tear-line' })
      )
    )
  );
}

// Helper function to generate a simple QR pattern
function getQRCellClass(row, col) {
  // Corner patterns (position detection patterns)
  const isCorner = (row < 2 && col < 2) ||
    (row < 2 && col > 4) ||
    (row > 4 && col < 2);
  // Random-ish data pattern
  const isData = (row + col) % 2 === 0 || (row * col) % 3 === 0;

  if (isCorner) return 'filled';
  if (isData && row > 1 && col > 1) return 'filled';
  return '';
}
