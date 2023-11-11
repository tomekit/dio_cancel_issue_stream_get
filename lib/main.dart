import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    print("--------------------------------");
    print("Framework error:  ${details.exception}");
    print("Stacktrace :  ${details.stack}");
  };

  runZonedGuarded(() async {
    runApp(const MyApp());
  },(error, stackTrace) {
    print("--------------------------------");
    print("Error:  $error");
    print("Stacktrace:  $stackTrace");
  });
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
              Text('_downloaded: ${_downloaded}, _running: ${_running}, _failed: ${_failed?.toString()},'),
              SizedBox(height: 5,),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [FloatingActionButton(
                onPressed: () async {
                  fetch(ResponseType.bytes);
                },
                tooltip: 'Start non-streamed download (Cancellation works OK)',
                child: const Icon(Icons.start),
              ),
                FloatingActionButton(
                  onPressed: () async {
                    fetch(ResponseType.stream);
                  },
                  tooltip: 'Start streamed download (Cancellation doesn\'t work !)',
                  child: const Icon(Icons.play_arrow, color: Colors.redAccent),
                ),
                FloatingActionButton(
                  onPressed: () => cancelToken.cancel(),
                  tooltip: 'Cancel',
                  child: const Icon(Icons.cancel),
                ),
                  const VerticalDivider(
                    width: 10,
                    thickness: 1,
                    indent: 10,
                    endIndent: 0,
                    // color: Colors.redAccent,
                  ),
                FloatingActionButton(
                  onPressed: () async {
                    _manageResponse();
                  },
                  tooltip: 'Uncaught exception test from async* (no effect !)',
                  child: const Icon(Icons.error, color: Colors.redAccent),
                ),
                FloatingActionButton(
                  onPressed: () async {
                    try {
                      _manageResponse();
                    } catch(e) {
                      print('Try/catch handled: $e');
                    }
                  },
                  tooltip: 'Try/catch handling test from async* (no effect !)',
                  child: const Icon(Icons.error, color: Colors.redAccent),
                ),
                  FloatingActionButton(
                    onPressed: () async {
                      throw Exception("Hi, I am an uncaught exception !");
                    },
                    tooltip: 'Uncaught exception test (works OK)',
                    child: const Icon(Icons.error),
                  ),
                // FloatingActionButton(
                //   onPressed: () async {
                //     try {
                //       await _manageResponse().toList();
                //     } catch (e) {
                //       print('Try/catch handled: $e');
                //     }
                //   },
                //   tooltip: 'Test (try/catch) exception handling from async*',
                //   child: const Icon(Icons.error),
                // ),
                // FloatingActionButton(
                //   onPressed: () async {
                //     await _manageResponse().toList();
                //   },
                //   tooltip: 'Test uncaught exception from async*',
                //   child: const Icon(Icons.error),
                // ),
                // FloatingActionButton(
                //   onPressed: () {
                //     _manageResponse().toList();
                //   },
                //   tooltip: 'Test uncaught exception from async* (no await)',
                //   child: const Icon(Icons.error),
                // ),
                // FloatingActionButton(
                //   onPressed: () {
                //     _manageResponse().toList().catchError((e) {
                //       print('catchError handled: ${e.toString()}');
                //
                //       final List<String> empty = [];
                //       return empty;
                //     });
                //   },
                //   tooltip: 'Test (catch error) exception handling async*',
                //   child: const Icon(Icons.error),
                // )
                ],)
            ],
          ),
        )
    );
  }

  // https://github.com/dart-lang/sdk/issues/47985#issuecomment-998987431
  Stream<String> _manageResponse() async* {
    throw Exception("Exception from _manageResponse");
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
      print("Exception try/catch: ${e.toString()}");

      setState(() {
        _failed = e as Exception;
      });
    }

    setState(() {
      _running = false;
    });
  }
}
