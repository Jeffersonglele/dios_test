import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _loadingProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showCancelDialog();
          },
        ),
        actions: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _loadingProgress,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.paymentUrl)),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                useOnLoadResource: true,
              ),
              android: AndroidInAppWebViewOptions(
                useHybridComposition: true,
              ),
              ios: IOSInAppWebViewOptions(
                allowsInlineMediaPlayback: true,
              ),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
                _loadingProgress = 0;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });

              // Vérifier si l'URL contient des indicateurs de succès/échec
              if (url != null) {
                _checkPaymentStatus(url.toString());
              }
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _loadingProgress = progress / 100;
              });
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url;

              if (url != null) {
                // Détecter les URLs de retour après paiement
                await _checkPaymentStatus(url.toString());
              }

              return NavigationActionPolicy.ALLOW;
            },
            onConsoleMessage: (controller, consoleMessage) {
              // Pour le débogage
              print('WebView Console: ${consoleMessage.message}');
            },
          ),
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Chargement de la page de paiement...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _checkPaymentStatus(String urlString) async {
    final urlLower = urlString.toLowerCase();
    
    // Vous pouvez adapter ces patterns selon les URLs de retour de Nyole
    // Typiquement, les gateways de paiement redirigent vers des URLs spécifiques
    // selon le statut du paiement
    
    // Exemple: vérifier si l'URL contient des indicateurs de succès
    if (urlLower.contains('success') ||
        urlLower.contains('completed') ||
        urlLower.contains('paid')) {
      _handlePaymentSuccess();
    }
    // Exemple: vérifier si l'URL contient des indicateurs d'échec
    else if (urlLower.contains('failed') ||
             urlLower.contains('error') ||
             urlLower.contains('cancelled')) {
      _handlePaymentFailed();
    }
  }

  void _handlePaymentSuccess() {
    // Ne fermer que si nous ne sommes pas déjà en train de naviguer
    if (!_isLoading && mounted) {
      widget.onPaymentSuccess?.call();
      Navigator.pop(context, true);
    }
  }

  void _handlePaymentFailed() {
    if (!_isLoading && mounted) {
      widget.onPaymentFailed?.call();
      Navigator.pop(context, false);
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le paiement?'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler le paiement? '
          'Votre commande ne sera pas validée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer le paiement'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onPaymentCancelled?.call();
              Navigator.pop(context, false);
            },
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
