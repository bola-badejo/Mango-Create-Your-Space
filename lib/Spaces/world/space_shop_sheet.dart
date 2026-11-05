// The Space shop: skins, icons and objects for MangoCoin. Prices and
// ownership are enforced on the server; payment and the item commit in one
// transaction, so you are never charged without receiving the item.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

import 'space_catalog.dart';
import 'space_world_service.dart';

class SpaceShopSheet extends StatefulWidget {
  const SpaceShopSheet({super.key, required this.svc, required this.catalog, required this.theme});

  final SpaceWorldService svc;
  final SpaceCatalog catalog;
  final Map<String, dynamic> theme;

  @override
  State<SpaceShopSheet> createState() => _SpaceShopSheetState();
}

class _SpaceShopSheetState extends State<SpaceShopSheet> {
  String? _balance;
  late Map<String, dynamic> _theme = Map<String, dynamic>.from(widget.theme);

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      if (!Get.isRegistered<WalletService>()) return;
      final data = await Get.find<WalletService>().getUserBalance();
      if (mounted) setState(() => _balance = data.balance.toFixed(2));
    } catch (_) {
      if (mounted) setState(() => _balance = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MangoSpace.s4, MangoSpace.s4, MangoSpace.s4, 0),
            child: Row(children: [
              Expanded(child: Text('Space shop', style: context.type.titleLarge)),
              Semantics(
                label: _balance == null ? 'Balance unavailable' : 'Your balance: $_balance MangoCoin',
                child: ExcludeSemantics(
                  child: Chip(avatar: const Text('🥭'), label: Text(_balance == null ? '—' : '$_balance MNG')),
                ),
              ),
            ]),
          ),
          const TabBar(tabs: [Tab(text: 'Skins'), Tab(text: 'Icons'), Tab(text: 'Objects')]),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: widget.svc.inventory(),
              builder: (context, snap) {
                final owned = snap.data ?? const <String>{};
                return TabBarView(children: [
                  for (final kind in SpaceItemKind.values) _grid(context, kind, owned),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _grid(BuildContext context, SpaceItemKind kind, Set<String> owned) {
    final items = widget.catalog.ofKind(kind).toList()
      ..sort((a, b) => double.parse(a.price).compareTo(double.parse(b.price)));
    return GridView.builder(
      padding: const EdgeInsets.all(MangoSpace.s4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisExtent: 210, crossAxisSpacing: MangoSpace.s3, mainAxisSpacing: MangoSpace.s3),
      itemCount: items.length,
      itemBuilder: (context, i) => _ItemCard(
        item: items[i],
        owned: owned.contains(items[i].id) || items[i].isFree,
        applied: _theme['skinId'] == items[i].id || _theme['iconId'] == items[i].id,
        onBuy: () async {
          await widget.svc.buy(items[i].id);
          await _loadBalance();
          if (context.mounted) MangoToast.show(context, message: '${items[i].name} is yours', kind: MangoToastKind.success);
        },
        onApply: kind == SpaceItemKind.object
            ? null
            : () async {
                final r = await widget.svc.applyTheme(
                  skinId: kind == SpaceItemKind.skin ? items[i].id : null,
                  iconId: kind == SpaceItemKind.icon ? items[i].id : null,
                );
                if (mounted) setState(() => _theme = Map<String, dynamic>.from((r['theme'] as Map?) ?? _theme));
              },
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.owned, required this.applied, required this.onBuy, this.onApply});

  final SpaceItem item;
  final bool owned;
  final bool applied;
  final Future<void> Function() onBuy;
  final Future<void> Function()? onApply;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    void showError(Object e) => MangoToast.show(context, message: e.toString(), kind: MangoToastKind.error);
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: applied ? c.actionPrimary : c.borderSubtle, width: applied ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 88,
          child: item.kind == SpaceItemKind.skin
              ? SpaceSkinBackground(skin: item)
              : Center(child: SpaceGlyph(item: item, size: 44)),
        ),
        Padding(
          padding: const EdgeInsets.all(MangoSpace.s2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.titleSmall),
            Text(item.isFree ? 'Free' : '${item.price} MNG · ${item.rarity}', style: context.type.bodySmall?.copyWith(color: c.textSecondary)),
          ]),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(MangoSpace.s2, 0, MangoSpace.s2, MangoSpace.s2),
          child: !owned
              ? MangoButton(label: 'Buy for ${item.price}', size: MangoButtonSize.medium, expand: true, showSuccess: true, successLabel: 'Bought', onPressed: onBuy, onError: showError)
              : onApply == null
                  ? Center(child: Text('Owned', style: context.type.labelLarge?.copyWith(color: c.textBrand)))
                  : MangoButton(
                      label: applied ? 'In use' : 'Use',
                      size: MangoButtonSize.medium,
                      expand: true,
                      variant: MangoButtonVariant.secondary,
                      onPressed: applied ? null : onApply,
                      onError: showError,
                    ),
        ),
      ]),
    );
  }
}
