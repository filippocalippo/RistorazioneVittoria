/// Costanti dell'applicazione
class AppConstants {
  // ========== App Info ==========
  static const String appName = 'Rotante';
  static const String appVersion = '1.0.0';

  // ========== Organization ==========
  // NOTE: Pizzeria name and branding are now loaded dynamically from
  // the organization's settings via organization_provider.dart
  // DO NOT add hardcoded pizzeria info here for multi-tenant support

  // ========== Database Tables ==========
  static const String tablePizzerie = 'pizzerie';
  static const String tableProfiles = 'profiles';
  static const String tableMenuItems = 'menu_items';
  static const String tableCategorieMenu = 'categorie_menu';
  static const String tableOrdini = 'ordini';
  static const String tableOrdiniItems = 'ordini_items';
  static const String tableNotifiche = 'notifiche';

  // ========== Storage Buckets ==========
  static const String bucketMenuImages = 'menu-images';
  static const String bucketAvatars = 'avatars';

  // ========== Pagination ==========
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ========== Timing ==========
  static const int debounceMilliseconds = 500;
  static const int realtimeRetryDelay = 3000;
  static const int notificationDuration = 3; // secondi

  // ========== Validation ==========
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxNoteLength = 200;

  // ========== Order ==========
  static const double defaultDeliveryCost = 3.0;
  static const double minOrderAmount = 10.0;
  static const int defaultPreparationTime = 30; // minuti
  static const double maxDeliveryDistance = 10.0; // km
}

/// Nomi delle routes dell'applicazione
class RouteNames {
  // ========== Auth ==========
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String connect = '/connect';
  static const String joinOrg = '/join';
  static const String switchOrg = '/switch-org';

  // ========== Customer ==========
  static const String menu = '/menu';
  static const String currentOrder = '/orders/current';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderTracking = '/order-tracking';
  static const String orderHistory = '/order-history';
  static const String customerProfile = '/profile';

  // ========== Manager ==========
  static const String dashboard = '/dashboard';
  static const String managerMenu = '/manager/menu';
  static const String managerOrders = '/manager/orders';
  static const String assignDelivery = '/manager/assign-delivery';
  static const String cashierOrder = '/manager/cashier-order';
  static const String menuManagement = '/menu-management';
  static const String menuItemForm = '/menu-item-form';
  static const String ordersOverview = '/orders-overview';
  static const String staffManagement = '/staff-management';
  static const String analytics = '/analytics';
  static const String settings = '/settings';
  static const String sizeVariants = '/manager/size-variants';
  static const String supplements = '/manager/supplements';
  static const String bulkOperations = '/manager/bulk-operations';
  static const String productAnalytics = '/manager/product-analytics';
  static const String deliveryRevenue = '/manager/delivery-revenue';
  static const String inventory = '/manager/inventory';

  // ========== Kitchen ==========
  static const String kitchenOrders = '/kitchen/orders';
  static const String kitchenOrderDetails = '/kitchen/order-details';
  static const String kitchenCompleted = '/kitchen/completed';

  // ========== Delivery ==========
  static const String deliveryReady = '/delivery/ready';
  static const String deliveryInProgress = '/delivery/in-progress';
  static const String deliveryDetails = '/delivery/details';
  static const String deliveryHistory = '/delivery/history';
}

/// Messaggi di errore comuni
class ErrorMessages {
  static const String networkError =
      'Errore di connessione. Verifica la tua connessione internet.';
  static const String serverError = 'Errore del server. Riprova più tardi.';
  static const String authError =
      'Errore di autenticazione. Effettua nuovamente il login.';
  static const String notFoundError = 'Risorsa non trovata.';
  static const String permissionError =
      'Non hai i permessi per questa operazione.';
  static const String validationError = 'Verifica i dati inseriti.';
  static const String unknownError = 'Si è verificato un errore imprevisto.';
}

/// Messaggi di successo comuni
class SuccessMessages {
  static const String loginSuccess = 'Login effettuato con successo';
  static const String logoutSuccess = 'Logout effettuato con successo';
  static const String saveSuccess = 'Salvato con successo';
  static const String deleteSuccess = 'Eliminato con successo';
  static const String updateSuccess = 'Aggiornato con successo';
  static const String orderCreated = 'Ordine creato con successo';
  static const String orderUpdated = 'Ordine aggiornato con successo';
}
