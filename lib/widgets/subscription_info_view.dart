import 'package:flclashx/common/common.dart';
import 'package:flclashx/models/models.dart';
import 'package:flutter/material.dart';

class SubscriptionInfoView extends StatelessWidget {
  const SubscriptionInfoView({
    super.key,
    this.subscriptionInfo,
  });
  final SubscriptionInfo? subscriptionInfo;

  @override
  Widget build(BuildContext context) {
    final info = subscriptionInfo ?? const SubscriptionInfo();
    final use = info.upload + info.download;
    final total = info.total;
    final hasTrafficLimit = total > 0;
    final progress = hasTrafficLimit ? (use / total).clamp(0.0, 1.0) : 0.0;

    final trafficShow = hasTrafficLimit
        ? "${TrafficValue(value: use).show} / ${TrafficValue(value: total).show}"
        : appLocalizations.trafficUnlimited;
    final expireShow = info.expire != 0
        ? DateTime.fromMillisecondsSinceEpoch(info.expire * 1000).show
        : appLocalizations.infiniteTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTrafficLimit) ...[
          LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: context.colorScheme.primary.opacity15,
          ),
          const SizedBox(
            height: 8,
          ),
        ],
        Text(
          "$trafficShow · $expireShow",
          style: context.textTheme.labelMedium?.toLight,
        ),
        const SizedBox(
          height: 4,
        ),
      ],
    );
  }
}
