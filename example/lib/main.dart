// Example app for the Puente Railway SDK.
//
// Runs against `PuenteEnvironment.mock` by default so it works
// offline on first `flutter run`. Switch to `PuenteConfig.testnet`
// when you have an `sk_testnet_…` API key and the Puente backend
// at `https://api-testnet.puenterailway.com/v1` is reachable.

import 'package:flutter/material.dart';
import 'package:puente_railway/puente_railway.dart';

void main() {
  runApp(const PuenteExampleApp());
}

class PuenteExampleApp extends StatelessWidget {
  const PuenteExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puente Railway Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00D632)),
        useMaterial3: true,
      ),
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
  late final PuenteClient _puente;
  final _amountController = TextEditingController(text: '100.00');
  final _clabeController = TextEditingController(text: '012180012345678901');
  final _nameController = TextEditingController(text: 'María García López');

  Quote? _quote;
  Transfer? _transfer;
  String? _watchStatus;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Swap for `PuenteClient(config: PuenteConfig.testnet(apiKey: '…'))`
    // when you're ready to hit the real testnet backend.
    _puente = PuenteClient.mock(
      settlementLatency: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _puente.close();
    _amountController.dispose();
    _clabeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendRemittance() async {
    setState(() {
      _busy = true;
      _error = null;
      _quote = null;
      _transfer = null;
      _watchStatus = null;
    });
    try {
      final amount = Money.fromDecimal(_amountController.text, Currency.usd);
      final result = await _puente.remittance.send(
        sourceAmount: amount,
        targetCurrency: Currency.mxn,
        receiverClabe: _clabeController.text.trim(),
        receiverName: _nameController.text.trim(),
        memo: 'Sent from Pesito demo',
      );
      setState(() {
        _quote = result.quote;
        _transfer = result.transfer;
        _watchStatus = result.transfer.status.wire;
      });

      // Stream lifecycle updates until terminal.
      await for (final t in _puente.transfers.watch(
        result.transfer.id,
        pollInterval: const Duration(milliseconds: 500),
      )) {
        if (!mounted) break;
        setState(() {
          _transfer = t;
          _watchStatus = t.status.wire;
        });
        if (t.status.isTerminal) break;
      }
    } on PuenteException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puente Railway Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'USD amount',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clabeController,
              decoration: const InputDecoration(
                labelText: 'Recipient CLABE (18 digits)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipient name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _sendRemittance,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send remittance'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!),
                ),
              ),
            if (_quote != null) ...[
              const SizedBox(height: 8),
              _Tile(
                title: 'Quote',
                lines: [
                  'Send: ${_quote!.sourceAmount.format()}',
                  'Recipient gets: ${_quote!.targetAmount.format()}',
                  'Rate: ${_quote!.exchangeRate.toStringAsFixed(4)}',
                  'Fee: ${_quote!.fee.format()}',
                ],
              ),
            ],
            if (_transfer != null) ...[
              const SizedBox(height: 8),
              _Tile(
                title: 'Transfer ${_transfer!.id}',
                lines: [
                  'Status: ${_watchStatus ?? _transfer!.status.wire}',
                  if (_transfer!.reference != null)
                    'Reference: ${_transfer!.reference}',
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
          ],
        ),
      ),
    );
  }
}
