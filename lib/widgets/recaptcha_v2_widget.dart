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
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.162 Mobile Safari/537.36")
      ..setBackgroundColor(const Color(0x00000000))
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint("🌐 WEBVIEW CONSOLE: ${message.message}");
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            debugPrint("🏁 reCAPTCHA WebView Page Loaded: $url");
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("❌ WebView Resource Error: ${error.errorCode} - ${error.description}");
            if (widget.onError != null) {
              widget.onError!(error.description);
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'CaptchaChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint("🎟️ Token received via channel!");
          widget.onVerified(message.message);
        },
      )
      ..loadHtmlString(_buildHtml(), baseUrl: "https://localhost");
  }

  String _buildHtml() {
    debugPrint("🏗️ Building HTML with Key: ${widget.siteKey}");
    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>reCAPTCHA</title>
        <script src="https://www.google.com/recaptcha/api.js?render=explicit" async defer></script>
        <style>
          body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            background-color: transparent;
            overflow: hidden;
          }
          #captcha-container {
            width: 304px;
            height: 78px;
          }
        </style>
        <script type="text/javascript">
          var captchaCallback = function(response) {
            CaptchaChannel.postMessage(response);
          };
          var onloadCallback = function() {
            grecaptcha.render('captcha-container', {
              'sitekey' : '${widget.siteKey}',
              'callback' : captchaCallback,
              'theme' : 'light'
            });
          };
        </script>
      </head>
      <body onload="onloadCallback()">
        <div id="captcha-container"></div>
      </body>
      </html>
    """;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120, // Increased slightly
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(51)), // 0.2 * 255 = 51
        borderRadius: BorderRadius.circular(8),
      ),
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
