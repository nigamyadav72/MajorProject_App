import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RecaptchaV2Widget extends StatefulWidget {
  final String siteKey;
  final Function(String token) onVerified;
  final Function(String error)? onError;

  const RecaptchaV2Widget({
    super.key,
    required this.siteKey,
    required this.onVerified,
    this.onError,
  });

  @override
  State<RecaptchaV2Widget> createState() => _RecaptchaV2WidgetState();
}

class _RecaptchaV2WidgetState extends State<RecaptchaV2Widget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (widget.onError != null) {
              widget.onError!(error.description);
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'CaptchaChannel',
        onMessageReceived: (JavaScriptMessage message) {
          widget.onVerified(message.message);
        },
      )
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://www.google.com/recaptcha/api.js" async defer></script>
        <style>
          body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            background-color: transparent;
          }
          .g-recaptcha {
            transform: scale(0.9);
            transform-origin: 0 0;
          }
        </style>
        <script type="text/javascript">
          var captchaCallback = function(response) {
            CaptchaChannel.postMessage(response);
          };
        </script>
      </head>
      <body>
        <div class="g-recaptcha" 
             data-sitekey="${widget.siteKey}" 
             data-callback="captchaCallback">
        </div>
      </body>
      </html>
    """;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100, // Standard height for reCAPTCHA v2 checkbox
      width: double.infinity,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
