// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Ride)
const rideProvider = RideProvider._();

final class RideProvider extends $NotifierProvider<Ride, RideState> {
  const RideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rideProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rideHash();

  @$internal
  @override
  Ride create() => Ride();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RideState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RideState>(value),
    );
  }
}

String _$rideHash() => r'a9252d8a98d0c6576e774d1cbc96e43f46a94452';

abstract class _$Ride extends $Notifier<RideState> {
  RideState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<RideState, RideState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RideState, RideState>,
              RideState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
