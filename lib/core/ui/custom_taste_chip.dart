import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class CustomTasteChip extends StatelessWidget {
  const CustomTasteChip({required this.label, this.onRemove, super.key});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: AppSizes.chipHeight,
      padding: const EdgeInsets.only(left: AppSpacing.s14, right: AppSpacing.s10),
      decoration: BoxDecoration(
        color: AppColors.stage3Soft,
        border: Border.all(color: AppColors.stage3, width: AppSizes.customTagBorder),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.ink, fontWeight: FontWeight.w600)),
        if (onRemove != null) ...[
          const SizedBox(width: AppSpacing.s6),
          const Icon(Icons.close_rounded, size: AppSizes.customTagIcon, color: AppColors.ink),
        ],
      ]),
    );
    if (onRemove == null) return chip;
    return Semantics(
      button: true,
      label: 'Hapus rasa $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onRemove,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
            child: ExcludeSemantics(child: chip),
          ),
        ),
      ),
    );
  }
}

class AddCustomTasteChip extends StatelessWidget {
  const AddCustomTasteChip({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Tambah rasa lain',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
          child: CustomPaint(
            painter: _DashedPillPainter(),
            child: SizedBox(
              height: AppSizes.chipHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, size: AppSizes.customTagIcon, color: AppColors.ink),
                  const SizedBox(width: AppSpacing.s6),
                  Text('Rasa lain', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
          ),
      ),
    ),
  );
}

class _DashedPillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(
      Offset.zero & size, const Radius.circular(AppRadius.pill)));
    final paint = Paint()
      ..color = AppColors.inkSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.customTagDashBorder;
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += AppSpacing.s8) {
        canvas.drawPath(metric.extractPath(start, start + AppSpacing.s4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
