import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../journal/widgets/journal_sheet.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/integrations_providers.dart';

/// Keys for Steam achievements and IsThereAnyDeal prices, kept on the device
/// like every other API key in the app.
Future<void> showConnectionsSheet(BuildContext context) {
  final S l = S.of(context);
  return showJournalSheet<void>(
    context,
    title: l.connectionsTitle,
    builder: (BuildContext _) => const _ConnectionsForm(),
  );
}

class _ConnectionsForm extends ConsumerStatefulWidget {
  const _ConnectionsForm();

  @override
  ConsumerState<_ConnectionsForm> createState() => _ConnectionsFormState();
}

class _ConnectionsFormState extends ConsumerState<_ConnectionsForm> {
  static final Uri _steamKeyPage = Uri.parse(
    'https://steamcommunity.com/dev/apikey',
  );
  static final Uri _itadKeyPage = Uri.parse(
    'https://isthereanydeal.com/apps/my/',
  );

  late final SharedPreferences _prefs = ref.read(sharedPreferencesProvider);
  late final TextEditingController _steamKey = TextEditingController(
    text: _prefs.getString(SettingsKeys.steamApiKey) ?? '',
  );
  late final TextEditingController _steamId = TextEditingController(
    text: _prefs.getString(SettingsKeys.steamId) ?? '',
  );
  late final TextEditingController _itadKey = TextEditingController(
    text: _prefs.getString(kItadKeyPref) ?? '',
  );
  late final TextEditingController _country = TextEditingController(
    text: itadCountry(_prefs),
  );

  @override
  void dispose() {
    _steamKey.dispose();
    _steamId.dispose();
    _itadKey.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _put(String key, String value) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, trimmed);
    }
  }

  Future<void> _save() async {
    await _put(SettingsKeys.steamApiKey, _steamKey.text);
    await _put(SettingsKeys.steamId, _steamId.text);
    if (_steamKey.text.trim().isNotEmpty && _steamId.text.trim().isNotEmpty) {
      await _prefs.setBool(SettingsKeys.steamRememberCredentials, true);
    }
    await _put(kItadKeyPref, _itadKey.text);
    await _put(kItadCountryPref, _country.text.toUpperCase());
    ref.read(credentialsRevisionProvider.notifier).state++;
    if (mounted) Navigator.of(context).pop();
  }

  Widget _link(String label, Uri uri) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l.connectionsSteam, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(l.connectionsSteamHint, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _steamKey,
          decoration: InputDecoration(labelText: l.connectionsSteamKey),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _steamId,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.connectionsSteamId),
        ),
        _link(l.connectionsGetKey, _steamKeyPage),
        const SizedBox(height: AppSpacing.md),
        Text(l.connectionsItad, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(l.connectionsItadHint, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _itadKey,
          decoration: InputDecoration(labelText: l.connectionsItadKey),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _country,
          maxLength: 2,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l.connectionsCountry),
        ),
        _link(l.connectionsGetKey, _itadKeyPage),
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: l.save,
          cancelLabel: l.cancel,
          onSave: _save,
        ),
      ],
    );
  }
}
