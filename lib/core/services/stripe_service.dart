import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import '../utils/logger.dart';

/// Cart item for server-side price validation
class StripeCartItem {
  final String menuItemId;
  final int quantity;
  final String? sizeId;
  final List<StripeExtraIngredient>? extraIngredients;

  const StripeCartItem({
    required this.menuItemId,
    required this.quantity,
    this.sizeId,
    this.extraIngredients,
  });

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'quantity': quantity,
    if (sizeId != null) 'sizeId': sizeId,
    if (extraIngredients != null && extraIngredients!.isNotEmpty)
      'extraIngredients': extraIngredients!.map((e) => e.toJson()).toList(),
  };
}

class StripeExtraIngredient {
  final String ingredientId;
  final int quantity;

  const StripeExtraIngredient({
    required this.ingredientId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'quantity': quantity,
  };
}

/// Result of a payment intent creation
class PaymentIntentResult {
  final String clientSecret;
  final String paymentIntentId;
  final int amount;
  final String currency;
  final double calculatedTotal;
  final double calculatedSubtotal;
  final double calculatedDeliveryFee;

  const PaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
    required this.calculatedTotal,
    required this.calculatedSubtotal,
    required this.calculatedDeliveryFee,
  });

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResult(
      clientSecret: json['clientSecret'] as String,
      paymentIntentId: json['paymentIntentId'] as String,
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      calculatedTotal: (json['calculatedTotal'] as num).toDouble(),
      calculatedSubtotal:
          (json['calculatedSubtotal'] as num?)?.toDouble() ?? 0.0,
      calculatedDeliveryFee:
          (json['calculatedDeliveryFee'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Result of the payment flow
class PaymentResult {
  final bool success;
  final String? paymentIntentId;
  final String? errorMessage;
  final double? serverCalculatedTotal;
  final double? serverCalculatedSubtotal;
  final double? serverCalculatedDeliveryFee;

  const PaymentResult({
    required this.success,
    this.paymentIntentId,
    this.errorMessage,
    this.serverCalculatedTotal,
    this.serverCalculatedSubtotal,
    this.serverCalculatedDeliveryFee,
  });

  factory PaymentResult.success(
    String paymentIntentId,
    double calculatedTotal,
    double calculatedSubtotal,
    double calculatedDeliveryFee,
  ) {
    return PaymentResult(
      success: true,
      paymentIntentId: paymentIntentId,
      serverCalculatedTotal: calculatedTotal,
      serverCalculatedSubtotal: calculatedSubtotal,
      serverCalculatedDeliveryFee: calculatedDeliveryFee,
    );
  }

  factory PaymentResult.failure(String message) {
    return PaymentResult(success: false, errorMessage: message);
  }

  factory PaymentResult.cancelled() {
    return const PaymentResult(
      success: false,
      errorMessage: 'Pagamento annullato',
    );
  }
}

/// Service for handling Stripe payments
class StripeService {
  static bool _isInitialized = false;

  /// Initialize Stripe SDK with publishable key
  /// Should be called during app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final publishableKey = EnvConfig.stripePublishableKey;
    if (publishableKey.isEmpty) {
      Logger.warning(
        'STRIPE_PUBLISHABLE_KEY not configured. Card payments will not work.',
        tag: 'StripeService',
      );
      return;
    }

    try {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      _isInitialized = true;
      Logger.info('Stripe SDK initialized successfully', tag: 'StripeService');
    } catch (e) {
      Logger.error('Failed to initialize Stripe: $e', tag: 'StripeService');
    }
  }

  /// Check if Stripe is properly initialized
  static bool get isInitialized => _isInitialized;

  /// Check if card payments are available
  static bool get isAvailable {
    return _isInitialized && EnvConfig.stripePublishableKey.isNotEmpty;
  }

  /// Create a PaymentIntent via Supabase Edge Function
  /// SECURITY: The amount is calculated server-side from cart items in the database.
  /// This prevents price manipulation attacks.
  static Future<PaymentIntentResult> createPaymentIntent({
    required List<StripeCartItem> items,
    required String orderType,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String currency = 'eur',
    String? customerEmail,
    Map<String, String>? metadata,
  }) async {
    final supabase = Supabase.instance.client;

    final response = await supabase.functions.invoke(
      'create-payment-intent',
      body: {
        'items': items.map((i) => i.toJson()).toList(),
        'orderType': orderType,
        if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
        if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
        'currency': currency,
        if (customerEmail != null) 'customerEmail': customerEmail,
        if (metadata != null) 'metadata': metadata,
      },
    );

    if (response.status != 200) {
      final errorData = response.data;
      final errorMessage =
          errorData?['error'] ?? 'Failed to create payment intent';
      throw Exception(errorMessage);
    }

    return PaymentIntentResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Initialize and present the Payment Sheet
  /// Returns a PaymentResult indicating success, failure, or cancellation
  /// SECURITY: Cart items are sent to server for price calculation - amount is never trusted from client
  static Future<PaymentResult> processPayment({
    required List<StripeCartItem> items,
    required String orderType,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String currency = 'eur',
    String? customerEmail,
    String? merchantDisplayName,
    Map<String, String>? metadata,
  }) async {
    if (!isAvailable) {
      return PaymentResult.failure(
        'Stripe non è configurato. Contatta il supporto.',
      );
    }

    try {
      Logger.info(
        'Creating PaymentIntent for ${items.length} items',
        tag: 'StripeService',
      );

      // 1. Create PaymentIntent on the server (amount calculated server-side)
      final paymentIntent = await createPaymentIntent(
        items: items,
        orderType: orderType,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        currency: currency,
        customerEmail: customerEmail,
        metadata: metadata,
      );

      Logger.info(
        'PaymentIntent created: ${paymentIntent.paymentIntentId} for €${paymentIntent.calculatedTotal}',
        tag: 'StripeService',
      );

      // 2. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent.clientSecret,
          merchantDisplayName: merchantDisplayName ?? 'Pizzeria Rotante',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFD32F2F), // Red accent color
            ),
            shapes: PaymentSheetShape(borderRadius: 16),
          ),
          billingDetails: BillingDetails(email: customerEmail),
        ),
      );

      Logger.info('Payment Sheet initialized', tag: 'StripeService');

      // 3. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      Logger.info(
        'Payment completed successfully: ${paymentIntent.paymentIntentId}',
        tag: 'StripeService',
      );

      return PaymentResult.success(
        paymentIntent.paymentIntentId,
        paymentIntent.calculatedTotal,
        paymentIntent.calculatedSubtotal,
        paymentIntent.calculatedDeliveryFee,
      );
    } on StripeException catch (e) {
      // Handle specific Stripe errors
      final code = e.error.code;
      final message = e.error.localizedMessage ?? e.error.message;

      Logger.warning('Stripe error: $code - $message', tag: 'StripeService');

      if (code == FailureCode.Canceled) {
        return PaymentResult.cancelled();
      }

      // User-friendly error messages in Italian
      String userMessage;
      switch (code) {
        case FailureCode.Failed:
          userMessage = 'Pagamento non riuscito. Riprova.';
          break;
        case FailureCode.Timeout:
          userMessage = 'Timeout. Controlla la connessione e riprova.';
          break;
        default:
          userMessage = message ?? 'Errore durante il pagamento. Riprova.';
      }

      return PaymentResult.failure(userMessage);
    } catch (e) {
      Logger.error('Payment error: $e', tag: 'StripeService');
      return PaymentResult.failure(
        'Errore durante il pagamento. Riprova più tardi.',
      );
    }
  }

  /// Initialize and present the Payment Sheet using an existing client secret
  /// Returns a boolean indicating success
  static Future<bool> presentPaymentSheet({
    required String clientSecret,
    String? merchantDisplayName,
    String? customerEmail,
  }) async {
    if (!isAvailable) {
      Logger.warning('Stripe not available', tag: 'StripeService');
      return false;
    }

    try {
      // 1. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName ?? 'Pizzeria Rotante',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFD32F2F), // Red accent color
            ),
            shapes: PaymentSheetShape(borderRadius: 16),
          ),
          billingDetails: BillingDetails(email: customerEmail),
        ),
      );

      // 2. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        Logger.info('Payment cancelled by user', tag: 'StripeService');
        return false;
      }
      Logger.error('Stripe error: ${e.error.message}', tag: 'StripeService');
      throw Exception(e.error.localizedMessage ?? 'Errore pagamento');
    } catch (e) {
      Logger.error('Payment presentation error: $e', tag: 'StripeService');
      throw Exception('Errore durante il pagamento');
    }
  }
}
