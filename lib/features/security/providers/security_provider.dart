import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/security_repository.dart';
import '../services/security_service.dart';

// Providers
final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository(Supabase.instance.client);
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(ref.watch(securityRepositoryProvider));
});

final securityStateProvider =
    StateNotifierProvider<SecurityStateNotifier, SecurityState>((ref) {
  return SecurityStateNotifier(ref.watch(securityServiceProvider));
});

// State
class SecurityState {
  final bool isLocked;
  final bool isSetupRequired;
  final bool isLoading;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final String? error;
  
  // Setup Flow State
  final int setupStep; // 0 = Password, 1 = Codes
  final List<String>? temporaryCodes;

  const SecurityState({
    this.isLocked = true,
    this.isSetupRequired = false,
    this.isLoading = true,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.error,
    this.setupStep = 0,
    this.temporaryCodes,
  });

  bool get isLockoutActive =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  SecurityState copyWith({
    bool? isLocked,
    bool? isSetupRequired,
    bool? isLoading,
    int? failedAttempts,
    DateTime? lockoutUntil,
    String? error,
    int? setupStep,
    List<String>? temporaryCodes,
  }) {
    return SecurityState(
      isLocked: isLocked ?? this.isLocked,
      isSetupRequired: isSetupRequired ?? this.isSetupRequired,
      isLoading: isLoading ?? this.isLoading,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: lockoutUntil ?? this.lockoutUntil,
      error: error,
      setupStep: setupStep ?? this.setupStep,
      temporaryCodes: temporaryCodes ?? this.temporaryCodes,
    );
  }
}

// Notifier
class SecurityStateNotifier extends StateNotifier<SecurityState> {
  final SecurityService _service;
  Timer? _lockoutTimer;
  bool _isCompletingSetup = false;

  SecurityStateNotifier(this._service) : super(const SecurityState()) {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // Prevent auto-check from overriding state if we are in the middle of a setup flow
    if (_isCompletingSetup) return;

    try {
      final repo = Supabase.instance.client;
      // Simple check if user is manager, otherwise no security needed
      final user = repo.auth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false, isLocked: false);
        return;
      }

      // Check if table has entry
      final settings =
          await Supabase.instance.client
              .from('dashboard_security')
              .select('id')
              .maybeSingle();

      if (settings == null) {
        state = state.copyWith(
          isSetupRequired: true,
          isLocked: true,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isSetupRequired: false,
          isLocked: true,
          isLoading: false,
        );
      }
    } catch (e) {
      // Allow through if error (fail safe? or fail closed?)
      // Fail closed for security
      state = state.copyWith(
        error: 'Errore verifica sicurezza: $e',
        isLoading: false,
        isLocked: true,
      );
    }
  }

  Future<bool> unlock(String password) async {
    if (state.isLockoutActive) {
      final remaining = state.lockoutUntil!.difference(DateTime.now());
      state = state.copyWith(
        error: 'Riprova tra ${remaining.inSeconds} secondi',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final isValid = await _service.verifyPassword(password);

      if (isValid) {
        state = state.copyWith(
          isLocked: false,
          isLoading: false,
          failedAttempts: 0,
          error: null,
        );
        return true;
      } else {
        final attempts = state.failedAttempts + 1;
        DateTime? lockout;

        if (attempts >= 5) {
          lockout = DateTime.now().add(const Duration(minutes: 5));
          _startLockoutTimer(lockout);
        } else if (attempts >= 3) {
          lockout = DateTime.now().add(const Duration(seconds: 30));
          _startLockoutTimer(lockout);
        }

        state = state.copyWith(
          isLoading: false,
          failedAttempts: attempts,
          lockoutUntil: lockout,
          error: 'Password errata',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void _startLockoutTimer(DateTime until) {
    _lockoutTimer?.cancel();
    final duration = until.difference(DateTime.now());
    _lockoutTimer = Timer(duration, () {
      state = state.copyWith(lockoutUntil: null, failedAttempts: 0);
    });
  }

  Future<void> setup(String password) async {
    state = state.copyWith(isLoading: true, error: null);
    _isCompletingSetup = true; // Mark as in-progress setup
    try {
      final codes = await _service.setupSecurity(password);
      // Move to step 1 and store codes in state so UI persists
      state = state.copyWith(
        isLoading: false,
        error: null,
        setupStep: 1,
        temporaryCodes: codes,
      );
    } catch (e) {
      _isCompletingSetup = false;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void completeSetup() {
    _isCompletingSetup = false;
    state = state.copyWith(
      isSetupRequired: false,
      isLocked: false,
      setupStep: 0,
      temporaryCodes: null,
    );
  }

  void lock() {
    state = state.copyWith(
      isLocked: true,
      error: null,
      failedAttempts: 0, // Optional: reset attempts on manual lock? Maybe keep them for security.
      // Let's keep failedAttempts to prevent "lock/unlock" spamming to reset counters
    );
  }

  Future<bool> recover(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isValid = await _service.verifyRecoveryCode(code);
      if (isValid) {
        // Valid code -> Reset required (treat as setup required)
        state = state.copyWith(
          isSetupRequired: true,
          isLocked: true,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Codice non valido',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> downloadCodes(List<String> codes) async {
    await _service.downloadRecoveryCodes(codes);
  }
}
