import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

class ChangeNickName extends StatefulWidget {
  const ChangeNickName({super.key});

  @override
  State<ChangeNickName> createState() => _ChangeNickNameState();
}

class _ChangeNickNameState extends State<ChangeNickName> {
  final TextEditingController _nickNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    _nickNameController.text = args['nickName'] ?? '';
    return PageScaffold(
      title: Text(context.l10n.nickNameTitle),
      leading: getPopLeading(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nickNameController,
              autofocus: true,
              decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  labelText: context.l10n.nickNameLabel,
                  hintText: context.l10n.nickNameHint,
                  prefixIcon: const Icon(Icons.person)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(context.l10n.nickNameRuleHint,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  )),
            ),
            ElevatedButton(
                onPressed: () async {
                  final nickName = _nickNameController.text.trim();
                  if (nickName.isEmpty) {
                    SmartDialog.showNotify(
                        msg: context.l10n.nickNameEmpty, notifyType: NotifyType.error);
                    return;
                  }
                  if (nickName == args['nickName']) {
                    SmartDialog.showNotify(
                        msg: context.l10n.nickNameSaveSuccess, notifyType: NotifyType.success);
                    Navigator.maybePop(context);
                    return;
                  }
                  SmartDialog.showLoading(msg: context.l10n.infoSaving);
                  try {
                    final auth = di.sl<AuthService>();
                    final user = auth.currentUser.value;
                    if (user == null) {
                      SmartDialog.dismiss();
                      SmartDialog.showNotify(
                          msg: context.l10n.avatarNotLoggedIn, notifyType: NotifyType.error);
                      return;
                    }

                    // Use AuthService.updateProfile — handles cloud sync,
                    // local fallback, and preserves all fields (gender, phone, etc.)
                    final (success, error) = await auth.updateProfile({
                      'name': nickName,
                    });

                    SmartDialog.dismiss();
                    if (success) {
                      SmartDialog.showNotify(
                          msg: context.l10n.nickNameSaveSuccess, notifyType: NotifyType.success);
                      Navigator.maybePop(context);
                    } else {
                      SmartDialog.showNotify(
                          msg: error ?? context.l10n.infoSaveFailed,
                          notifyType: NotifyType.failure);
                    }
                  } catch (e) {
                    debugPrint('[ChangeNickName] error: $e');
                    SmartDialog.dismiss();
                    SmartDialog.showNotify(
                        msg: context.l10n.nickNameSaveFailedWithError(e.toString()),
                        notifyType: NotifyType.failure);
                  }
                },
                child: Text(context.l10n.nickNameSaveChanges))
          ],
        ),
      ),
    );
  }
}
