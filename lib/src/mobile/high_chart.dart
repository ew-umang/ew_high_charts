import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';

// import 'package:webview_flutter_android/webview_flutter_android.dart';
// import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

///
///A Chart library based on [High Charts (.JS)](https://www.highcharts.com/)
///
class HighCharts extends StatefulWidget {
  const HighCharts(
      {required this.data,
      required this.size,
      this.loader = const Center(child: CircularProgressIndicator()),
      this.scripts = const [],
      super.key});

  ///Custom `loader` widget, until script is loaded
  ///
  ///Has no effect on Web
  ///
  ///Defaults to `CircularProgressIndicator`
  final Widget loader;

  ///Chart data
  ///
  ///(use `jsonEncode` if the data is in `Map<String,dynamic>`)
  ///
  ///Reference: [High Charts API](https://api.highcharts.com/highcharts)
  ///
  ///```dart
  ///String chart_data = '''{
  ///      title: {
  ///          text: 'Combination chart'
  ///      },
  ///      xAxis: {
  ///          categories: ['Apples', 'Oranges', 'Pears', 'Bananas', 'Plums']
  ///      },
  ///      labels: {
  ///          items: [{
  ///              html: 'Total fruit consumption',
  ///              style: {
  ///                  left: '50px',
  ///                  top: '18px',
  ///                  color: (
  ///                      Highcharts.defaultOptions.title.style &&
  ///                      Highcharts.defaultOptions.title.style.color
  ///                  ) || 'black'
  ///              }
  ///          }]
  ///      },
  ///
  ///      ...
  ///
  ///    }''';
  ///
  ///```
  ///
  ///Reference: [High Charts API](https://api.highcharts.com/highcharts)
  final String data;

  ///Chart size
  ///
  ///Height and width of the chart is required
  ///
  ///```dart
  ///Size size = Size(400, 300);
  ///```
  final Size size;

  ///Scripts to be loaded
  ///
  ///Url's of the hightchart js scripts.
  ///
  ///Reference: [Full Scripts list](https://code.highcharts.com/)
  ///
  ///or use any CDN hosted script
  ///
  ///### For `android` and `ios` platforms, the scripts must be provided
  ///
  ///```dart
  ///List<String> scripts = [
  ///  'https://code.highcharts.com/highcharts.js',
  ///  'https://code.highcharts.com/modules/exporting.js',
  ///  'https://code.highcharts.com/modules/export-data.js'
  /// ];
  /// ```
  ///
  ///### For `web` platform, the scripts must be provided in `web/index.html`
  ///
  ///```html
  ///<head>
  ///   <script src="https://code.highcharts.com/highcharts.js"></script>
  ///   <script src="https://code.highcharts.com/modules/exporting.js"></script>
  ///   <script src="https://code.highcharts.com/modules/export-data.js"></script>
  ///</head>
  ///```
  ///
  final List<String> scripts;
  @override
  HighChartsState createState() => HighChartsState();
}

class HighChartsState extends State<HighCharts> {
  bool _isLoaded = false;

  late WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        "FlutterChannel",
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..addJavaScriptChannel(
        "FlutterConsole",
        onMessageReceived:
            _handleConsoleMessage, // Capture console logs & errors
      )
      ..setNavigationDelegate(
        NavigationDelegate(onWebResourceError: (WebResourceError error) {
          debugPrint('Highcharts WebView Error: ${error.description}');
        }, onPageFinished: (String url) {
          _loadData();
        }),
      )
      ..addJavaScriptChannel(
        'FlutterHighchartsChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Highcharts Error: ${message.message}');
        },
      )
      ..setOnConsoleMessage(
        (JavaScriptConsoleMessage message) {
          debugPrint('Highcharts CONSOLE Error: ${message.message}');
        },
      )
      ..loadHtmlString(_htmlContent());

    if (!Platform.isMacOS) {
      _controller.setBackgroundColor(Colors.transparent);
    }
  }

  void _handleConsoleMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      if (data['type'] == 'console_error') {
        print("🔥 JavaScript ERROR: ${data['message']}");
      } else if (data['type'] == 'console_log') {
        print("📋 JavaScript LOG: ${data['message']}");
      } else if (data['type'] == 'error') {
        print(
            "🚨 JavaScript Exception: ${data['message']} (Source: ${data['source']} Line: ${data['line']} Column: ${data['column']})");
        if (data['error'] != null) {
          print("📝 Stack Trace: ${data['error']}");
        }
      }
    } catch (e) {
      print("⚠️ Error parsing JavaScript message: $e");
    }
  }

  /// Injects JavaScript handler to listen for HighCharts click events
  Future<void> _injectJavaScriptHandler() async {
    await _controller.runJavaScript("""
    window.onerror = function(message, source, lineno, colno, error) {
      var errorMsg = JSON.stringify({
        type: "error",
        message: message,
        source: source,
        line: lineno,
        column: colno,
        error: error ? error.stack : "No stack trace"
      });

      console.error("🔥 Full JavaScript Error:", errorMsg);
      
      if (window.FlutterConsole) {
        FlutterConsole.postMessage(errorMsg);
      }
    };

    console.log("✅ JavaScript Error Logging Activated.");
  """);
  }

  /// Handles messages from WebView (HighCharts click events)
  void _handleJavaScriptMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Watch Details"),
        content: Text(
          "ID: ${data['watchId']}",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("OK")),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant HighCharts oldWidget) {
    if (oldWidget.data != widget.data ||
        oldWidget.size != widget.size ||
        oldWidget.scripts != widget.scripts) {
      _controller.loadHtmlString(_htmlContent());
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size.height,
      width: widget.size.width,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          !_isLoaded ? widget.loader : const SizedBox.shrink(),
          WebViewWidget(controller: _controller)
        ],
      ),
    );
  }

  String _htmlContent() {
    String html = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script>
            window.onerror = function(msg, url, line, col, error) {
              FlutterHighchartsChannel.postMessage(
                JSON.stringify({
                  message: msg,
                  url: url,
                  line: line,
                  column: col,
                  error: error?.stack
                })
              );
              return false;
            };
            
            function senthilnasa(a) {
              try {
                eval(a);
                return true;
              } catch (error) {
                FlutterHighchartsChannel.postMessage(error.toString());
                return false;
              }
            }
          </script>
        </head>
        <body>
          <div style="height:100%;width:100%;" id="highChartsDiv"></div>
    ''';

    for (String src in widget.scripts) {
      html += '<script src="$src"></script>';
    }

    html += '</body></html>';
    return html;
  }

  void _loadData() async {
    if (mounted) {
      setState(() {
        _isLoaded = true;
      });
      await _injectJavaScriptHandler();
      _controller.runJavaScriptReturningResult(
          "senthilnasa(`Highcharts.chart('highChartsDiv',${widget.data} )`);");
    }
  }
}
