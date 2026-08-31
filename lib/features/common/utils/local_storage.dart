import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  // 用户
  static _LS<String> user_token = _LS('user_token'); // 登录token
  static _LS<String> user_uid = _LS('user_uid'); // 用户ID
  static _LS<String> user_nickName = _LS('user_nickName'); // 用户昵称
  static _LS<String> user_avatar = _LS('user_avatar'); // 用户缩略头像url
  static _LS<String> user_userName = _LS('user_userName'); // 用户真名
  static _LS<String> user_mobile = _LS('user_mobile'); // 用户手机号(隐藏中间四位) 123****1234
  static _LS<String> user_college = _LS('user_college'); // 用户学院/组织
  static _LS<String> user_gender = _LS('user_gender'); // 用户性别
  static _LS<String> user_dormBuilding = _LS('user_dormBuilding'); // 用户楼栋
  static _LS<String> user_dormNumber = _LS('user_dormNumber'); // 用户房间号

  // 课表
  static _LS<String> timetable_college = _LS('timetable_college'); // 学院/组织
  static _LS<String> timetable_inited = _LS('timetable_inited'); // 课程表页面是否完成初始化
  static _LS<Map> timetable_data = _LS('timetable_data'); // 课程表原始数据
}

class _LS<T> {
  static SharedPreferences? instance;
  static Future<SharedPreferences> _getPref() async {
    if (instance == null) {
      instance = await SharedPreferences.getInstance();
      return Future(() => instance!);
    }
    return Future(() => instance!);
  }

  final String key;
  _LS(this.key);

  Future<dynamic> get() async {
    final prefs = await _getPref();
    var v = prefs.get(key);
    if (v == null) {
      return Future(() => null);
    }
    if (v is String && v.startsWith('@@**JSON^^@@')) {
      v = v.substring('@@**JSON^^@@'.length);
      return Future(() => json.decode(v as String) as Map<dynamic, dynamic>);
    }
    return Future(() => prefs.get(key) as T?);
  }

  Future<bool> set(T value) async {
    final prefs = await _getPref();
    if (value is String) {
      return Future(() => prefs.setString(key, value as String));
    }
    if (value is int) {
      return Future(() => prefs.setInt(key, value as int));
    }
    if (value is double) {
      return Future(() => prefs.setDouble(key, value as double));
    }
    if (value is bool) {
      return Future(() => prefs.setBool(key, value as bool));
    }
    if (value is List<String>) {
      return Future(() => prefs.setStringList(key, value as List<String>));
    }
    if (value is Map) {
      return Future(() => prefs.setString(key, '@@**JSON^^@@${json.encode(value)}'));
    }
    return Future(() => false);
  }
}
