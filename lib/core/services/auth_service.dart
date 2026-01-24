import 'dart:async';
import 'dart:io' show Platform, HttpServer, HttpRequest;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';
import '../config/firebase_config.dart';
import '../config/google_signin_config.dart';
import '../models/user_model.dart';
import '../utils/enums.dart';
import '../utils/constants.dart';
import '../exceptions/app_exceptions.dart';
import '../utils/logger.dart';

class AuthService {
  final supabase.SupabaseClient _client = SupabaseConfig.client;

  supabase.User? get currentUser => _client.auth.currentUser;
  Stream<supabase.AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
  bool get isAuthenticated => currentUser != null;


  Future<void> signOut() async {
    try {
      // SECURITY: Clear FCM token before signing out
      // This prevents notifications from being delivered to this device after logout
      final userId = currentUser?.id;
      if (userId != null) {
        try {
          await _client
              .from('profiles')
              .update({'fcm_token': null})
              .eq('id', userId);
          Logger.debug('AuthService: Cleared FCM token on logout', tag: 'AuthService');
        } catch (e) {
          // Don't fail logout if FCM token clear fails
          Logger.warning('AuthService: Failed to clear FCM token: $e', tag: 'AuthService');
        }
      }

      // Sign out from Supabase
      await _client.auth.signOut();
      
      // Also sign out from Google Sign-In to allow account selection on next login
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn(
            clientId: Platform.isIOS ? GoogleSignInConfig.iosClientId : null,
            serverClientId: GoogleSignInConfig.webClientId,
          );
          await googleSignIn.signOut();
          Logger.debug('AuthService: Signed out from GoogleSignIn', tag: 'AuthService');
        } catch (e) {
          // Don't fail logout if Google sign-out fails
          Logger.warning('AuthService: Failed to sign out from GoogleSignIn: $e', tag: 'AuthService');
        }
      }
    } catch (_) {
      throw AuthException('Errore durante il logout');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on supabase.AuthException catch (e) {
      throw AuthException('Errore reset password: ${e.message}');
    } catch (_) {
      throw AuthException('Errore imprevisto durante il reset password');
    }
  }

  /// Sign in with Google
  /// Uses native sign-in on Android/iOS, OAuth flow on Web/Desktop
  Future<UserModel> signInWithGoogle() async {
    try {
      Logger.debug('AuthService: Starting Google sign-in', tag: 'AuthService');

      // Check if we're on a platform that supports native Google Sign-In
      final bool useNativeSignIn =
          !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      if (useNativeSignIn) {
        // Use native Google Sign-In for Android and iOS
        return await _signInWithGoogleNative();
      } else {
        // Use OAuth flow for Web, Windows, macOS, Linux
        return await _signInWithGoogleOAuth();
      }
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      Logger.error(
        'AuthService: Google sign-in error: $e',
        tag: 'AuthService',
        error: e,
      );
      Logger.error('Stack trace: $stackTrace', tag: 'AuthService');
      throw AuthException(
        'Errore durante l\'accesso con Google: ${e.toString()}',
      );
    }
  }

  /// Native Google Sign-In for Android and iOS
  Future<UserModel> _signInWithGoogleNative() async {
    Logger.debug(
      'AuthService: Using native Google sign-in',
      tag: 'AuthService',
    );

    // Initialize GoogleSignIn with platform-specific configuration
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: Platform.isIOS ? GoogleSignInConfig.iosClientId : null,
      serverClientId: GoogleSignInConfig.webClientId,
    );

    // Sign out first to force account selection dialog
    try {
      await googleSignIn.signOut();
      Logger.debug(
        'AuthService: Cleared previous Google session',
        tag: 'AuthService',
      );
    } catch (e) {
      Logger.debug(
        'AuthService: No previous session to clear: $e',
        tag: 'AuthService',
      );
    }

    // Trigger Google Sign-In flow
    Logger.debug(
      'AuthService: Launching Google sign-in UI',
      tag: 'AuthService',
    );
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      Logger.warning(
        'AuthService: User cancelled Google sign-in',
        tag: 'AuthService',
      );
      throw AuthException('Accesso con Google annullato');
    }

    Logger.debug(
      'AuthService: Google user selected: ${googleUser.email}',
      tag: 'AuthService',
    );

    // Obtain Google authentication tokens
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final String? accessToken = googleAuth.accessToken;
    final String? idToken = googleAuth.idToken;

    if (accessToken == null) {
      Logger.error(
        'AuthService: No access token from Google',
        tag: 'AuthService',
      );
      throw AuthException('Token di accesso Google non disponibile');
    }
    if (idToken == null) {
      Logger.error('AuthService: No ID token from Google', tag: 'AuthService');
      throw AuthException('Token ID Google non disponibile');
    }

    Logger.debug(
      'AuthService: Google tokens obtained, signing in to Supabase',
      tag: 'AuthService',
    );

    // Sign in to Supabase with Google tokens
    final supabase.AuthResponse response = await _client.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (response.user == null) {
      Logger.error(
        'AuthService: No user in Supabase response',
        tag: 'AuthService',
      );
      throw AuthException('Accesso con Google fallito');
    }

    Logger.debug(
      'AuthService: Supabase authentication successful',
      tag: 'AuthService',
    );

    // Handle profile creation/retrieval
    return await _handleGoogleUserProfile(
      response.user!.id,
      googleUser.email,
      googleUser.displayName ?? '',
    );
  }

  /// OAuth Google Sign-In for Web, Windows, macOS, Linux
  Future<UserModel> _signInWithGoogleOAuth() async {
    Logger.debug(
      'AuthService: Using OAuth Google sign-in with local server',
      tag: 'AuthService',
    );

    // Start local HTTP server to receive OAuth callback
    HttpServer? server;
    try {
      // Try to bind to localhost on a random port
      server = await HttpServer.bind('127.0.0.1', 0);
      final int port = server.port;
      final String redirectUrl = 'http://127.0.0.1:$port/callback';

      Logger.debug(
        'AuthService: Local server listening on port $port',
        tag: 'AuthService',
      );

      // Create completer for the OAuth result
      final Completer<String> authCodeCompleter = Completer<String>();

      // Handle incoming requests
      server.listen((HttpRequest request) async {
        final uri = request.uri;

        if (uri.path == '/callback') {
          // Extract auth code from query parameters
          final code = uri.queryParameters['code'];

          if (code != null) {
            Logger.debug(
              'AuthService: Received auth code from callback',
              tag: 'AuthService',
            );

            // Send success response to browser
            request.response
              ..statusCode = 200
              ..headers.set('Content-Type', 'text/html; charset=utf-8')
              ..write('''
                <!DOCTYPE html>
                <html lang="it">
                <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>Accesso Effettuato - Rotante</title>
                  <link rel="preconnect" href="https://fonts.googleapis.com">
                  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700;900&display=swap" rel="stylesheet">
                  <style>
                    * {
                      margin: 0;
                      padding: 0;
                      box-sizing: border-box;
                    }
                    body {
                      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                      background: linear-gradient(135deg, #FAF8F5 0%, #F5F1ED 100%);
                      min-height: 100vh;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      color: #2C2420;
                    }
                    .container {
                      max-width: 500px;
                      padding: 48px;
                      background: #FFFFFE;
                      border-radius: 24px;
                      box-shadow: 0 8px 32px rgba(44, 36, 32, 0.08);
                      border: 1px solid #E8E0D5;
                      text-align: center;
                      animation: slideUp 0.5s ease-out;
                    }
                    @keyframes slideUp {
                      from {
                        opacity: 0;
                        transform: translateY(20px);
                      }
                      to {
                        opacity: 1;
                        transform: translateY(0);
                      }
                    }
                    .icon {
                      width: 80px;
                      height: 80px;
                      margin: 0 auto 24px;
                      background: linear-gradient(135deg, #E6B422 0%, #EDC53A 100%);
                      border-radius: 50%;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      animation: scaleIn 0.6s ease-out 0.2s both;
                    }
                    @keyframes scaleIn {
                      from {
                        transform: scale(0);
                        opacity: 0;
                      }
                      to {
                        transform: scale(1);
                        opacity: 1;
                      }
                    }
                    .icon svg {
                      width: 48px;
                      height: 48px;
                      stroke: white;
                      fill: none;
                      stroke-width: 3;
                      stroke-linecap: round;
                      stroke-linejoin: round;
                    }
                    h1 {
                      font-size: 32px;
                      font-weight: 900;
                      color: #2C2420;
                      margin-bottom: 12px;
                      letter-spacing: -0.5px;
                    }
                    p {
                      font-size: 16px;
                      font-weight: 400;
                      color: #5C4F45;
                      line-height: 1.6;
                      margin-bottom: 32px;
                    }
                    .badge {
                      display: inline-block;
                      padding: 8px 16px;
                      background: #E8F3E8;
                      color: #5B8C5A;
                      border-radius: 12px;
                      font-size: 14px;
                      font-weight: 700;
                      margin-top: 8px;
                    }
                    .footer {
                      margin-top: 32px;
                      padding-top: 24px;
                      border-top: 1px solid #E8E0D5;
                      font-size: 14px;
                      color: #8B7D70;
                    }
                  </style>
                </head>
                <body>
                  <div class="container">
                    <div class="icon">
                      <svg viewBox="0 0 24 24">
                        <polyline points="20 6 9 17 4 12"></polyline>
                      </svg>
                    </div>
                    <h1>Accesso Effettuato!</h1>
                    <p>Hai effettuato l'accesso con successo tramite Google. Puoi chiudere questa finestra e tornare all'applicazione Rotante.</p>
                    <div class="badge">✓ Autenticazione completata</div>
                  </div>
                  <script>
                    // Auto-close after 3 seconds
                    setTimeout(() => {
                      window.close();
                    }, 3000);
                  </script>
                </body>
                </html>
              ''');
            await request.response.close();

            if (!authCodeCompleter.isCompleted) {
              authCodeCompleter.complete(code);
            }
          } else {
            // Error in callback
            final error = uri.queryParameters['error'] ?? 'Unknown error';
            Logger.error(
              'AuthService: OAuth error: $error',
              tag: 'AuthService',
            );

            request.response
              ..statusCode = 400
              ..headers.set('Content-Type', 'text/html; charset=utf-8')
              ..write('''
                <!DOCTYPE html>
                <html lang="it">
                <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>Errore Autenticazione - Rotante</title>
                  <link rel="preconnect" href="https://fonts.googleapis.com">
                  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700;900&display=swap" rel="stylesheet">
                  <style>
                    * {
                      margin: 0;
                      padding: 0;
                      box-sizing: border-box;
                    }
                    body {
                      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                      background: linear-gradient(135deg, #FAF8F5 0%, #F5F1ED 100%);
                      min-height: 100vh;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      color: #2C2420;
                    }
                    .container {
                      max-width: 500px;
                      padding: 48px;
                      background: #FFFFFE;
                      border-radius: 24px;
                      box-shadow: 0 8px 32px rgba(44, 36, 32, 0.08);
                      border: 1px solid #E8E0D5;
                      text-align: center;
                      animation: slideUp 0.5s ease-out;
                    }
                    @keyframes slideUp {
                      from {
                        opacity: 0;
                        transform: translateY(20px);
                      }
                      to {
                        opacity: 1;
                        transform: translateY(0);
                      }
                    }
                    .icon {
                      width: 80px;
                      height: 80px;
                      margin: 0 auto 24px;
                      background: linear-gradient(135deg, #D4463C 0%, #E85D4A 100%);
                      border-radius: 50%;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      animation: scaleIn 0.6s ease-out 0.2s both;
                    }
                    @keyframes scaleIn {
                      from {
                        transform: scale(0);
                        opacity: 0;
                      }
                      to {
                        transform: scale(1);
                        opacity: 1;
                      }
                    }
                    .icon svg {
                      width: 48px;
                      height: 48px;
                      stroke: white;
                      fill: none;
                      stroke-width: 3;
                      stroke-linecap: round;
                      stroke-linejoin: round;
                    }
                    h1 {
                      font-size: 32px;
                      font-weight: 900;
                      color: #2C2420;
                      margin-bottom: 12px;
                      letter-spacing: -0.5px;
                    }
                    p {
                      font-size: 16px;
                      font-weight: 400;
                      color: #5C4F45;
                      line-height: 1.6;
                      margin-bottom: 32px;
                    }
                    .error-code {
                      display: inline-block;
                      padding: 8px 16px;
                      background: #FFF5F5;
                      color: #D4463C;
                      border-radius: 12px;
                      font-size: 13px;
                      font-weight: 700;
                      margin-top: 8px;
                      font-family: 'Courier New', monospace;
                    }
                    .footer {
                      margin-top: 32px;
                      padding-top: 24px;
                      border-top: 1px solid #E8E0D5;
                      font-size: 14px;
                      color: #8B7D70;
                    }
                  </style>
                </head>
                <body>
                  <div class="container">
                    <div class="icon">
                      <svg viewBox="0 0 24 24">
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                      </svg>
                    </div>
                    <h1>Errore Autenticazione</h1>
                    <p>Si è verificato un errore durante l'autenticazione con Google. Chiudi questa finestra e riprova dall'applicazione.</p>
                    <div class="error-code">$error</div>
                  </div>
                  <script>
                    // Auto-close after 5 seconds
                    setTimeout(() => {
                      window.close();
                    }, 5000);
                  </script>
                </body>
                </html>
              ''');
            await request.response.close();

            if (!authCodeCompleter.isCompleted) {
              authCodeCompleter.completeError(
                AuthException('Autenticazione fallita: $error'),
              );
            }
          }
        }
      });

      // Build OAuth URL
      final oauthResponse = await _client.auth.getOAuthSignInUrl(
        provider: supabase.OAuthProvider.google,
        redirectTo: redirectUrl,
      );

      // Parse and modify URL to force Google account selection
      final originalUri = Uri.parse(oauthResponse.url);
      final authUrl = originalUri.replace(
        queryParameters: {
          ...originalUri.queryParameters,
          'prompt': 'select_account', // Force Google account picker
        },
      );

      Logger.debug(
        'AuthService: Opening browser for OAuth with account selection',
        tag: 'AuthService',
      );

      // Open browser with OAuth URL
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw AuthException('Impossibile aprire il browser');
      }

      Logger.info(
        'AuthService: Browser opened. Waiting for OAuth completion...',
        tag: 'AuthService',
      );

      // Wait for auth code with timeout
      final authCode = await authCodeCompleter.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw AuthException('Timeout: accesso con Google scaduto');
        },
      );

      Logger.debug(
        'AuthService: Exchanging auth code for session',
        tag: 'AuthService',
      );

      // Exchange auth code for session
      await _client.auth.exchangeCodeForSession(authCode);

      // Get the current session after exchange
      final session = _client.auth.currentSession;
      final user = session?.user;

      if (user == null) {
        throw AuthException('Accesso con Google fallito');
      }

      Logger.debug(
        'AuthService: Session created for user: ${user.email}',
        tag: 'AuthService',
      );

      // Handle profile creation/retrieval
      final String displayName =
          user.userMetadata?['full_name'] ?? user.email ?? '';
      return await _handleGoogleUserProfile(
        user.id,
        user.email ?? '',
        displayName,
      );
    } finally {
      // Always close the server
      await server?.close();
      Logger.debug('AuthService: Local server closed', tag: 'AuthService');
    }
  }

  /// Common logic for handling Google user profile
  Future<UserModel> _handleGoogleUserProfile(
    String userId,
    String email,
    String displayName,
  ) async {
    // Wait a moment for the session to be fully established
    await Future.delayed(const Duration(milliseconds: 100));

    // Check if user profile exists
    UserModel? userProfile;
    try {
      Logger.debug(
        'AuthService: Checking for existing profile',
        tag: 'AuthService',
      );
      userProfile = await _getUserProfile(userId);
      if (userProfile != null) {
        Logger.debug('AuthService: Existing profile found', tag: 'AuthService');
      } else {
        Logger.debug('AuthService: Profile not found, will create new', tag: 'AuthService');
      }
    } catch (e) {
      Logger.error(
        'AuthService: Error checking profile: $e',
        tag: 'AuthService',
        error: e,
      );
      // If it's a critical DB error (like recursion), we shouldn't proceed to create a new profile blindly.
      // But for safety, if we can't read, maybe we shouldn't try to write?
      // Or we rethrow?
      // In the original code it swallowed DatabaseException and tried to create.
      // We should probably rethrow if it's not a "not found" situation.
      rethrow;
    }

    // Create profile if it doesn't exist
    if (userProfile == null) {
      Logger.debug(
        'AuthService: Creating new profile for Google user',
        tag: 'AuthService',
      );

      // Extract name from display name
      final List<String> nameParts = displayName.split(' ');
      final String nome = nameParts.isNotEmpty ? nameParts.first : 'User';
      final String cognome = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      // Create profile in database
      await _client.from(AppConstants.tableProfiles).insert({
        'id': userId,
        'email': email,
        'nome': nome,
        'cognome': cognome,
        'ruolo': UserRole.customer.name,
        'attivo': true,
        'ultimo_accesso': _nowUtcIso(),
      });

      Logger.debug(
        'AuthService: Profile created, fetching it',
        tag: 'AuthService',
      );

      // Fetch the newly created profile
      userProfile = await _getUserProfile(userId);
      if (userProfile == null) {
        throw AuthException('Impossibile recuperare il profilo dopo la creazione');
      }
    }
    
    // Ensure userProfile is not null here
    final profile = userProfile!;

    // Check if user is active
    if (!profile.attivo) {
      Logger.warning(
        'AuthService: User account is inactive',
        tag: 'AuthService',
      );
      await signOut();
      throw AuthException('Account disattivato. Contatta il supporto.');
    }

    // Update last access
    Logger.debug('AuthService: Updating last access', tag: 'AuthService');
    await updateLastAccess(profile.id);

    // Save FCM token for notifications
    Logger.debug('AuthService: Saving FCM token', tag: 'AuthService');
    await FirebaseConfig.saveFcmTokenForCurrentUser();

    Logger.debug(
      'AuthService: Google sign-in completed successfully',
      tag: 'AuthService',
    );
    return profile;
  }

  Future<UserModel?> _getUserProfile(String userId) async {
    try {
      final data = await _client
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserModel.fromJson(data);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseException('Errore recupero profilo: ${e.message}');
    } catch (e) {
      throw DatabaseException('Errore imprevisto recupero profilo: $e');
    }
  }

  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _client
          .from(AppConstants.tableProfiles)
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (e) {
      // Logging volutamente semplice per evitare crash in background
      // ignore: avoid_print
      print('Warning: Could not update FCM token: $e');
    }
  }

  Future<void> updateLastAccess(String userId) async {
    try {
      await _client
          .from(AppConstants.tableProfiles)
          .update({'ultimo_accesso': _nowUtcIso()})
          .eq('id', userId);
    } catch (e) {
      // ignore: avoid_print
      print('Warning: Could not update last access: $e');
    }
  }

  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();
}
