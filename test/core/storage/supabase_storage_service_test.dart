import 'dart:typed_data';

import 'package:appli_recette/core/storage/supabase_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseStorageClient mockStorageClient;
  late MockStorageFileApi mockFileApi;
  late SupabaseStorageService service;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockStorageClient = MockSupabaseStorageClient();
    mockFileApi = MockStorageFileApi();
    service = SupabaseStorageService(mockClient);

    when(() => mockClient.storage).thenReturn(mockStorageClient);
    when(() => mockStorageClient.from('recipe-photos'))
        .thenReturn(mockFileApi);
  });

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
  });

  group('SupabaseStorageService', () {
    const householdId = 'household-123';
    const recipeId = 'recipe-456';
    final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    const expectedPath = '$householdId/$recipeId.jpg';
    const expectedUrl =
        'https://example.supabase.co/storage/v1/object/public/recipe-photos/$expectedPath';

    test('uploadRecipePhoto uploads binary and returns public URL', () async {
      when(
        () => mockFileApi.uploadBinary(
          expectedPath,
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((_) async => expectedPath);

      when(() => mockFileApi.getPublicUrl(expectedPath))
          .thenReturn(expectedUrl);

      final url = await service.uploadRecipePhoto(
        bytes: testBytes,
        householdId: householdId,
        recipeId: recipeId,
      );

      expect(url, equals(expectedUrl));
      verify(
        () => mockFileApi.uploadBinary(
          expectedPath,
          testBytes,
          fileOptions: any(named: 'fileOptions'),
        ),
      ).called(1);
      verify(() => mockFileApi.getPublicUrl(expectedPath)).called(1);
    });

    test('uploadRecipePhoto uses correct path convention', () async {
      when(
        () => mockFileApi.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((_) async => expectedPath);

      when(() => mockFileApi.getPublicUrl(any())).thenReturn(expectedUrl);

      await service.uploadRecipePhoto(
        bytes: testBytes,
        householdId: 'my-household',
        recipeId: 'my-recipe',
      );

      verify(
        () => mockFileApi.uploadBinary(
          'my-household/my-recipe.jpg',
          testBytes,
          fileOptions: any(named: 'fileOptions'),
        ),
      ).called(1);
    });

    test('deleteRecipePhoto removes the correct file', () async {
      when(() => mockFileApi.remove([expectedPath]))
          .thenAnswer((_) async => []);

      await service.deleteRecipePhoto(
        householdId: householdId,
        recipeId: recipeId,
      );

      verify(() => mockFileApi.remove([expectedPath])).called(1);
    });

    group('deleteByPublicUrl', () {
      test('extracts path from public URL and deletes', () async {
        when(() => mockFileApi.remove(any())).thenAnswer((_) async => []);

        await service.deleteByPublicUrl(expectedUrl);

        verify(
          () => mockFileApi.remove([expectedPath]),
        ).called(1);
      });

      test('handles URL with different household/recipe IDs', () async {
        when(() => mockFileApi.remove(any())).thenAnswer((_) async => []);

        const url =
            'https://example.supabase.co/storage/v1/object/public/recipe-photos/abc-123/def-456.jpg';
        await service.deleteByPublicUrl(url);

        verify(
          () => mockFileApi.remove(['abc-123/def-456.jpg']),
        ).called(1);
      });

      test('does nothing for invalid URL', () async {
        await service.deleteByPublicUrl('not-a-valid-url');

        verifyNever(() => mockFileApi.remove(any()));
      });

      test('does nothing when bucket not found in URL', () async {
        await service
            .deleteByPublicUrl('https://example.com/some/other/path.jpg');

        verifyNever(() => mockFileApi.remove(any()));
      });
    });
  });
}
