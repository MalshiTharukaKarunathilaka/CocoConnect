import 'package:flutter/material.dart';
import 'fertilizer_chrome.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';
import 'fertilizer_order_edit_sheet.dart';

/// My orders: private supplier orders and government requests, newest first.
class FertilizerRequestsPage extends StatefulWidget {
  const FertilizerRequestsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<FertilizerRequestsPage> createState() => _FertilizerRequestsPageState();
}

class _FertilizerRequestsPageState extends State<FertilizerRequestsPage> {
  final _store = FertilizerStore.instance;

  Future<void> _viewPrivate(FertOrder o) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final kg = o.items.fold<int>(0, (a, l) => a + l.qty50 * 50);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFCF8EF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order ${o.id}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                      StatusPill.forStatus(o.status),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    o.company,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  for (final l in o.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l.item.name}\n${l.qty50} × 50 kg · ${rupees(l.item.perKg)}/kg',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          Text(
                            rupees(l.lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Text(
                    'Total ${rupees(o.price)} · $kg kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Date ${shortDate(o.preferredDate)} · ${o.slot}'),
                  if (o.message.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(o.message, style: const TextStyle(color: AppColors.muted)),
                  ],
                  const SizedBox(height: 14),
                  if (o.status == 'Pending Ack' || o.status == 'Negotiating')
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _editPrivate(o);
                      },
                      child: const Text('Edit order'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editPrivate(FertOrder o) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FertilizerOrderEditSheet(order: o),
    );
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final private = _store.ownerOrders('Your Estate');
    final gov = _store.govRequests
        .where((r) => r.owner == 'Your Estate')
        .toList();
    final waiting = private.where((o) => o.status == 'Pending Ack').length +
        gov.where((r) => r.status == 'Pending Ack').length;
    final accepted = private.where((o) => o.status == 'Accepted').length;
    final spend = private.fold<int>(0, (s, o) => s + o.price);

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _summary(private.length + gov.length, waiting, accepted, spend),
        const SizedBox(height: 20),
        _section(
          Icons.storefront_outlined,
          'Private suppliers',
          private.length,
          AppColors.green,
        ),
        const SizedBox(height: 10),
        if (private.isEmpty)
          _empty('No private orders yet')
        else
          for (final o in private) _privateCard(o),
        const SizedBox(height: 14),
        _section(
          Icons.account_balance_outlined,
          'Government',
          gov.length,
          const Color(0xFF1F5E8C),
        ),
        const SizedBox(height: 10),
        if (gov.isEmpty)
          _empty('No government requests yet')
        else
          for (final r in gov) _govCard(r),
      ],
    );

    if (widget.embedded) return ColoredBox(color: AppColors.cream, child: body);
    return FertPage(
      title: 'My orders',
      subtitle: 'FERTILIZER · LAND OWNER',
      child: body,
    );
  }

  Widget _summary(int total, int waiting, int accepted, int spend) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5),
              ),
            ],
          ),
        );
    Widget bar() =>
        Container(width: 1, height: 30, color: const Color(0x33FFFFFF));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D4F), Color(0xFF1B5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331B5E3A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          stat('$total', 'Orders'),
          bar(),
          stat('$waiting', 'Waiting'),
          bar(),
          stat('$accepted', 'Accepted'),
          bar(),
          stat(
            spend >= 1000 ? '${(spend / 1000).round()}k' : '$spend',
            'Rs. spent',
          ),
        ],
      ),
    );
  }

  Widget _section(IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F3),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.muted),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      );

  Widget _doc(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 13, color: AppColors.green),
            const SizedBox(width: 4),
            Text(
              t,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      );

  Widget _empty(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.callout),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      );

  Widget _badge(IconData icon, Color color) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 22),
      );

  BoxDecoration _cardBox() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );

  Widget _privateCard(FertOrder o) {
    final canEdit =
        o.status == 'Pending Ack' || o.status == 'Negotiating';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardBox(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: _accent(o.status)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _badge(Icons.inventory_2_outlined, AppColors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.product,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  o.company,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(
                            Icons.shopping_bag_outlined,
                            '${o.qty50} bag${o.qty50 == 1 ? '' : 's'}',
                          ),
                          _chip(
                            Icons.event_outlined,
                            shortDate(o.preferredDate),
                          ),
                          _chip(Icons.schedule, o.slot),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: AppColors.line),
                      ),
                      if (o.status == 'Cancelled' ||
                          o.status == 'Negotiating') ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: o.status == 'Cancelled'
                                ? AppColors.dangerSoft
                                : AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            o.message.trim().isEmpty
                                ? o.status
                                : o.message,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: o.status == 'Cancelled'
                                  ? AppColors.dangerText
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Text(
                            rupees(o.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: AppColors.green,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _viewPrivate(o),
                            child: const Text('View'),
                          ),
                          if (canEdit)
                            TextButton(
                              onPressed: () => _editPrivate(o),
                              child: const Text('Edit'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accent(String status) {
    switch (status) {
      case 'Accepted':
        return AppColors.green;
      case 'Pending Ack':
        return AppColors.warning;
      default:
        return AppColors.muted;
    }
  }

  Widget _govCard(FertGovRequest r) {
    const blue = Color(0xFF1F5E8C);
    final step = r.status == 'Pending Ack' ? 1 : (r.distributed > 0 ? 3 : 2);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardBox(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: blue),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _badge(Icons.account_balance_outlined, blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.fertilizer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${r.id} · ${r.cdo}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusPill.forStatus(r.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(
                            Icons.shopping_bag_outlined,
                            '${r.requested} bag${r.requested == 1 ? '' : 's'}',
                          ),
                          if (r.estateName.isNotEmpty)
                            _chip(Icons.park_outlined, r.estateName),
                          if (r.acres > 0)
                            _chip(
                              Icons.crop_square,
                              '${r.acres % 1 == 0 ? r.acres.toInt() : r.acres} acres',
                            ),
                          _chip(Icons.place_outlined, r.district),
                        ],
                      ),
                      if (r.nicCopy.isNotEmpty ||
                          r.landTitleCopy.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (r.nicCopy.isNotEmpty) _doc('NIC copy'),
                            if (r.landTitleCopy.isNotEmpty)
                              _doc('Land title copy'),
                          ],
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: AppColors.line),
                      ),
                      _steps(step),
                      if (r.status == 'Pending Ack') ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.hourglass_top,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Waiting for ${r.cdo} approval',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _steps(int step) {
    const labels = ['Sent', 'CDO approval', 'Distributed'];
    final done = step;
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < done
                      ? AppColors.green
                      : (i == done
                          ? AppColors.warning.withValues(alpha: 0.18)
                          : const Color(0xFFEDEFEB)),
                  border: i == done
                      ? Border.all(color: AppColors.warning, width: 1.6)
                      : null,
                ),
                child: i < done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: i <= done ? FontWeight.w700 : FontWeight.w500,
                  color: i <= done ? Colors.black87 : AppColors.muted,
                ),
              ),
            ],
          ),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
                color: i < done ? AppColors.green : const Color(0xFFEDEFEB),
              ),
            ),
        ],
      ],
    );
  }
}
