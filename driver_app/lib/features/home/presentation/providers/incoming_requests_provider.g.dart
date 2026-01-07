// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incoming_requests_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(IncomingRequests)
const incomingRequestsProvider = IncomingRequestsProvider._();

final class IncomingRequestsProvider
    extends $NotifierProvider<IncomingRequests, List<Map<String, dynamic>>> {
  const IncomingRequestsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'incomingRequestsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$incomingRequestsHash();

  @$internal
  @override
  IncomingRequests create() => IncomingRequests();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Map<String, dynamic>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Map<String, dynamic>>>(value),
    );
  }
}

String _$incomingRequestsHash() => r'3db64e087480550e0e08273043ecf5b4af39c517';

abstract class _$IncomingRequests
    extends $Notifier<List<Map<String, dynamic>>> {
  List<Map<String, dynamic>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref
        as $Ref<List<Map<String, dynamic>>, List<Map<String, dynamic>>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<Map<String, dynamic>>, List<Map<String, dynamic>>>,
        List<Map<String, dynamic>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
