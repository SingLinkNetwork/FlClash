import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

class TestUrlSelector extends StatelessWidget {
  final List<String> urls;
  final String? selectedUrl;
  final ValueChanged<String?> onChanged;

  const TestUrlSelector({
    super.key,
    required this.urls,
    required this.selectedUrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.length < 2) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final url in urls) ...[
              Tooltip(
                message: url,
                child: ChoiceChip(
                  label: Text(testUrlLabel(url)),
                  selected: url == selectedUrl,
                  onSelected: (_) => onChanged(url),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
