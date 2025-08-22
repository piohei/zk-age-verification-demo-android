import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory, getTemporaryDirectory, getApplicationCacheDirectory;
import 'bridge_generated/api.dart';  // Updated import path
import 'bridge_generated/frb_generated.dart';  // Updated import path
import 'dart:ffi';
import 'dart:io';


void main() async {
  await RustLib.init();

  runApp(const MyApp());
}

// Helper function to load the proper library based on platform
DynamicLibrary _loadDylib() {
  final libName = Platform.isAndroid
      ? 'libnative.so'
      : Platform.isIOS
          ? 'libnative.a'
          : Platform.isMacOS
              ? 'libnative.dylib'
              : 'libnative.so';

  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.process();
  }
  return DynamicLibrary.open(libName);
}

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
  bool _isLoadingPrepare = false;
  bool _isLoadingProve = false;

  Future<void> _callRustPrepare() async {
    setState(() {
      _isLoadingPrepare = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final programPath = await _getAssetPath('assets/complete_age_check.json');
      final outputPath = '${directory.path}/prepare-output-noir-proof-scheme.nps';
      final tmpDirPath = await getApplicationCacheDirectory();

      // Call the Rust function
      final result = await prepare(programPath: programPath, outputPath: outputPath, tmpDirPath: tmpDirPath.path);

      setState(() {
        _message = result;
        _isLoadingPrepare = false;
      });
    } catch (e) {
      setState(() {
        _message = "Error: $e";
        _isLoadingPrepare = false;
      });
    }
  }

  Future<void> _callRustProve() async {
    setState(() {
      _isLoadingProve = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final schemePath = '${directory.path}/prepare-output-noir-proof-scheme.nps';
      final inputPath = await _getAssetPath('assets/Prover.toml');
      final proofPath = '${directory.path}/prove-output-noir-proof.np';

      // Call the Rust function
      final result = await prove(schemePath: schemePath, inputPath: inputPath, proofPath: proofPath);

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
              _isLoadingPrepare
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _callRustPrepare,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Prepare',
                        style: TextStyle(fontSize: 18),
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