import 'package:flutter/material.dart';
import '../services/api_client.dart';

const Color _accent = Color(0xFF2E7D32);
const Color _muted = Color(0xFF777777);

/// Loads a list, with spinner, error + retry, empty message and
/// pull-to-refresh. [itemBuilder] gets a reload callback for after edits.
class AsyncList<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final String emptyText;
  final Widget Function(BuildContext context, T item, VoidCallback reload)
  itemBuilder;

  const AsyncList({
    super.key,
    required this.load,
    required this.emptyText,
    required this.itemBuilder,
  });

  @override
  State<AsyncList<T>> createState() => _AsyncListState<T>();
}

class _AsyncListState<T> extends State<AsyncList<T>> {
  late Future<List<T>> _items = widget.load();

  Future<void> _reload() async {
    final Future<List<T>> next = widget.load();
    setState(() {
      _items = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder below.
    }
  }

  Widget _message(IconData icon, String text) {
    // ListView so pull-to-refresh still works on an empty or failed list.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 20),
      children: [
        Icon(icon, size: 34, color: _muted),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(foregroundColor: _accent),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _accent,
      onRefresh: _reload,
      child: FutureBuilder<List<T>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }
          if (snapshot.hasError) {
            final Object error = snapshot.error!;
            return _message(
              Icons.cloud_off_outlined,
              error is ApiException ? error.message : 'Could not load',
            );
          }
          final List<T> items = snapshot.data!;
          if (items.isEmpty) {
            return _message(Icons.inbox_outlined, widget.emptyText);
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                widget.itemBuilder(context, items[index], _reload),
          );
        },
      ),
    );
  }
}
