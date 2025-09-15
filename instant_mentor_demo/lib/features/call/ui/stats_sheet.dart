import 'dart:async';
import 'package:flutter/material.dart';
import '../controller/call_controller.dart';

class CallStatsSheet extends StatefulWidget {
  final CallController controller;
  const CallStatsSheet({super.key, required this.controller});

  @override
  State<CallStatsSheet> createState() => _CallStatsSheetState();
}

class _CallStatsSheetState extends State<CallStatsSheet> {
  Timer? _timer;
  Map<String, dynamic>? _last;
  DateTime? _lastTime;
  double? _outKbps;
  double? _inKbps;
  final _history = <Map<String, dynamic>>[]; // rolling samples

  @override
  void initState() {
    super.initState();
    _sample();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _sample());
  }

  Future<void> _sample() async {
    final snap = await widget.controller.getStats();
    if (!mounted) return;
    final now = DateTime.now();
    if (_last != null && _lastTime != null && snap.isNotEmpty) {
      final dt = now.difference(_lastTime!).inMilliseconds / 1000.0;
      if (dt > 0) {
        final prevOut = (_last!['outbound_bitrate_bps'] ?? 0).toDouble();
        final prevIn = (_last!['inbound_bitrate_bps'] ?? 0).toDouble();
        final curOut = (snap['outbound_bitrate_bps'] ?? 0).toDouble();
        final curIn = (snap['inbound_bitrate_bps'] ?? 0).toDouble();
        _outKbps = ((curOut - prevOut) / dt) / 1000.0;
        _inKbps = ((curIn - prevIn) / dt) / 1000.0;
      }
    }
    _last = snap.isEmpty ? _last : snap; // keep old if empty
    _lastTime = now;
    if (snap.isNotEmpty) {
      final entry = {
        't': now.toIso8601String(),
        'outKbps': _outKbps,
        'inKbps': _inKbps,
        'loss': snap['loss_pct'],
        'rtt': snap['rtt_ms'],
        'res': snap['resolution'],
      };
      _history.add(entry);
      if (_history.length > 20) _history.removeAt(0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _last;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blueGrey),
                const SizedBox(width: 8),
                const Text('Call Stats',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const Divider(),
            if (snap == null)
              const Text('Collecting stats...',
                  style: TextStyle(fontStyle: FontStyle.italic))
            else ...[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _chip('Outbound', _fmtKbps(_outKbps)),
                  _chip('Inbound', _fmtKbps(_inKbps)),
                  _chip('Loss %', _fmtPct(snap['loss_pct'])),
                  _chip('RTT ms', _fmtNum(snap['rtt_ms'])),
                  _chip('Frames Sent', _fmtNum(snap['frames_sent'])),
                  _chip('Frames Recv', _fmtNum(snap['frames_recv'])),
                  if (snap['resolution'] != null)
                    _chip('Resolution', snap['resolution'].toString()),
                ],
              ),
              const SizedBox(height: 12),
              Text('Recent (last ${_history.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                child: ListView(
                  children: _history.reversed
                      .map((h) => Text(
                            '${h['t'].toString().substring(11, 19)}  out:${_fmtKbps(h['outKbps'])}  in:${_fmtKbps(h['inKbps'])}  loss:${_fmtPct(h['loss'])}  rtt:${_fmtNum(h['rtt'])}  res:${h['res'] ?? '-'}',
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
                'Bitrate values are approximate deltas over 2s intervals.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.blueGrey.shade800,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }

  String _fmtKbps(dynamic v) {
    if (v == null) return '--';
    final d = (v as num).toDouble();
    if (d.isNaN || d.isInfinite) return '--';
    return d.toStringAsFixed(d >= 100 ? 0 : 1) + ' kbps';
  }

  String _fmtPct(dynamic v) {
    if (v == null) return '--';
    final d = (v as num).toDouble();
    return d.toStringAsFixed(1);
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '--';
    final d = (v as num).toDouble();
    if (d % 1 == 0) return d.toInt().toString();
    return d.toStringAsFixed(1);
  }
}
