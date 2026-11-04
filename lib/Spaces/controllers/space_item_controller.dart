
import 'package:get/get.dart';
import 'package:mango/Spaces/controllers/space_item.dart';
import 'package:mango/utils.dart';

class SpaceItemsController extends GetxController {
  final SpaceItemsService _service = SpaceItemsService();
  
  final RxList<SpaceItem> spaceItems = <SpaceItem>[].obs;
  final RxList<SpaceWithItems> allUserSpaceItems = <SpaceWithItems>[].obs;
  final RxList<SpaceItem> recentItems = <SpaceItem>[].obs;
  
  final RxString selectedSpaceId = ''.obs;
  final RxString selectedItemType = 'all'.obs;
  final RxBool isLoading = false.obs;
  
  get context => null;

  @override
  void onInit() {
    super.onInit();
    
    loadRecentItems(context);
  }

  
  Future<void> loadSpaceItems(String spaceId, context) async {
    try {
      isLoading.value = true;
      selectedSpaceId.value = spaceId;
      
      final items = await _service.getSpaceItems(spaceId);
      spaceItems.assignAll(items);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to load space items: $e', context: context);
    } finally {
      isLoading.value = false;
    }
  }

  
  Future<List<SpaceItem>> loadSpaceItemsByType(String spaceId, String itemType, context) async {
    try {
      isLoading.value = true;
      selectedSpaceId.value = spaceId;
      selectedItemType.value = itemType;
      
      final items = await _service.getSpaceItemsByType(spaceId, itemType);
      spaceItems.assignAll(items);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to load $itemType items: $e', context: context);
    } finally {
      isLoading.value = false;
    }
    return spaceItems;
  }

  
  Future<void> loadAllUserSpaceItems(context) async {
    try {
      isLoading.value = true;
      final items = await _service.getAllUserSpaceItems();
      allUserSpaceItems.assignAll(items);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to load user space items: $e', context: context);
    } finally {
      isLoading.value = false;
    }
  }

  
  Future<void> loadRecentItems(context) async {
    try {
      isLoading.value = true;
      final items = await _service.getRecentItems();
      recentItems.assignAll(items);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to load recent items: $e', context: context);
    } finally {
      isLoading.value = false;
    }
  }

  
  Future<void> deleteItem(String spaceId, SpaceItem item, context) async {
    try {
      await _service.deleteSpaceItem(spaceId, item);
      
      
      spaceItems.remove(item);
      recentItems.removeWhere((i) => i.id == item.id);
      
      
      for (final spaceWithItems in allUserSpaceItems) {
        if (spaceWithItems.spaceId == spaceId) {
          spaceWithItems.items.remove(item);
        }
      }
      
      UtilsService().showSnackbar('Success', 'Item removed from space', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to delete item: $e', context: context);
    }
  }

  
  void clearData() {
    spaceItems.clear();
    allUserSpaceItems.clear();
    recentItems.clear();
    selectedSpaceId.value = '';
    selectedItemType.value = 'all';
  }
}