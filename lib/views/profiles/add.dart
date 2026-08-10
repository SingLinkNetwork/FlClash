import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AddProfileView extends StatelessWidget {
  final BuildContext context;

  const AddProfileView({super.key, required this.context});

  Future<void> _handleAddProfileFormFile() async {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(URLImportResult result) async {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormURL(result.url, useProxy: result.useProxy);
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      globalState.container
          .read(profilesActionProvider.notifier)
          .addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(URLImportResult(url: url));
      });
    }
  }

  Future<void> _toAdd() async {
    final appLocalizations = context.appLocalizations;
    final result = await globalState.showCommonDialog<URLImportResult>(
      child: const URLFormDialog(),
    );
    if (result != null) {
      _handleAddProfileFormURL(result);
    }
  }

  @override
  Widget build(context) {
    final appLocalizations = context.appLocalizations;
    return ListView(
      children: [
        ListItem(
          leading: const Icon(Icons.qr_code_sharp),
          title: Text(appLocalizations.qrcode),
          subtitle: Text(appLocalizations.qrcodeDesc),
          onTap: _toScan,
        ),
        ListItem(
          leading: const Icon(Icons.upload_file_sharp),
          title: Text(appLocalizations.file),
          subtitle: Text(appLocalizations.fileDesc),
          onTap: _handleAddProfileFormFile,
        ),
        ListItem(
          leading: const Icon(Icons.cloud_download_sharp),
          title: Text(appLocalizations.url),
          subtitle: Text(appLocalizations.urlDesc),
          onTap: _toAdd,
        ),
      ],
    );
  }
}

class URLImportResult {
  final String url;
  final bool useProxy;

  const URLImportResult({required this.url, this.useProxy = true});
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  var _useProxy = true;

  Future<void> _handleAddProfileFormURL() async {
    if (_formKey.currentState?.validate() == false) return;
    Navigator.of(context).pop(
      URLImportResult(url: _urlController.value.text, useProxy: _useProxy),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.importFromURL,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _handleAddProfileFormURL,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: SizedBox(
        width: 300,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                keyboardType: TextInputType.url,
                minLines: 1,
                maxLines: 5,
                inputFormatters: TextInputLimits.limit(TextInputLimits.url),
                onSubmitted: (_) {
                  _handleAddProfileFormURL();
                },
                onEditingComplete: _handleAddProfileFormURL,
                controller: _urlController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: appLocalizations.url,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return appLocalizations.emptyTip('').trim();
                  }
                  if (!value.isUrl) {
                    return appLocalizations.urlTip('').trim();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              RadioGroup<bool>(
                groupValue: _useProxy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _useProxy = value);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: true,
                      title: Text(appLocalizations.syncViaProxy),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      title: Text(appLocalizations.syncDirect),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
