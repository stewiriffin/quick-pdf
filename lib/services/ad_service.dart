import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that owns the interstitial ad lifecycle.
/// The banner is managed separately in _BannerAdArea (main_nav_page.dart).
///
/// Frequency capping: shows an interstitial at most once every
/// [_capEveryN] tool completions to reduce ad fatigue.
class AdService {
  AdService._();
  static final AdService _instance = AdService._();
  factory AdService() => _instance;

  static const String bannerAdUnitId =
      'ca-app-pub-9418386170210711/8362178112';
  static const String interstitialAdUnitId =
      'ca-app-pub-9418386170210711/3537611287';

  static const String _rewardedAdUnitId =
      'ca-app-pub-9418386170210711/3537611287'; // replace with real rewarded ID
  static const String _prefCompletions = 'ad_completion_count';
  static const int _capEveryN = 3;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  bool get isInterstitialReady => _isInterstitialReady;

  // ── Ads enabled flag (for testing / user preference) ──────────────────────

  static bool adsEnabled = true;

  // ── Interstitial ──────────────────────────────────────────────────────────

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
              loadInterstitial();
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

  /// Call after each tool completion. Shows an interstitial once every
  /// [_capEveryN] completions. Silently skips if ads are disabled or not ready.
  Future<void> recordToolCompletion() async {
    if (!adsEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_prefCompletions) ?? 0) + 1;
    await prefs.setInt(_prefCompletions, count);
    if (count % _capEveryN == 0) {
      showInterstitialIfReady();
    }
  }

  void showInterstitialIfReady() {
    if (!adsEnabled) return;
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  // ── Rewarded ads ──────────────────────────────────────────────────────────

  /// Loads and shows a rewarded ad, calling [onRewarded] if the user earns
  /// the reward. Falls back to calling [onRewarded] immediately if the ad
  /// fails, so the feature is never blocked.
  Future<void> showRewardedOrFallback({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (!adsEnabled) {
      onRewarded();
      return;
    }

    RewardedAd? ad;
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (loaded) => ad = loaded,
        onAdFailedToLoad: (error) {
          debugPrint('AdService: rewarded load failed — $error. Falling back.');
          onRewarded(); // never block the user
        },
      ),
    );

    if (ad == null) return; // already handled by onAdFailedToLoad

    ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        ad!.dispose();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('AdService: rewarded show failed — $error. Falling back.');
        ad!.dispose();
        onRewarded(); // fall back
      },
    );

    await ad!.show(
      onUserEarnedReward: (_, __) => onRewarded(),
    );
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
