import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/responsive.dart';

/// Ana kabuğun bir sekmesi: alt çubukta ve yan rayda aynı ikon ve etiket.
@immutable
class ShellDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const ShellDestination({required this.icon, required this.selectedIcon, required this.label});
}

/// Ana kabuğun iskeleti: dikey telefonda alt gezinme çubuğu, tablette ve
/// yatay telefonda (dikey alan kıtken) solda NavigationRail ve içerik sağda.
///
/// [body] her düzende aynı ağaç konumunda kalır; telefon döndürülünce ya da
/// gezinme gizlenince sekmelerin durumu (ör. süren sayaç) kaybolmaz.
class ShellNavigationScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  /// false iken (ör. yatayda sayaç çalışırken odak modu) hiçbir gezinme
  /// gösterilmez.
  final bool showNavigation;

  const ShellNavigationScaffold({
    super.key,
    this.appBar,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.showNavigation = true,
  });

  void _select(int index) {
    if (index == selectedIndex) return;
    onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final useRail = showNavigation && Responsive.of(context).useSideNavigation;
    final useBar = showNavigation && !useRail;

    return Scaffold(
      backgroundColor: background,
      appBar: appBar,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (useRail) ...[
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _select,
              backgroundColor: background,
              indicatorColor: AppColors.primaryFixed,
              labelType: NavigationRailLabelType.all,
              // Yatay telefonda dört sekme sığmazsa ray kendi içinde kayar.
              scrollable: true,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon, color: AppColors.onPrimaryFixed),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            ),
          ],
          // Ray sol güvenli alanı (çentik) kendisi karşılar; içerik ikinci
          // kez boşluk bırakmasın. Builder: Scaffold'un gövdeye verdiği
          // MediaQuery'den (üst çubuk ve alt çubuk varken üst/alt güvenli
          // alan düşülmüş) türetilir. Dış context kullanılınca düşülen
          // dolgu geri geliyor, sekmelerin SafeArea'sı iPhone'da üstte ve
          // altta ikinci kez boşluk bırakıyordu (sayaçta BAŞLAT aşağı kayıyordu).
          Expanded(
            child: Builder(
              builder: (context) => MediaQuery.removePadding(
                context: context,
                removeLeft: useRail,
                child: body,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: useBar
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: _select,
              backgroundColor: background,
              indicatorColor: AppColors.primaryFixed,
              elevation: 4,
              height: 68,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon, color: AppColors.onPrimaryFixed),
                    label: d.label,
                  ),
              ],
            )
          : null,
    );
  }
}
