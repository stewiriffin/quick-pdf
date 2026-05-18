import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Singleton that owns the interstitial ad lifecycle.
/// The banner is managed separately in _BannerAdArea (main_nav_page.dart)
/// so it can handle its own widget lifecycle (mount/unmount).
class AdService {
  AdService._();
  static final AdService _instance = AdService._();
  factory AdService() => _instance;

  static const String bannerAdUnitId =
      'ca-app-pub-9418386170210711/8362178112';
  static const String interstitialAdUnitId =
      'ca-app-pub-9418386170210711/3537611287';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  bool get isInterstitialReady => _isInterstitialReady;

  /// Load (or reload) the interstitial. Called once at startup and after
  /// every dismissal so there is always a preloaded ad ready.
  void loadInterstitial() {
    _isInterstitialReady = false;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialReady = false;
              loadInterstitial(); // preload next
            },
            onAdFailedToShowFullScreenContent: (_, error) {
              debugPrint('AdService: interstitial show failed — $error');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialReady = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: interstitial load failed — $error');
          _interstitialAd = null;
          _isInterstitialReady = false;
        },
      ),
    );
  }

  /// Show the interstitial if one is ready. Silently skips if not loaded yet,
  /// so callers never need to check readiness themselves.
  void showInterstitialIfReady() {
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
