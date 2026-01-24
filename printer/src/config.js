const fs = require('fs').promises;
const path = require('path');
const logger = require('./logger');

const CONFIG_PATH = path.join(__dirname, '../print_settings.json');

const DEFAULT_CONFIG = {
  printer: {
    encoding: 'CP858',
    width: 48, // Characters per line (standard for 80mm)
    copies: 1
  },
  // Section-specific text sizing (1 = normal, 2 = double, etc.)
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
    size: 6, // 1-10 scale
    label: '',
    marginTop: 1,
    marginBottom: 1
  }
};

let currentConfig = JSON.parse(JSON.stringify(DEFAULT_CONFIG));

function deepMerge(target, source) {
  const result = { ...target };
  for (const key of Object.keys(source)) {
    if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
      result[key] = deepMerge(target[key] || {}, source[key]);
    } else if (source[key] !== undefined) {
      result[key] = source[key];
    }
  }
  return result;
}

async function loadConfig() {
  try {
    const data = await fs.readFile(CONFIG_PATH, 'utf8');
    const parsed = JSON.parse(data);
    // Deep merge defaults with loaded config to ensure all keys exist
    currentConfig = deepMerge(DEFAULT_CONFIG, parsed);
    logger.info('Config loaded successfully');
  } catch (error) {
    if (error.code === 'ENOENT') {
      logger.warn('Config file not found, creating default');
      await saveConfig(DEFAULT_CONFIG);
    } else {
      logger.error(`Error loading config: ${error.message}`);
    }
  }
  return currentConfig;
}

async function saveConfig(newConfig) {
  try {
    // Deep merge with current config
    const configToSave = deepMerge(currentConfig, newConfig);

    await fs.writeFile(CONFIG_PATH, JSON.stringify(configToSave, null, 2), 'utf8');
    currentConfig = configToSave;
    logger.info('Config saved successfully');
    return currentConfig;
  } catch (error) {
    logger.error(`Error saving config: ${error.message}`);
    throw error;
  }
}


function getConfig() {
  return currentConfig;
}

module.exports = {
  loadConfig,
  saveConfig,
  getConfig
};
