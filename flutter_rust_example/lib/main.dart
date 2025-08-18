import 'package:flutter/material.dart';
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
  String _message = "Press the button to call Rust code";
  bool _isLoading = false;

  Future<void> _callRustCode() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Call the Rust function
      final result = await helloWorld();
      
      setState(() {
        _message = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = "Error: $e";
        _isLoading = false;
      });
    }
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
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _callRustCode,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Call Rust Function',
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