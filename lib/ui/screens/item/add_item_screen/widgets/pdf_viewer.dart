import 'package:Ziepick/ui/theme/theme.dart';
import 'package:Ziepick/utils/extensions/extensions.dart';
import 'package:Ziepick/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PdfViewer extends StatefulWidget {
  final String url;

  const PdfViewer({Key? key, required this.url}) : super(key: key);

  @override
  _PDFViewerState createState() => _PDFViewerState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return MaterialPageRoute(
      builder: (_) => PdfViewer(
        url: arguments?['url'],
      ),
    );
  }
}

class _PDFViewerState extends State<PdfViewer> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Use Google Docs Viewer to display PDF
    final pdfUrl = Uri.encodeFull(widget.url);
    final viewerUrl = 'https://docs.google.com/gview?embedded=true&url=$pdfUrl';

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        backgroundColor: context.color.secondaryDetailsColor,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
