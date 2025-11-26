import 'dart:convert';
import 'package:Ziepick/settings.dart';
import 'package:Ziepick/ui/theme/theme.dart';
import 'package:Ziepick/utils/extensions/extensions.dart';
import 'package:Ziepick/utils/hive_utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

bool _looksLikeBase64(String s) {
  final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
  return s.isNotEmpty && base64Regex.hasMatch(s) && s.length % 4 == 0;
}

String? decodeBase64ToPlain(String base64Str) {
  try {
    final bytes = base64Decode(base64Str);
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

class Base64QrScannerPage extends StatefulWidget {
  const Base64QrScannerPage({super.key});

  @override
  State<Base64QrScannerPage> createState() => _Base64QrScannerPageState();
}

class _Base64QrScannerPageState extends State<Base64QrScannerPage> {
  bool _handled = false;
  String? scannedId;
  String? scannedName;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    
    // Using HTML5 QR Code scanner
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'QRScanner',
        onMessageReceived: (JavaScriptMessage message) {
          if (_handled) return;
          final raw = message.message;
          if (raw.isEmpty) return;

          _handled = true;

          if (_looksLikeBase64(raw)) {
            final decoded = decodeBase64ToPlain(raw);
            if (decoded != null) {
              if (decoded.contains('**')) {
                final clean = decoded.replaceAll('**', '');
                final parts = clean.split('#');
                scannedId = parts.isNotEmpty ? parts[0] : '';
                scannedName = parts.length > 1 ? parts[1] : '';
                _openFormAfterClosingScanner(context);
              } else {
                _showErrorAfterClosingScanner(context, 'Invalid QR code');
              }
            } else {
              _showErrorAfterClosingScanner(context, 'Invalid base64 payload');
            }
          } else {
            _showErrorAfterClosingScanner(context, 'Scanned text is not base64');
          }
        },
      )
      ..loadHtmlString(_getQRScannerHTML());
  }

  String _getQRScannerHTML() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js"></script>
  <style>
    body { margin: 0; padding: 0; background: #000; }
    #reader { width: 100%; height: 100vh; }
  </style>
</head>
<body>
  <div id="reader"></div>
  <script>
    function onScanSuccess(decodedText, decodedResult) {
      QRScanner.postMessage(decodedText);
    }
    
    const html5QrCode = new Html5Qrcode("reader");
    html5QrCode.start(
      { facingMode: "environment" },
      { fps: 10, qrbox: { width: 250, height: 250 } },
      onScanSuccess
    );
  </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: context.color.territoryColor,
      ),
      body: WebViewWidget(controller: _webViewController),
    );
  }

  void _showError(String msg,BuildContext rootContext) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(rootContext, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  void _showErrorAfterClosingScanner(BuildContext scannerContext,String msg) {
    Navigator.of(scannerContext).pop();

    Future.delayed(const Duration(milliseconds: 50), () {
      final rootContext = Navigator.of(scannerContext, rootNavigator: true).context;

      _showError(msg,rootContext);
    });
  }

  void _openFormAfterClosingScanner(BuildContext scannerContext) {
    Navigator.of(scannerContext).pop();

    Future.delayed(const Duration(milliseconds: 50), () {
      final rootContext = Navigator.of(scannerContext, rootNavigator: true).context;

      _showFormDialog(rootContext);
    });
  }

  void _showFormDialog(BuildContext rootContext) {
    final priceController = TextEditingController();
    final discountController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submitForm() async {
              final price = priceController.text.trim();
              final discount = discountController.text.trim();

              // Validation
              if (price.isEmpty) {
                Fluttertoast.showToast(msg: "Please enter product price");
                return;
              }
              if (discount.isEmpty) {
                Fluttertoast.showToast(msg: "Please enter discount");
                return;
              }

              setState(() => isLoading = true);

              try {

                Map<String,dynamic> rawData = {
                  'user_id': HiveUtils.getUserDetails().id.toString(),
                  'vendor_id': scannedId ?? "",
                  'prize': price,
                  'discount': discount,
                };

                print("!!!!! $rawData");

                var response = await http.post(Uri.parse('${AppSettings.baseUrl}discount'),body: rawData);

                print("***** ${response.statusCode} === ${response.body}");

                if (response.statusCode == 200) {
                  var jsonData = jsonDecode(response.body);

                  if (jsonData["error"] == false) {
                    Fluttertoast.showToast(msg: jsonData["message"] ?? "Success");
                    Navigator.of(dialogContext, rootNavigator: true).pop(); // Close dialog
                  } else {
                    Fluttertoast.showToast(msg: jsonData["message"] ?? "Something went wrong");
                  }
                } else {
                  Fluttertoast.showToast(msg: "Server error: ${response.statusCode}");
                }
              } catch (e) {
                Fluttertoast.showToast(msg: "Error: $e");
              }

              setState(() => isLoading = false);
            }

            return AlertDialog(
              title: const Text('Product Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vendor Name
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Vendor Name',
                      ),
                      controller: TextEditingController(text: scannedName ?? ''),
                      readOnly: true,
                    ),
                    const SizedBox(height: 8),
                    // Product Price
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Product Price',
                      ),
                      controller: priceController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    // Discount
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Discount',
                      ),
                      controller: discountController,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : submitForm,
                  child: isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
