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
      this.onClickEvent,
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

  final Function(String value)? onClickEvent;

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
      ..addJavaScriptChannel(
        'ClickEventChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final Map<String, dynamic> data = jsonDecode(message.message);

          if (widget.onClickEvent != null) {
            widget.onClickEvent!(data['watchId']);
          }
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

  /// Injects JavaScript handler to listen for HighCharts click events
  void injectFlutterBridge() {
    _controller.runJavaScript('''
      window.sendDataToFlutter = function(data) {
        try {
          var jsonData = JSON.stringify(data);
          ClickEventChannel.postMessage(jsonData);
        } catch (error) {
          console.error("🔥 Error sending data to Flutter:", error);
        }
      };
    ''');
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
      injectFlutterBridge();
      _controller.runJavaScriptReturningResult(
          "senthilnasa(`Highcharts.chart('highChartsDiv',${widget.data} )`);");
    }
  }
}
