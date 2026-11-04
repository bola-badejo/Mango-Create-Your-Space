import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:mango/Models/customModel/interest_elements.dart';
import 'package:mango/constants.dart';
import 'add_friends.dart';

class Interests extends StatefulWidget {
  const Interests({super.key});

  @override
  _InterestsState createState() => _InterestsState();
}

class _InterestsState extends State<Interests> {
  
  DocumentReference _getCollectionReference(String category) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('interests')
        .doc(category);
  }

  
  Future<void> _saveAllInterests() async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      
      final categories = {
        'books': SelectedInterests.books,
        'music': SelectedInterests.music,
        'sport': SelectedInterests.sport,
        'celebrities': SelectedInterests.celebrities,
        'comedy': SelectedInterests.comedy,
        'movies': SelectedInterests.movies,
        'innovationsandtech': SelectedInterests.innovationsandtech,
        'artanddesign': SelectedInterests.artanddesign,
        'science': SelectedInterests.science,
        'business': SelectedInterests.business,
        'lifestyle': SelectedInterests.lifestyle,
        'travel': SelectedInterests.travel,
        'news': SelectedInterests.news,
        'eco': SelectedInterests.eco,
        'fashion': SelectedInterests.fashion,
        'lifeandhistory': SelectedInterests.lifeAndHistory,
      };

      categories.forEach((category, interests) {
        if (interests.isNotEmpty) {
          final docRef = _getCollectionReference(category);
          batch.set(docRef, {'selectedGenres': interests});
        }
      });

      await batch.commit();

      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MakeFriends()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving interests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color dividerColor = isDark ? Colors.grey[700]! : Colors.blueGrey;
    final Color chipBackground = isDark ? Colors.grey[800]! : const Color(0xffededed);
    final Color selectedChipColor = isDark 
        ? Colors.deepOrange.withOpacity(0.8) 
        : Colors.deepOrangeAccent.withOpacity(0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _saveAllInterests,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.skip_next,
                  color: textColor,
                  size: 22,
                ),
                const SizedBox(width: 5.0),
                Text(
                  "Next",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 10.0),
              ],
            ),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 130),
              Text(
                "What are you interested in?",
                style: headingextStyle.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  "Tailor your Mango Space to your taste",
                  style: postTextBoxHint.copyWith(color: textColor.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              
              
              _buildInterestSection(
                title: "Books",
                interests: InterestList.books,
                category: 'books',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Music",
                interests: InterestList.music,
                category: 'music',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Sport",
                interests: InterestList.sport,
                category: 'sport',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Celebrities",
                interests: InterestList.celebrities,
                category: 'celebrities',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Comedy",
                interests: InterestList.comedy,
                category: 'comedy',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Movies",
                interests: InterestList.movies,
                category: 'movies',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Entertainment",
                interests: InterestList.entertainment,
                category: 'entertainment',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Innovation & Technology",
                interests: InterestList.innovationsAndTech,
                category: 'innovationsandtech',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Art & Design",
                interests: InterestList.artAndDesign,
                category: 'artanddesign',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Science",
                interests: InterestList.science,
                category: 'science',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Business",
                interests: InterestList.business,
                category: 'business',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Lifestyle",
                interests: InterestList.lifestyle,
                category: 'lifestyle',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Travel",
                interests: InterestList.travel,
                category: 'travel',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "News",
                interests: InterestList.news,
                category: 'news',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Eco",
                interests: InterestList.eco,
                category: 'eco',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Fashion",
                interests: InterestList.fashion,
                category: 'fashion',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
              
              
              _buildInterestSection(
                title: "Life & History",
                interests: InterestList.lifeAndHistory,
                category: 'lifeandhistory',
                isDark: isDark,
                textColor: textColor,
                chipBackground: chipBackground,
                selectedChipColor: selectedChipColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestSection({
    required String title,
    required List<String> interests,
    required String category,
    required bool isDark,
    required Color textColor,
    required Color chipBackground,
    required Color selectedChipColor,
  }) {
    return Column(
      children: [
        _titleContainer(title, textColor),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 150,
            child: MasonryGridView.count(
              scrollDirection: Axis.horizontal,
              itemCount: interests.length,
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              itemBuilder: (context, index) {
                return FilterChipWidget(
                  chipName: interests[index],
                  category: category,
                  isDark: isDark,
                  chipBackground: chipBackground,
                  selectedChipColor: selectedChipColor,
                );
              },
            ),
          ),
        ),
        Divider(
          color: isDark ? Colors.grey[700] : Colors.blueGrey,
          height: 20.0,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _titleContainer(String myTitle, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        myTitle,
        style: TextStyle(
          color: textColor,
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class FilterChipWidget extends StatefulWidget {
  final String chipName;
  final String category;
  final bool isDark;
  final Color chipBackground;
  final Color selectedChipColor;

  const FilterChipWidget({
    super.key,
    required this.chipName,
    required this.category,
    required this.isDark,
    required this.chipBackground,
    required this.selectedChipColor,
  });

  @override
  _FilterChipWidgetState createState() => _FilterChipWidgetState();
}

class _FilterChipWidgetState extends State<FilterChipWidget> {
  var _isSelected = false;

  void _handleSelection(bool isSelected) {
    setState(() {
      _isSelected = isSelected;
      
      
      switch (widget.category) {
        case "books":
          isSelected 
              ? SelectedInterests.books.add(widget.chipName)
              : SelectedInterests.books.remove(widget.chipName);
          break;
        case "music":
          isSelected 
              ? SelectedInterests.music.add(widget.chipName)
              : SelectedInterests.music.remove(widget.chipName);
          break;
        case "sport":
          isSelected 
              ? SelectedInterests.sport.add(widget.chipName)
              : SelectedInterests.sport.remove(widget.chipName);
          break;
        case "celebrities":
          isSelected 
              ? SelectedInterests.celebrities.add(widget.chipName)
              : SelectedInterests.celebrities.remove(widget.chipName);
          break;
        case "comedy":
          isSelected 
              ? SelectedInterests.comedy.add(widget.chipName)
              : SelectedInterests.comedy.remove(widget.chipName);
          break;
        case "movies":
          isSelected 
              ? SelectedInterests.movies.add(widget.chipName)
              : SelectedInterests.movies.remove(widget.chipName);
          break;
        case "innovationsandtech":
          isSelected 
              ? SelectedInterests.innovationsandtech.add(widget.chipName)
              : SelectedInterests.innovationsandtech.remove(widget.chipName);
          break;
        case "artanddesign":
          isSelected 
              ? SelectedInterests.artanddesign.add(widget.chipName)
              : SelectedInterests.artanddesign.remove(widget.chipName);
          break;
        case "science":
          isSelected 
              ? SelectedInterests.science.add(widget.chipName)
              : SelectedInterests.science.remove(widget.chipName);
          break;
        case "lifestyle":
          isSelected 
              ? SelectedInterests.lifestyle.add(widget.chipName)
              : SelectedInterests.lifestyle.remove(widget.chipName);
          break;
        case "business":
          isSelected 
              ? SelectedInterests.business.add(widget.chipName)
              : SelectedInterests.business.remove(widget.chipName);
          break;
        case "travel":
          isSelected 
              ? SelectedInterests.travel.add(widget.chipName)
              : SelectedInterests.travel.remove(widget.chipName);
          break;
        case "news":
          isSelected 
              ? SelectedInterests.news.add(widget.chipName)
              : SelectedInterests.news.remove(widget.chipName);
          break;
        case "eco":
          isSelected 
              ? SelectedInterests.eco.add(widget.chipName)
              : SelectedInterests.eco.remove(widget.chipName);
          break;
        case "lifeandhistory":
          isSelected 
              ? SelectedInterests.lifeAndHistory.add(widget.chipName)
              : SelectedInterests.lifeAndHistory.remove(widget.chipName);
          break;
        case "fashion":
          isSelected 
              ? SelectedInterests.fashion.add(widget.chipName)
              : SelectedInterests.fashion.remove(widget.chipName);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        widget.chipName,
        style: TextStyle(
          color: _isSelected 
              ? Colors.white 
              : (widget.isDark ? Colors.white : Colors.black),
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: _isSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.0),
      ),
      backgroundColor: widget.chipBackground,
      onSelected: _handleSelection,
      selectedColor: widget.selectedChipColor,
    );
  }
}