import 'package:flutter/material.dart';
import 'package:puente_railway/puente_railway.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puente Railway Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _client = PuenteClient(
    apiKey: 'sk_sandbox_demo',
    environment: PuenteEnvironment.sandbox,
  );
  
  final _amountController = TextEditingController(text: '100.00');
  bool _isLoading = false;
  Quote? _quote;

  Future<void> _getQuote() async {
    setState(() {
      _isLoading = true;
      _quote = null;
    });

    try {
      final amountDouble = double.tryParse(_amountController.text) ?? 0.0;
      final cents = (amountDouble * 100).round();

      final quote = await _client.quotes.create(
        sourceAmount: Money(cents: cents, currency: 'USD'),
        sourceCurrency: 'USD',
        targetCurrency: 'MXN',
      );
      
      setState(() {
        _quote = quote;
      });
    } on PuenteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puente API Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'USD Amount',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _getQuote,
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text('Get Quote'),
            ),
            const SizedBox(height: 32),
            if (_quote != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You send: ${_quote!.sourceAmount.format()}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('They receive: ${_quote!.targetAmount.format()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Exchange Rate: ${_quote!.exchangeRate}'),
                      Text('Fee: ${_quote!.fee.format()}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
