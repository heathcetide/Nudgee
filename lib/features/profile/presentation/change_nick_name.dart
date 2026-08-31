import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/features/common/utils/consts.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

class ChangeNickName extends StatefulWidget {
  const ChangeNickName({super.key});

  @override
  State<ChangeNickName> createState() => _ChangeNickNameState();
}

class _ChangeNickNameState extends State<ChangeNickName> {
  TextEditingController _nickNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> args =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    _nickNameController.text = args['nickName'];
    return PageScaffold(
      title: Text('修改昵称'),
      leading: getPopLeading(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nickNameController,
              autofocus: true,
              decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: '昵称',
                  hintText: '请输入您的新昵称',
                  prefixIcon: Icon(Icons.person)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('昵称限制长度最多16个字符\n昵称只能包含汉字、字母、数字和下划线',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  )),
            ),
            ElevatedButton(
                onPressed: () async {
                  String nickName = _nickNameController.text;
                  if (nickName == args['nickName']) {
                    SmartDialog.showNotify(msg: '保存成功', notifyType: NotifyType.success);
                    Navigator.maybePop(context);
                    return;
                  }
                  SmartDialog.showLoading(msg: '等待响应中');
                  var resp =
                      (await dio.post(BaseURL + '/user/update', data: {'nickName': nickName})).data;
                  if (resp['code'] != 0) {
                    SmartDialog.dismiss();
                    SmartDialog.showNotify(msg: resp['msg'], notifyType: NotifyType.failure);
                    return;
                  }
                  SmartDialog.showLoading(msg: '等待更新中');
                  await syncUserInfo();
                  SmartDialog.dismiss();
                  SmartDialog.showNotify(msg: '保存成功', notifyType: NotifyType.success);
                  Navigator.maybePop(context);
                },
                child: Text('保存更改'))
          ],
        ),
      ),
    );
  }
}
