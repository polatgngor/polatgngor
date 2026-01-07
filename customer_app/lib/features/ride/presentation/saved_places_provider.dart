import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/saved_place_model.dart';
import '../data/saved_places_service.dart';

final savedPlacesProvider = AsyncNotifierProvider<SavedPlacesNotifier, List<SavedPlace>>(() {
  return SavedPlacesNotifier();
});

class SavedPlacesNotifier extends AsyncNotifier<List<SavedPlace>> {
  
  @override
  Future<List<SavedPlace>> build() async {
    final service = ref.read(savedPlacesServiceProvider);
    return service.getSavedPlaces();
  }

  Future<void> addPlace({
    required String title,
    required String address,
    required double lat,
    required double lng,
    String icon = 'place',
  }) async {
    // Optimistic UI: Don't show full loading spinner, keep list visible
    // We can't optimistically add easily without a temp ID and handling that in UI, 
    // so we just keep the current list visible (no flicker) until the new one is ready.
    final previousList = state.value ?? [];
    
    // state = const AsyncValue.loading(); // REMOVED to prevent white screen/spinner flicker
    
    state = await AsyncValue.guard(() async {
      final service = ref.read(savedPlacesServiceProvider);
      final newPlace = await service.addSavedPlace(
        title: title,
        address: address,
        lat: lat,
        lng: lng,
        icon: icon,
      );
      return [newPlace, ...previousList];
    });
  }

  Future<void> deletePlace(String id) async {
    final service = ref.read(savedPlacesServiceProvider);
    final previousList = state.value ?? [];
    
    // Optimistic Delete: Remove instantly
    state = AsyncValue.data(previousList.where((p) => p.id != id).toList());
    
    try {
      await service.deleteSavedPlace(id);
    } catch (e, st) {
      // Revert on failure
      state = AsyncValue.data(previousList);
      // We could also set error state but that might replace the list with error widget.
      // Better to keep list and show toast (handled by UI usually, but provider just reverts)
      // state = AsyncValue.error(e, st);
    }
  }
}
