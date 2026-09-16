import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/device_info.dart';
import '../theme/app_theme.dart';

/// Barre de navigation inférieure signature Dios Délices
/// Style flottant, fond chaud, indicateur de sélection animé
class DiosNavBar extends StatefulWidget {
  const DiosNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.prominentIndex,
  });

  final List<DiosNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? prominentIndex;

  @override
  State<DiosNavBar> createState() => _DiosNavBarState();
}

class _DiosNavBarState extends State<DiosNavBar>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('app.navbar/navigate');
  static final List<_DiosNavBarState> _activeStates = [];
  static bool _handlerInitialized = false;

  late AnimationController _indicatorController;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _indicatorController = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _indicatorController.value = 1.0;

    if (DeviceInfo.instance.useNativeIOSNavBar) {
      _activeStates.add(this);
      _initNativeHandler();
    }
  }

  static void _initNativeHandler() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      if (_activeStates.isEmpty) return;
      final activeState = _activeStates.last;
      if (!activeState.mounted || call.method != 'selectIndex') return;

      final index = call.arguments as int?;
      if (index != null && index >= 0 && index < activeState.widget.items.length) {
        activeState.widget.onTap(index);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DiosNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _indicatorController
        ..reset()
        ..forward();
    }
    if (DeviceInfo.instance.useNativeIOSNavBar &&
        oldWidget.currentIndex != widget.currentIndex) {
      _channel.invokeMethod('updateIndex', widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    _activeStates.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (DeviceInfo.instance.useNativeIOSNavBar) {
      return _buildLiquidGlass(context);
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasProminent = widget.prominentIndex != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floatingList,
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.items.length, (index) {
            final isSelected = widget.currentIndex == index;
            final isProminent = hasProminent && widget.prominentIndex == index;

            if (isProminent) {
              return _ProminentButton(
                item: widget.items[index],
                onTap: () => widget.onTap(index),
              );
            }

            return _NavBarItem(
              item: widget.items[index],
              isSelected: isSelected,
              animation: _indicatorController,
              isPrevious: index == _previousIndex,
              onTap: () => widget.onTap(index),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLiquidGlass(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 72 + bottomPadding + 12,
      child: UiKitView(
        viewType: 'liquid_glass_navbar',
        layoutDirection: TextDirection.ltr,
        creationParams: {
          'currentIndex': widget.currentIndex,
          'items': widget.items
              .asMap()
              .entries
              .map(
                (entry) => {
                  'index': entry.key,
                  'icon': entry.value.iosSystemName ?? 'circle.fill',
                  'label': entry.value.label,
                },
              )
              .toList(),
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.animation,
    required this.isPrevious,
    required this.onTap,
  });

  final DiosNavItem item;
  final bool isSelected;
  final Animation<double> animation;
  final bool isPrevious;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = isSelected
                ? 0.9 + (0.1 * animation.value)
                : 1.0 - (0.05 * (isPrevious ? (1 - animation.value) : 0));
            final yOffset = isSelected ? (1 - animation.value) * -3 : 0.0;

            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicateur animé
                    AnimatedContainer(
                      duration: AppMotion.fast,
                      width: isSelected ? 32 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Icône
                    IconTheme(
                      data: IconThemeData(
                        color: isSelected ? AppColors.brand : AppColors.inkMuted,
                        size: 24,
                      ),
                      child: isSelected ? item.activeIcon : item.icon,
                    ),
                    const SizedBox(height: 2),
                    // Label
                    AnimatedDefaultTextStyle(
                      duration: AppMotion.fast,
                      style: AppTypography.labelMedium(
                        color: isSelected ? AppColors.brand : AppColors.inkMuted,
                      ).copyWith(fontSize: 10),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProminentButton extends StatelessWidget {
  const _ProminentButton({
    required this.item,
    required this.onTap,
  });

  final DiosNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white, size: 26),
          child: item.activeIcon,
        ),
      ),
    );
  }
}

/// Modèle d'item de navigation
class DiosNavItem {
  const DiosNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.iosSystemName,
  });

  final Widget icon;
  final Widget activeIcon;
  final String label;
  final String? iosSystemName;
}
