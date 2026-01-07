// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(driverRideRepository)
const driverRideRepositoryProvider = DriverRideRepositoryProvider._();

final class DriverRideRepositoryProvider extends $FunctionalProvider<
    DriverRideRepository,
    DriverRideRepository,
    DriverRideRepository> with $Provider<DriverRideRepository> {
  const DriverRideRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'driverRideRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$driverRideRepositoryHash();

  @$internal
  @override
  $ProviderElement<DriverRideRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DriverRideRepository create(Ref ref) {
    return driverRideRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriverRideRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriverRideRepository>(value),
    );
  }
}

String _$driverRideRepositoryHash() =>
    r'f6a54f831a88b644238af18eb39b510a54559fb3';
