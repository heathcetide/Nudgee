import 'package:dio/dio.dart';

var dio = Dio();

// const String BaseURL = "https://17cd-117-175-132-168.ngrok-free.app";
const String BaseURL = "http://lingecho.com:8082";

final Options FromOptions = Options(
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
  },
);
