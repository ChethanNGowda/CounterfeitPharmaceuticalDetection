import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme.dart';

/// Collapsible section card used in ResultsScreen.
class ExpandableCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget content;
  final bool initiallyExpanded;
  final Widget? trailingBadge;

  const ExpandableCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.content,
    this.initiallyExpanded = false,
    this.trailingBadge,
  });

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(widget.icon, color: AppTheme.primaryTeal, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailingBadge != null) ...[
                    widget.trailingBadge!,
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: AppTheme.border),
            Padding(padding: const EdgeInsets.all(14), child: widget.content),
          ],
        ],
      ),
    );
  }
}
