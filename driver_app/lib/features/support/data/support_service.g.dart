// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supportService)
const supportServiceProvider = SupportServiceProvider._();

final class SupportServiceProvider
    extends $FunctionalProvider<SupportService, SupportService, SupportService>
    with $Provider<SupportService> {
  const SupportServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'supportServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$supportServiceHash();

  @$internal
  @override
  $ProviderElement<SupportService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupportService create(Ref ref) {
    return supportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupportService>(value),
    );
  }
}

String _$supportServiceHash() => r'd3ef316389814d1ed7c6af1378aa00680aa8f341';

@ProviderFor(myTickets)
const myTicketsProvider = MyTicketsProvider._();

final class MyTicketsProvider extends $FunctionalProvider<
        AsyncValue<List<dynamic>>, List<dynamic>, FutureOr<List<dynamic>>>
    with $FutureModifier<List<dynamic>>, $FutureProvider<List<dynamic>> {
  const MyTicketsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'myTicketsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$myTicketsHash();

  @$internal
  @override
  $FutureProviderElement<List<dynamic>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<dynamic>> create(Ref ref) {
    return myTickets(ref);
  }
}

String _$myTicketsHash() => r'9d61f3802c9081d30f0e2362896db1e0df2de4af';
