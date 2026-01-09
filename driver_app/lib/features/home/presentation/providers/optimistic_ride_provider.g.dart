// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'optimistic_ride_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OptimisticRide)
const optimisticRideProvider = OptimisticRideProvider._();

final class OptimisticRideProvider
    extends $NotifierProvider<OptimisticRide, OptimisticState> {
  const OptimisticRideProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'optimisticRideProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$optimisticRideHash();

  @$internal
  @override
  OptimisticRide create() => OptimisticRide();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OptimisticState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OptimisticState>(value),
    );
  }
}

String _$optimisticRideHash() => r'9e70ef85e6453e3fb487140c0c1ebb1e9086b422';

abstract class _$OptimisticRide extends $Notifier<OptimisticState> {
  OptimisticState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<OptimisticState, OptimisticState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<OptimisticState, OptimisticState>,
        OptimisticState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
