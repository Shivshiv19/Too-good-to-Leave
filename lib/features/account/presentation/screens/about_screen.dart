import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §4.2 `/account/about`, §5f.10. Licence attributions use Flutter's own
/// `LicensePage` — **generated at build time from the dependency tree**
/// (§5f.10's own requirement), not maintained by hand.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final info = _info;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        title: Text(l10n.accountAbout),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.x4),
          children: [
            Text('Surplus Marketplace', style: context.type.display),
            if (info != null)
              Semantics(
                label: l10n.aboutVersionSemantic(
                  info.version,
                  info.buildNumber,
                ),
                excludeSemantics: true,
                child: Text(
                  'v${info.version} (${info.buildNumber})',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: Space.x4),
            Text(l10n.aboutBody, style: context.type.body),
            const SizedBox(height: Space.x6),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Surplus Marketplace',
                applicationVersion: info?.version,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: Text(l10n.aboutRateApp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.aboutRateAppUnavailable)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
