// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directions_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(directionsService)
const directionsServiceProvider = DirectionsServiceProvider._();

final class DirectionsServiceProvider extends $FunctionalProvider<
    DirectionsService,
    DirectionsService,
    DirectionsService> with $Provider<DirectionsService> {
  const DirectionsServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'directionsServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$directionsServiceHash();

  @$internal
  @override
  $ProviderElement<DirectionsService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DirectionsService create(Ref ref) {
    return directionsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectionsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectionsService>(value),
    );
  }
}

String _$directionsServiceHash() => r'56b75c5a447a06296c2fb56d6ab6944d55db044a';
