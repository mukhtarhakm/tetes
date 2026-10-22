import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.label,
    required this.icon,
    this.iconWidget,
    this.isAction = false,
  });

  final String label;
  final IconData icon;
  final Widget? iconWidget;
  final bool isAction;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  }) : assert(items.length > 1),
       assert(currentIndex >= 0 && currentIndex < items.length);

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppInsets.bottomNavigation,
          child: SizedBox(
            height: AppSizes.bottomNavigationHeight,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (items[index].isAction)
                    const VerticalDivider(
                      width: AppSpacing.s8,
                      color: AppColors.divider,
                    ),
                  Expanded(
                    child: _NavigationItem(
                      item: items[index],
                      isSelected:
                          index == currentIndex && !items[index].isAction,
                      onTap: () => onTap(index),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected ? AppColors.ink : AppColors.inkSoft;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.navigation),
        child: Center(
          child: AnimatedContainer(
            duration: AppDurations.feedback,
            curve: Curves.easeOut,
            constraints: const BoxConstraints(
              minWidth: AppSizes.minimumTouchTarget,
              minHeight: AppSizes.minimumTouchTarget,
            ),
            padding: AppInsets.bottomNavigationItem,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.navigation),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: AppSizes.navigationAvatar,
                  child: Center(
                    child: item.iconWidget != null
                        ? Container(
                            decoration: isSelected
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: AppSizes.progressStroke,
                                    ),
                                  )
                                : null,
                            child: item.iconWidget,
                          )
                        : Icon(
                            item.icon,
                            size: AppSizes.navigationIcon,
                            color: foregroundColor,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: foregroundColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
