import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/constants.dart';

enum ExternalOfferAvailability { unknown, available, unavailable }

class ExternalOffersService {
  static const String _pricingUrl = 'https://meowmin.taucity.xyz/pricing';

  /// Paddle price id for the hero Yearly plan on /pricing.
  static const String yearlyPriceId = 'pri_01m1h2jqe88brc2grgnr20jv80';

  final FlutterInappPurchase _iap = FlutterInappPurchase.instance;
  bool _initDone = false;

  Future<void> _ensureInit() async {
    if (_initDone) return;
    await _iap.initConnection();
    _initDone = true;
  }

  Future<ExternalOfferAvailability> checkAvailability() async {
    try {
      await _ensureInit();
      final result = await _iap.isBillingProgramAvailableAndroid(
        BillingProgramAndroid.ExternalOffer,
      );
      return result.isAvailable
          ? ExternalOfferAvailability.available
          : ExternalOfferAvailability.unavailable;
    } on PlatformException catch (_) {
      return ExternalOfferAvailability.unavailable;
    } catch (_) {
      return ExternalOfferAvailability.unknown;
    }
  }

  Future<String?> createReportingToken() async {
    try {
      await _ensureInit();
      final details = await _iap.createBillingProgramReportingDetailsAndroid(
        BillingProgramAndroid.ExternalOffer,
      );
      return details.externalTransactionToken;
    } on PlatformException catch (e) {
      throw ExternalOffersException('createReportingToken failed: ${e.message}');
    } catch (e) {
      throw ExternalOffersException('createReportingToken failed: $e');
    }
  }

  Future<bool> launchExternalLink({
    required String externalTransactionToken,
    required String linkUri,
  }) async {
    try {
      await _ensureInit();
      final ok = await _iap.launchExternalLinkAndroid(
        LaunchExternalLinkParamsAndroid(
          billingProgram: BillingProgramAndroid.ExternalOffer,
          externalTransactionToken: externalTransactionToken,
          launchMode: ExternalLinkLaunchModeAndroid.LaunchInExternalBrowserOrApp,
          linkType: ExternalLinkTypeAndroid.LinkToDigitalContentOffer,
          linkUri: linkUri,
        ),
      );
      return ok;
    } on PlatformException catch (e) {
      throw ExternalOffersException('launchExternalLink failed: ${e.message}');
    } catch (e) {
      throw ExternalOffersException('launchExternalLink failed: $e');
    }
  }

  // Mint a backend checkout session carrying the fresh PBL reporting
  // token. Returns the opaque sid (256-bit capability handle).
  // Retries once with a force-refreshed ID token on 401 (token race
  // after sign-in); anything else throws.
  Future<String> mintSession({
    required String externalTransactionToken,
    String? rcCustomerId,
  }) async {
    final uri = Uri.parse('${AppConstants.backendUrl}/external-offer/session');
    final body = jsonEncode({
      'external_transaction_token': externalTransactionToken,
      if (rcCustomerId != null) 'rc_customer_id': rcCustomerId,
    });
    http.Response res = await http.post(
      uri,
      headers: await ApiClient.postHeaders(),
      body: body,
    );
    if (res.statusCode == 401) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.getIdToken(true);
        } catch (_) {
          // fall through to the retry with whatever headers we can build
        }
        res = await http.post(
          uri,
          headers: await ApiClient.postHeaders(),
          body: body,
        );
      }
    }
    if (res.statusCode != 200) {
      throw ExternalOffersException('mintSession failed: HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final sid = decoded['sid'] as String?;
    if (sid == null || sid.isEmpty) {
      throw ExternalOffersException('mintSession failed: no sid in response');
    }
    return sid;
  }

  // Full EEA checkout: ensure a Firebase identity (anonymous if needed so
  // the purchase is attributable) -> reporting token -> backend session ->
  // external browser link-out to /pricing?price=...&sid=... (no PII in URL).
  // Returns true when the link was launched.
  Future<bool> openCheckout({
    String priceId = yearlyPriceId,
    String? rcCustomerId,
  }) async {
    var user = FirebaseAuth.instance.currentUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      throw ExternalOffersException('Sign-in required before checkout');
    }
    final token = await createReportingToken();
    if (token == null || token.isEmpty) {
      throw ExternalOffersException('No reporting token from Play Billing');
    }
    final sid = await mintSession(
      externalTransactionToken: token,
      rcCustomerId: rcCustomerId ?? uid,
    );
    final linkUri = '$_pricingUrl?price=$priceId&sid=${Uri.encodeComponent(sid)}';
    return launchExternalLink(
      externalTransactionToken: token,
      linkUri: linkUri,
    );
  }

  Future<void> resumeRefresh() async {
    if (!_initDone) return;
    try {
      await _iap.initConnection();
    } on PlatformException catch (_) {
      // ignore
    } catch (_) {
      // ignore
    }
  }
}

class ExternalOffersException implements Exception {
  final String message;
  ExternalOffersException(this.message);
  @override
  String toString() => 'ExternalOffersException: $message';
}