import 'package:clock/clock.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

///Cache information of one file
class CacheObject {
  static const columnId = '_id';
  static const columnUrl = 'url';
  static const columnPath = 'relativePath';
  static const columnETag = 'eTag';
  static const columnValidTill = 'validTill';
  static const columnTouched = 'touched';
  static const columnKey = 'key';

  CacheObject(this.key,
      {this.relativePath, this.validTill, this.eTag, this.id, this.url});

  CacheObject.fromMap(Map<String, dynamic> map)
      : id = map[columnId] as int,
        url = map[columnUrl] as String,
        relativePath = map[columnPath] as String,
        validTill =
            DateTime.fromMillisecondsSinceEpoch(map[columnValidTill] as int),
        eTag = map[columnETag] as String,
        key = map[columnKey] as String;

  int id;
  String url;
  String relativePath;
  DateTime validTill;
  String eTag;
  String key;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      columnUrl: url,
      columnPath: relativePath,
      columnETag: eTag,
      columnValidTill: validTill?.millisecondsSinceEpoch ?? 0,
      columnTouched: clock.now().millisecondsSinceEpoch,
      columnKey: key
    };
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }

  static List<CacheObject> fromMapList(List<Map<String, dynamic>> list) {
    return list.map((map) => CacheObject.fromMap(map)).toList();
  }
}
