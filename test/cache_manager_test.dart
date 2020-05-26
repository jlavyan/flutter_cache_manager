import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/web/web_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'web_helper_test.dart';

void main() {
  group('Tests for getSingleFile', () {
    test('Valid cacheFile should not call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().add(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(fileInfo));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verifyNever(webHelper.downloadFile(any, key: anyNamed('key')));
    });

    test('Outdated cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(fileInfo));

      var webHelper = MockWebHelper();
      when(webHelper.downloadFile(argThat(anything), key: anyNamed('key')))
          .thenAnswer((i) => Stream.value(FileInfo(
                null,
                FileSource.Online,
                DateTime.now().add(const Duration(days: 7)),
                i.positionalArguments.first as String,
              )));
      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verify(webHelper.downloadFile(any, key: anyNamed('key'))).called(1);
    });

    test('Non-existing cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);

      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var webHelper = MockWebHelper();
      when(webHelper.downloadFile(fileUrl, key: fileUrl))
          .thenAnswer((_) => Stream.value(fileInfo));

      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verify(webHelper.downloadFile(any, key: anyNamed('key'))).called(1);
    });
  });

  group('Tests for getFile', () {
    test('Valid cacheFile should not call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().add(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(fileInfo));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      var fileStream = cacheManager.getFile(fileUrl);
      expect(fileStream, emits(fileInfo));
      verifyNever(webHelper.downloadFile(any, key: anyNamed('key')));
    });

    test('Outdated cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));

      var file = (await store.fileDir).childFile(fileName);
      var cachedInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(cachedInfo));

      var webHelper = MockWebHelper();
      var downloadedInfo = FileInfo(file, FileSource.Online,
          DateTime.now().add(const Duration(days: 1)), fileUrl);
      when(webHelper.downloadFile(fileUrl, key: fileUrl))
          .thenAnswer((_) => Stream.value(downloadedInfo));

      var cacheManager = TestCacheManager(store, webHelper);
      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsInOrder([cachedInfo, downloadedInfo]));

      verify(webHelper.downloadFile(any, key: anyNamed('key'))).called(1);
    });

    test('Non-existing cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);

      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var webHelper = MockWebHelper();
      when(webHelper.downloadFile(fileUrl, key: fileUrl))
          .thenAnswer((_) => Stream.value(fileInfo));

      var cacheManager = TestCacheManager(store, webHelper);

      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsInOrder([fileInfo]));
      verify(webHelper.downloadFile(any, key: anyNamed('key'))).called(1);
    });

    test('Errors should be passed to the stream', () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var webHelper = MockWebHelper();
      var error = HttpExceptionWithStatus(404, 'Invalid statusCode: 404',
          uri: Uri.parse(fileUrl));
      when(webHelper.downloadFile(fileUrl, key: fileUrl)).thenThrow(error);

      var cacheManager = TestCacheManager(store, webHelper);

      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsError(error));
      verify(webHelper.downloadFile(any, key: anyNamed('key'))).called(1);
    });
  });

  group('Testing puting files in cache', () {
    test('Check if file is written and info is stored', () async {
      var fileUrl = 'baseflow.com/test';
      var fileBytes = Uint8List(16);
      var extension = '.jpg';

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      var file = await cacheManager.putFile(fileUrl, fileBytes,
          fileExtension: extension);
      expect(await file.exists(), true);
      expect(await file.readAsBytes(), fileBytes);
      verify(store.putFile(any)).called(1);
    });
  });

  group('Testing remove files from cache', () {
    test('Remove existing file from cache', () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.retrieveCacheData(fileUrl))
          .thenAnswer((_) => Future.value(CacheObject(fileUrl)));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      await cacheManager.removeFile(fileUrl);
      verify(store.removeCachedFile(any)).called(1);
    });

    test("Don't remove files not in cache", () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.retrieveCacheData(fileUrl)).thenAnswer((_) => null);

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      await cacheManager.removeFile(fileUrl);
      verifyNever(store.removeCachedFile(any));
    });
  });

  test('Download file just downloads file', () async {
    var fileUrl = 'baseflow.com/test';
    var fileInfo = FileInfo(null, FileSource.Cache, DateTime.now(), fileUrl);
    var store = MockStore();
    var webHelper = MockWebHelper();
    when(webHelper.downloadFile(fileUrl, key: fileUrl))
        .thenAnswer((_) => Stream.value(fileInfo));
    var cacheManager = TestCacheManager(store, webHelper);
    expect(await cacheManager.downloadFile(fileUrl, key: fileUrl), fileInfo);
  });

  test('test file from memory', () {
    var fileUrl = 'baseflow.com/test';
    var fileInfo = FileInfo(null, FileSource.Cache, DateTime.now(), fileUrl);

    var store = MockStore();
    when(store.getFileFromMemory(fileUrl)).thenAnswer((_) => fileInfo);

    var webHelper = MockWebHelper();
    var cacheManager = TestCacheManager(store, webHelper);
    expect(cacheManager.getFileFromMemory(fileUrl), fileInfo);
  });

  test('Empty cache empties cache in store', () async {
    var store = MockStore();
    var webHelper = MockWebHelper();
    var cacheManager = TestCacheManager(store, webHelper);
    await cacheManager.emptyCache();
    verify(store.emptyCache()).called(1);
  });

  group('Progress tests', () {
    test('Test progress from download', () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      when(store.putFile(argThat(anything)))
          .thenAnswer((_) => Future.value(VoidCallback));

      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var fileService = MockFileService();
      var downloadStreamController = StreamController<List<int>>();
      when(fileService.get(fileUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            downloadStreamController.stream,
            6,
            'testv1',
            '.jpg',
            200,
            DateTime.now()));
      });

      var cacheManager =
          TestCacheManager(store, null, fileService: fileService);

      var fileStream = cacheManager.getFileStream(fileUrl, withProgress: true);
      downloadStreamController.add([0]);
      downloadStreamController.add([1]);
      downloadStreamController.add([2, 3]);
      downloadStreamController.add([4]);
      downloadStreamController.add([5]);
      await downloadStreamController.close();
      expect(
          fileStream,
          emitsInOrder([
            isA<DownloadProgress>().having((p) => p.progress, '1/6', 1 / 6),
            isA<DownloadProgress>().having((p) => p.progress, '2/6', 2 / 6),
            isA<DownloadProgress>().having((p) => p.progress, '4/6', 4 / 6),
            isA<DownloadProgress>().having((p) => p.progress, '5/6', 5 / 6),
            isA<DownloadProgress>().having((p) => p.progress, '6/6', 1),
            isA<FileInfo>(),
          ]));
    });

    test("Don't get progress when not asked", () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      when(store.putFile(argThat(anything)))
          .thenAnswer((_) => Future.value(VoidCallback));

      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var fileService = MockFileService();
      var downloadStreamController = StreamController<List<int>>();
      when(fileService.get(fileUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            downloadStreamController.stream,
            6,
            'testv1',
            '.jpg',
            200,
            DateTime.now()));
      });

      var cacheManager =
          TestCacheManager(store, null, fileService: fileService);

      var fileStream = cacheManager.getFileStream(fileUrl);
      downloadStreamController.add([0]);
      downloadStreamController.add([1]);
      downloadStreamController.add([2, 3]);
      downloadStreamController.add([4]);
      downloadStreamController.add([5]);
      await downloadStreamController.close();

      // Only expect a FileInfo Result and no DownloadProgress status objects.
      expect(
          fileStream,
          emitsInOrder([
            isA<FileInfo>(),
          ]));
    });
  });
}

class TestCacheManager extends BaseCacheManager {
  TestCacheManager(CacheStore store, WebHelper webHelper,
      {FileService fileService})
      : super('test',
            cacheStore: store, webHelper: webHelper, fileService: fileService);

  @override
  Future<String> getFilePath() {
    //Not needed because we supply our own store
    throw UnimplementedError();
  }
}

class MockStore extends Mock implements CacheStore {}

class MockWebHelper extends Mock implements WebHelper {}
