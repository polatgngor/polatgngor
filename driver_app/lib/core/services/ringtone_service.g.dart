// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ringtone_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ringtoneService)
const ringtoneServiceProvider = RingtoneServiceProvider._();

final class RingtoneServiceProvider extends $FunctionalProvider<RingtoneService,
    RingtoneService, RingtoneService> with $Provider<RingtoneService> {
  const RingtoneServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'ringtoneServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$ringtoneServiceHash();

  @$internal
  @override
  $ProviderElement<RingtoneService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RingtoneService create(Ref ref) {
    return ringtoneService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RingtoneService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RingtoneService>(value),
    );
  }
}

String _$ringtoneServiceHash() => r'b4d6830d7bf3b7d813b77e99346013ed544b095a';
