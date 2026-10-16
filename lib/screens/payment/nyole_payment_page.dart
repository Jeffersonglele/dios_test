import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Page de paiement Nyole (WebView).
///
/// Se ferme avec `true` quand Nyole redirige vers la page de retour du
/// backend avec `status=success`, `false` sinon (annulation, échec, retour
/// arrière). Le retour « succès » n'est PAS une preuve de paiement : la
/// commande n'est confirmée qu'après vérification serveur (webhook).
class NyolePaymentPage extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final VoidCallback? onPaymentSuccess;
  final VoidCallback? onPaymentFailed;
  final VoidCallback? onPaymentCancelled;

  const NyolePaymentPage({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    this.onPaymentSuccess,
    this.onPaymentFailed,
    this.onPaymentCancelled,
  });

  @override
  State<NyolePaymentPage> createState() => _NyolePaymentPageState();
}

class _NyolePaymentPageState extends State<NyolePaymentPage> {
  bool _isLoading = true;
  double _loadingProgress = 0;

  /// Évite de fermer la page deux fois (shouldOverrideUrlLoading puis
  /// onLoadStop pour la même URL), ce qui fermerait aussi le panier.
  bool _finished = false;

  static final String? _backendHost =
      Uri.tryParse(AppConfig.nodeBackendUrl)?.host;

  /// Statut lu sur l'URL de retour du backend
  /// (`/payments/nyole/return?status=success|cancelled`), sinon null.
  static String? _returnStatus(Uri? uri) {
    if (uri == null) return null;
    final isReturnPath = uri.path.contains('/payments/nyole/return');
    final isBackend = _backendHost != null &&
        _backendHost!.isNotEmpty &&
        uri.host == _backendHost;
    if (!isReturnPath && !isBackend) return null;
    final status = uri.queryParameters['status']?.trim().toLowerCase();
    if (status == null || status.isEmpty) return isReturnPath ? 'unknown' : null;
    return status;
  }

  /// Retourne true si l'URL est la page de retour (et ferme la page).
  bool _handleUrl(Uri? uri) {
    final status = _returnStatus(uri);
    if (status == null) return false;
    _finish(status == 'success' || status == 'succes' || status == 'paid');
    return true;
  }

  void _finish(bool success) {
    if (_finished || !mounted) return;
    _finished = true;
    if (success) {
      widget.onPaymentSuccess?.call();
    } else {
      widget.onPaymentFailed?.call();
    }
    Navigator.of(context).pop(success);
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final cancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.nyole_cancel_title),
        content: Text(l10n.nyole_cancel_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.nyole_continue),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  AppColors.resolve(AppColors.error, AppDarkColors.error),
            ),
            child: Text(l10n.nyole_cancel),
          ),
        ],
      ),
    );
    if (cancel == true && !_finished && mounted) {
      _finished = true;
      widget.onPaymentCancelled?.call();
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);

    return PopScope(
      // Le retour système passe par la confirmation d'annulation.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_finished) _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: ink),
            onPressed: _confirmCancel,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 17, color: brand),
              const SizedBox(width: 6),
              Text(
                l10n.nyole_title,
                style: AppTypography.titleMedium(color: ink),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isLoading ? 1 : 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                value: _loadingProgress > 0 ? _loadingProgress : null,
                color: brand,
                backgroundColor: brand.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.paymentUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                useHybridComposition: true,
                allowsInlineMediaPlayback: true,
              ),
              onLoadStart: (controller, url) {
                if (_handleUrl(url)) return;
                setState(() {
                  _isLoading = true;
                  _loadingProgress = 0;
                });
              },
              onLoadStop: (controller, url) {
                if (_handleUrl(url)) return;
                setState(() => _isLoading = false);
              },
              onProgressChanged: (controller, progress) {
                setState(() => _loadingProgress = progress / 100);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                // Inutile de charger la page de retour : on ferme directement.
                return _handleUrl(navigationAction.request.url)
                    ? NavigationActionPolicy.CANCEL
                    : NavigationActionPolicy.ALLOW;
              },
            ),
            if (_isLoading && _loadingProgress < 0.3)
              ColoredBox(
                color: surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: brand,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.nyole_loading,
                        style: AppTypography.bodyMedium(color: inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
