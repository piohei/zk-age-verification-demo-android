import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory, getTemporaryDirectory, getApplicationCacheDirectory;
import 'package:app/src/rust/api.dart';  // Updated import path
import 'package:app/src/rust/frb_generated.dart';  // Updated import path
import 'dart:ffi';
import 'dart:io';

void main() async {
  // Initialize the bridge
  // final dylib = _loadDylib();

  await RustLib.init();

  runApp(const MyApp());
}

// Helper function to load the proper library based on platform
// DynamicLibrary _loadDylib() {
//   if (Platform.isAndroid) {
//     return DynamicLibrary.open('librust_lib_app.so');
//   } else if (Platform.isIOS) {
//     // On iOS, the library is statically linked, so we use process() instead of open()
//     return DynamicLibrary.process();
//   } else if (Platform.isMacOS) {
//     return DynamicLibrary.process();
//   } else if (Platform.isWindows) {
//     return DynamicLibrary.open('native.dll');
//   } else if (Platform.isLinux) {
//     return DynamicLibrary.open('librust_lib_app.so');
//   }
  
//   throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Rust Bridge Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Rust Bridge Demo'),
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
  String _message = "R1CS Android Runner";
  bool _isLoadingProve = false;

  Future<void> _callRustProve() async {
    setState(() {
      _isLoadingProve = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final schemePath = await _getAssetPath('assets/noir-proof-scheme.nps');
      final inputPath = await _getAssetPath('assets/Prover.toml');
      final proofPath = '${directory.path}/noir-proof.np';
      final tmpDirPath = await getApplicationCacheDirectory();

      // Call the Rust function
      final result = await prove(schemePath: schemePath, inputPath: inputPath, proofPath: proofPath, tmpDirPath: tmpDirPath.path);

      setState(() {
        _message = result;
        _isLoadingProve = false;
      });
    } catch (e) {
      setState(() {
        _message = "Error: $e";
        _isLoadingProve = false;
      });
    }
  }


  // Helper function to get an asset as a file with a real path
  Future<String> _getAssetPath(String assetPath) async {
    // Get temporary directory
    final directory = await getTemporaryDirectory();

    // Extract filename from asset path
    final filename = assetPath.split('/').last;
    final filePath = '${directory.path}/$filename';

    // Load asset
    final byteData = await rootBundle.load(assetPath);

    // Write to file
    final file = File(filePath);
    await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        )
    );

    return filePath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _message,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              _isLoadingProve
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _callRustProve,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Prove',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}