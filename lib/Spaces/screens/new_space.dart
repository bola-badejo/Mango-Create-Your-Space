import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mango/Models/animation.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/Spaces/controllers/avatars.dart';
import 'package:mango/Spaces/controllers/friends.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Utils/text_field.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class NewSpaceScreen extends StatelessWidget {
  NewSpaceScreen({super.key});
  final FriendsController controller = Get.put(FriendsController());
  final AvatarController avatarController = Get.put(AvatarController());
  final CategoryController categoryController = Get.put(CategoryController());

  final GlobalKey<ExpansionTileCardState> cardA = GlobalKey();
  final GlobalKey<ExpansionTileCardState> cardB = GlobalKey();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _spaceTitleController = TextEditingController();
  final TextEditingController _spaceDescriptionController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  void _showBottomModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (value) {
                  avatarController.updateSearchQuery(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),

            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelStyle: const TextStyle(fontSize: 12),
                      tabs: const [
                        Tab(text: 'Planetary'),
                        Tab(text: 'Space Objects'),
                        Tab(text: 'Mango Custom'),
                      ],
                      indicatorColor: Theme.of(context).cardColor,
                      labelColor: Theme.of(context).cardColor,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildAvatarGrid(
                            avatarController.planetaryAvatars,
                            avatarController.isLoading.value,
                            context,
                          ),
                          _buildAvatarGrid(
                            avatarController.spaceObjectAvatars,
                            avatarController.isLoading.value,
                            context,
                          ),
                          _buildAvatarGrid(
                            avatarController.mangoCustomAvatars,
                            avatarController.isLoading.value,
                            context,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarGrid(
    RxList<Map> avatars,
    bool isLoading,
    BuildContext context,
  ) {
    return Obx(() {
      if (isLoading) {
        return Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
      }

      List<Map> filteredAvatars = avatars.where((avatar) {
        return avatar['name'].toString().toLowerCase().contains(
          avatarController.searchQuery.value.toLowerCase(),
        );
      }).toList();

      if (filteredAvatars.isEmpty) {
        return Center(
          child: Text(
            'No avatars found',
            style: TextStyle(color: Theme.of(context).primaryColorLight),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: OptimizedGridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.7,
          ),
          itemCount: filteredAvatars.length,
          itemBuilder: (context, index) {
            final avatar = filteredAvatars[index];

            bool isPremium = (avatar['price'] ?? 0) > 0;

            return MangoPressable(
              onTap: isPremium
                  ? null
                  : () {
                      avatarController.selectAvatar(avatar['link'].toString());
                      Navigator.pop(context);
                    },
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.transparent,
                          backgroundImage: NetworkImage(
                            avatar['link'].toString(),
                          ),
                          radius: 25,
                          onBackgroundImageError: (exception, stackTrace) {
                            print('❌ Failed to load image: ${avatar['link']}');
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          avatar['name'].toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Theme.of(context).primaryColorLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPremium)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.star,
                            size: 10,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Create your Space",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Theme.of(context).primaryColorLight,
                ),
              ),
              WidgetSpan(
                child: Transform.translate(
                  offset: const Offset(2, -4),
                  child: Text(
                    'TM',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Theme.of(context).primaryColorLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Obx(
                    () => MangoPressable(
                      onTap: () => _showBottomModal(context),
                      child: avatarController.selectedAvatar.value.isEmpty
                          ? const CircleAvatar(
                              backgroundColor: MangoPalette.green500,
                              radius: 50,
                              child: Icon(Icons.add),
                            )
                          : CircleAvatar(
                              backgroundImage: NetworkImage(
                                avatarController.selectedAvatar.value,
                              ),
                              backgroundColor: Colors.transparent,
                              radius: 50,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: ExpansionTileCard(
                    key: cardA,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(
                        Icons.abc_outlined,
                        size: 18,
                        color: Theme.of(context).primaryColorLight,
                      ),
                    ),
                    title: Text(
                      "Space Info",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColorLight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      "Customize your Space to your taste",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColorLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    children: <Widget>[
                      const Divider(thickness: 0.10, height: 0.10),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 30.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            FadeAnimation(
                              1.1,
                              CustomTextField(
                                controller: _spaceTitleController,
                                placeholder: 'Space title',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a space title';
                                  }
                                  if (value.length < 3) {
                                    return 'Title must be at least 3 characters';
                                  }
                                  return null;
                                },
                                leading: Icon(
                                  Icons.title,
                                  color: Theme.of(context).primaryColorLight,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20.0),
                            FadeAnimation(
                              1.2,
                              CustomMultilineTextField(
                                controller: _spaceDescriptionController,
                                placeholder: 'Tell us about your Space..',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a space description';
                                  }
                                  if (value.length < 10) {
                                    return 'Description must be at least 10 characters';
                                  }
                                  return null;
                                },
                                leading: Icon(
                                  Icons.description,
                                  color: Theme.of(context).primaryColorLight,
                                  size: 20,
                                ),
                                height: 100,
                              ),
                            ),
                            const SizedBox(height: 10.0),
                            FadeAnimation(
                              1.3,
                              CustomDropdown<String>(
                                value:
                                    categoryController.selectedCategory.value ==
                                        'Category'
                                    ? null
                                    : categoryController.selectedCategory.value,
                                placeholder: 'Category',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a category';
                                  }
                                  return null;
                                },
                                items: categoryController.categories
                                    .map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).primaryColorLight,
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                                onChanged: categoryController.selectCategory,
                                leading: Icon(
                                  Icons.category,
                                  color: Theme.of(context).primaryColorLight,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10.0),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Collaborators',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColorLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Obx(() {
                        if (controller.selectedFriends.isNotEmpty) {
                          return TextButton(
                            onPressed: () {
                              _showClearAllConfirmation(context);
                            },
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade300,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Selected Contributors with Remove Icons
                Obx(() {
                  if (controller.selectedFriends.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: MangoPalette.grey800.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                        ),
                        child: Center(
                          child: Text(
                            'No collaborators selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: MangoPalette.grey400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(left: 10.0, bottom: 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: controller.selectedFriends.map((friend) {
                        return _buildContributorCard(friend, context);
                      }).toList(),
                    ),
                  );
                }),

                const SizedBox(height: 10),

                // Available Friends to Add
                Obx(() {
                  final availableFriends = controller.availableFriends;

                  if (availableFriends.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'No more friends available to add',
                        style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...availableFriends
                            .take(5)
                            .map(
                              (friend) => MangoPressable(
                                onTap: () =>
                                    controller.toggleSelectedFriend(friend),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            backgroundImage: NetworkImage(
                                              friend.profileImage,
                                            ),
                                            radius: 30,
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: MangoPalette.green500,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Theme.of(
                                                    context,
                                                  ).cardColor,
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@${friend.username}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: MangoPalette.grey400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        if (availableFriends.length > 5)
                          MangoPressable(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => FriendsBottomSheet(),
                            ),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: MangoPalette.grey800,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_horiz,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          MangoPressable(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => FriendsBottomSheet(),
                            ),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: MangoPalette.grey800,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColorLight,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                buildSettingsSection(),
                SizedBox(height: controller.isPrivate.value ? 20 : 0),
                Obx(() {
                  return controller.isPrivate.value
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3.0,
                            vertical: 10,
                          ),
                          child: ExpansionTileCard(
                            key: cardB,
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Icon(
                                Icons.price_change,
                                size: 18,
                                color: Theme.of(context).primaryColorLight,
                              ),
                            ),
                            title: Text(
                              "Payment Info",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColorLight,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              "Add pricing and details",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColorLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            children: <Widget>[
                              const Divider(thickness: 0.10, height: 0.10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                  vertical: 30.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    FadeAnimation(
                                      1.1,
                                      CustomTextField(
                                        controller: _priceController,
                                        placeholder: 'Price',
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (controller.isPrivate.value &&
                                              (value == null ||
                                                  value.isEmpty)) {
                                            return 'Please enter a price for private space';
                                          }
                                          if (value != null &&
                                              value.isNotEmpty) {
                                            final price = double.tryParse(
                                              value,
                                            );
                                            if (price == null || price <= 0) {
                                              return 'Please enter a valid price';
                                            }
                                          }
                                          return null;
                                        },
                                        leading: Icon(
                                          Icons.attach_money,
                                          color: Theme.of(
                                            context,
                                          ).primaryColorLight,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container();
                }),
                const SizedBox(height: 40),
                Center(
                  child: Obx(() {
                    return Container(
                      padding: const EdgeInsets.only(top: 3, left: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).primaryColorLight,
                          ),
                          top: BorderSide(
                            color: Theme.of(context).primaryColorLight,
                          ),
                          left: BorderSide(
                            color: Theme.of(context).primaryColorLight,
                          ),
                          right: BorderSide(
                            color: Theme.of(context).primaryColorLight,
                          ),
                        ),
                      ),
                      child: MaterialButton(
                        minWidth: double.infinity,
                        height: 60,
                        onPressed: controller.isLoading.value
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  await controller.createSpace(
                                    _spaceTitleController.text,
                                    _spaceDescriptionController.text,
                                    _priceController.text,
                                    categoryController.selectedCategory.value,
                                    context,
                                  );
                                  Get.back();
                                } else {
                                  UtilsService().showSnackbar(
                                    'Validation Error',
                                    'Please fill all required fields correctly',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    context: context,
                                  );
                                }
                              },
                        color: controller.isLoading.value
                            ? MangoPalette.grey500
                            : MangoPalette.green500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                        ),
                        child: controller.isLoading.value
                            ? CircularProgressIndicator(semanticsLabel: 'Loading', 
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColorDark,
                                ),
                              )
                            : RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Create your Space",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).primaryColorDark,
                                      ),
                                    ),
                                    WidgetSpan(
                                      child: Transform.translate(
                                        offset: const Offset(2, -4),
                                        child: Text(
                                          'TM',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).primaryColorDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContributorCard(MangoUser friend, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(friend.profileImage),
                radius: 30,
              ),
              // Remove button overlay
              Positioned(
                top: -5,
                right: -5,
                child: MangoPressable(
                  onTap: () {
                    _showRemoveConfirmation(context, friend);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).cardColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '@${friend.username}',
            style: TextStyle(
              fontSize: 12,
              color: MangoPalette.grey400,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context, MangoUser friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Remove Contributor',
          style: TextStyle(color: Theme.of(context).primaryColorLight),
        ),
        content: Text(
          'Are you sure you want to remove @${friend.username} as a contributor?',
          style: TextStyle(color: Theme.of(context).primaryColorLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: MangoPalette.grey400),
            ),
          ),
          TextButton(
            onPressed: () {
              controller.removeSelectedFriend(friend);
              Navigator.pop(context);
            },
            child: Text('Remove', style: TextStyle(color: Colors.red.shade300)),
          ),
        ],
      ),
    );
  }

  // NEW: Show confirmation for clearing all contributors
  void _showClearAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Clear All Contributors',
          style: TextStyle(color: Theme.of(context).primaryColorLight),
        ),
        content: Text(
          'Are you sure you want to remove all ${controller.selectedFriends.length} contributors?',
          style: TextStyle(color: Theme.of(context).primaryColorLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: MangoPalette.grey400),
            ),
          ),
          TextButton(
            onPressed: () {
              controller.clearSelectedFriends();
              Navigator.pop(context);
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputSection(String hintText, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MangoPalette.grey200,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: MangoPalette.grey500),
          const SizedBox(width: 10),
          Text(
            hintText,
            style: const TextStyle(fontSize: 16, color: MangoPalette.grey500),
          ),
          const Spacer(),
          const Icon(Icons.add, color: MangoPalette.grey500),
        ],
      ),
    );
  }

  Widget buildMemberAvatar(String name, String imagePath) {
    return Column(
      children: [
        CircleAvatar(radius: 30, backgroundImage: AssetImage(imagePath)),
        const SizedBox(height: 5),
        Text(name, style: const TextStyle(fontSize: 14, color: MangoPalette.black)),
      ],
    );
  }

  Widget buildSettingsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSettingCard(
              Icons.lock,
              'Privacy',
              'Make this Space private',
              isSwitch: controller.isPrivate,
            ),
            buildSettingCard(
              Icons.movie,
              'Movies',
              'enable movies in this Space',
              isSwitch: controller.isMovies,
            ),
            buildSettingCard(
              Icons.music_note_outlined,
              'Music',
              'enable music in this Space',
              isSwitch: controller.isMusic,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSettingCard(
              Icons.auto_stories_outlined,
              'Books',
              'enable Books in this Space',
              isSwitch: controller.isBooks,
            ),
            buildSettingCard(
              Icons.podcasts,
              'Podcasts',
              'Make this Room private',
              isSwitch: controller.isPodcast,
            ),
            buildSettingCard(
              Icons.chair_outlined,
              'Lounge',
              'enable lounge in this Space',
              isSwitch: controller.isLounge,
            ),
          ],
        ),
      ],
    );
  }

  Widget buildSettingCard(
    IconData icon,
    String title,
    String subtitle, {
    required RxBool isSwitch,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(MangoRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color.fromARGB(255, 255, 255, 255)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(255, 117, 117, 117),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 10),
            Obx(() {
              return Switch(
                value: isSwitch.value,
                onChanged: (value) {
                  isSwitch.value = value;
                },
                activeColor: const Color.fromARGB(255, 255, 178, 35),
                inactiveThumbColor: const Color.fromARGB(255, 117, 117, 117),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class FriendsBottomSheet extends StatelessWidget {
  final FriendsController controller = Get.find<FriendsController>();

  FriendsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Collaborators',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColorLight,
                ),
              ),
              Obx(() {
                if (controller.selectedFriends.isNotEmpty) {
                  return TextButton(
                    onPressed: () {
                      _showClearAllConfirmation(context);
                    },
                    child: Text(
                      'Clear All (${controller.selectedFriends.length})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade300,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field
          TextField(
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search friends...',
              hintStyle: TextStyle(color: MangoPalette.grey400, fontSize: 14),
              filled: true,
              fillColor: MangoPalette.grey800,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MangoRadius.md),
                borderSide: BorderSide(color: MangoPalette.grey700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MangoRadius.md),
                borderSide: const BorderSide(color: MangoPalette.green500),
              ),
            ),
            onChanged: (value) {
              controller.searchQuery.value = value;
            },
          ),

          const SizedBox(height: 20),

          // Selected Friends Summary
          Obx(() {
            if (controller.selectedFriends.isEmpty)
              return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MangoPalette.grey800,
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected (${controller.selectedFriends.length})',
                    style: TextStyle(
                      fontSize: 12,
                      color: MangoPalette.green300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: controller.selectedFriends.map((friend) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MangoPalette.green900,
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(
                                friend.profileImage,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '@${friend.username}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            MangoPressable(
        semanticLabel: 'Close',
                              onTap: () {
                                controller.removeSelectedFriend(friend);
                              },
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),

          // Friends Grid
          Expanded(
            child: Obx(() {
              if (controller.filteredFriends.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: MangoPalette.grey600,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        controller.searchQuery.value.isEmpty
                            ? 'No friends found'
                            : 'No matching friends',
                        style: TextStyle(color: MangoPalette.grey400),
                      ),
                    ],
                  ),
                );
              }

              return OptimizedGridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemCount: controller.filteredFriends.length,
                itemBuilder: (_, index) {
                  final friend = controller.filteredFriends[index];
                  final isSelected = controller.selectedFriends.contains(
                    friend,
                  );

                  return MangoPressable(
                    onTap: () {
                      controller.toggleSelectedFriend(friend);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                        border: Border.all(
                          color: isSelected
                              ? MangoPalette.green500
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                backgroundImage: NetworkImage(
                                  friend.profileImage,
                                ),
                                radius: 35,
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: MangoPalette.green500,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '@${friend.username}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? MangoPalette.green500
                                  : MangoPalette.grey400,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),

          // Done Button
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MangoPalette.green500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                ),
                child: Obx(() {
                  return Text(
                    'Done (${controller.selectedFriends.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Clear All',
          style: TextStyle(color: Theme.of(context).primaryColorLight),
        ),
        content: Text(
          'Remove all ${controller.selectedFriends.length} selected contributors?',
          style: TextStyle(color: Theme.of(context).primaryColorLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: MangoPalette.grey400),
            ),
          ),
          TextButton(
            onPressed: () {
              controller.clearSelectedFriends();
              Navigator.pop(context);
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryController extends GetxController {
  var selectedCategory = 'Category'.obs;
  var categories = <String>[
    'Content Creator',
    'Art Space',
    'Entertainment',
    'Science',
    'Technology',
    'Lifestyle',
  ].obs;

  void selectCategory(String? category) {
    if (category != null) {
      selectedCategory.value = category;
    }
  }
}
