import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dio cancellation issue',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Dio cancellation issue'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  int _downloaded = 0;
  bool _running = false;
  Exception? _failed;
  CancelToken cancelToken = CancelToken();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('_downloaded: ${_downloaded}, _running: ${_running}, _failed: ${_failed?.toString()},')
            ],
          ),
        ),
        floatingActionButton:
        Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                onPressed: () async {
                  fetch(ResponseType.bytes);
                },
                tooltip: 'Start bytes',
                child: const Icon(Icons.start),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FloatingActionButton(
                onPressed: () async {
                  fetch(ResponseType.stream);
                },
                tooltip: 'Start stream',
                child: const Icon(Icons.start),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                onPressed: () => cancelToken.cancel(),
                tooltip: 'Cancel',
                child: const Icon(Icons.cancel),
              ),
            ),
          ],
        )
    );
  }

  fetch(ResponseType responseType) async {
    final url = "http://ash-speed.hetzner.com/100MB.bin";

    final dio = Dio();

    final options = Options(
      // responseType: ResponseType.bytes, // Works fine
      // responseType: ResponseType.stream, // No effect
      responseType: responseType
    );

    // For ResponseType.bytes purposes
    onReceiveProgress(int sent, int __) {
      setState(() {
        _downloaded = sent;
      });
      return;
    }

    try {

      setState(() {
        _running = true;
        _failed = null;
        cancelToken = CancelToken();
      });

      final response = await dio.get(url, options: options, cancelToken: cancelToken, onReceiveProgress: onReceiveProgress);
      final status = response.statusCode;

      var downloadedTotalStream = 0;
      if (status == 200) {
        await for (final List<int> dataChunk in response.data.stream) {
          downloadedTotalStream += dataChunk.length;
          setState(() {
            _downloaded = downloadedTotalStream;
          });
        }
      } else {
        setState(() {
          _failed = Exception("Status code: $status");
        });
      }

    } catch(e) {
      setState(() {
        _failed = e as Exception;
      });
    }

    setState(() {
      _running = false;
    });
  }
}
