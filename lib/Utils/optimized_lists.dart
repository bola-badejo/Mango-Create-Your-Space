// optimized_list.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double? cacheExtent;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool primary;
  final Axis scrollDirection;
  final bool reverse;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;
  final bool addSemanticIndexes;
  final IndexedWidgetBuilder? separatorBuilder;
  final double? itemExtent;
  final Widget? prototypeItem;
  
  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.cacheExtent,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.primary = true,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.addSemanticIndexes = true,
    this.separatorBuilder,
    this.itemExtent,
    this.prototypeItem,
  });
  
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web-optimized ListView
      if (separatorBuilder != null) {
        return ListView.separated(
          controller: controller,
          padding: padding,
          itemCount: itemCount,
          shrinkWrap: shrinkWrap,
          physics: physics ?? _getOptimalPhysics(),
          primary: primary,
          scrollDirection: scrollDirection,
          reverse: reverse,
          dragStartBehavior: dragStartBehavior,
          clipBehavior: clipBehavior,
          restorationId: restorationId,
          keyboardDismissBehavior: keyboardDismissBehavior,
          cacheExtent: cacheExtent ?? 500.0,
          addRepaintBoundaries: true, // Force for web
          addAutomaticKeepAlives: false, // Reduce memory on web
          addSemanticIndexes: false, // Disable for web performance
          separatorBuilder: separatorBuilder!,
          itemBuilder: (context, index) {
            return RepaintBoundary(
              child: itemBuilder(context, index),
            );
          },
        );
      }
      
      return ListView.builder(
        controller: controller,
        padding: padding,
        itemCount: itemCount,
        shrinkWrap: shrinkWrap,
        physics: physics ?? _getOptimalPhysics(),
        primary: primary,
        scrollDirection: scrollDirection,
        reverse: reverse,
        dragStartBehavior: dragStartBehavior,
        clipBehavior: clipBehavior,
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        cacheExtent: cacheExtent ?? 500.0,
        itemExtent: itemExtent,
        prototypeItem: prototypeItem,
        addRepaintBoundaries: true, // Force for web
        addAutomaticKeepAlives: false, // Reduce memory on web
        addSemanticIndexes: false, // Disable for web performance
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: itemBuilder(context, index),
          );
        },
      );
    }
    
    // Native optimized ListView
    if (separatorBuilder != null) {
      return ListView.separated(
        controller: controller,
        padding: padding,
        itemCount: itemCount,
        shrinkWrap: shrinkWrap,
        physics: physics,
        primary: primary,
        scrollDirection: scrollDirection,
        reverse: reverse,
        dragStartBehavior: dragStartBehavior,
        clipBehavior: clipBehavior,
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        cacheExtent: cacheExtent,
        addRepaintBoundaries: addRepaintBoundaries,
        addAutomaticKeepAlives: addAutomaticKeepAlives,
        addSemanticIndexes: addSemanticIndexes,
        separatorBuilder: separatorBuilder!,
        itemBuilder: itemBuilder,
      );
    }
    
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      physics: physics,
      primary: primary,
      scrollDirection: scrollDirection,
      reverse: reverse,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      cacheExtent: cacheExtent,
      itemExtent: itemExtent,
      prototypeItem: prototypeItem,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addSemanticIndexes: addSemanticIndexes,
      itemBuilder: itemBuilder,
    );
  }
  
  ScrollPhysics _getOptimalPhysics() {
    if (physics != null) return physics!;
    
    // Use BouncingScrollPhysics for better web feel
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class OptimizedGridView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final double? cacheExtent;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool primary;
  final Axis scrollDirection;
  final bool reverse;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;
  final bool addSemanticIndexes;
  
  const OptimizedGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.cacheExtent,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.primary = true,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.addSemanticIndexes = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web-optimized GridView
      return GridView.builder(
        controller: controller,
        padding: padding,
        itemCount: itemCount,
        shrinkWrap: shrinkWrap,
        physics: physics ?? _getOptimalPhysics(),
        primary: primary,
        scrollDirection: scrollDirection,
        reverse: reverse,
        dragStartBehavior: dragStartBehavior,
        clipBehavior: clipBehavior,
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        gridDelegate: gridDelegate,
        cacheExtent: cacheExtent ?? 500.0,
        addRepaintBoundaries: true, // Force for web
        addAutomaticKeepAlives: false, // Reduce memory on web
        addSemanticIndexes: false, // Disable for web performance
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: itemBuilder(context, index),
          );
        },
      );
    }
    
    // Native optimized GridView
    return GridView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      physics: physics,
      primary: primary,
      scrollDirection: scrollDirection,
      reverse: reverse,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      gridDelegate: gridDelegate,
      cacheExtent: cacheExtent,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addSemanticIndexes: addSemanticIndexes,
      itemBuilder: itemBuilder,
    );
  }
  
  ScrollPhysics _getOptimalPhysics() {
    if (physics != null) return physics!;
    
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

// Extension for GridView.count
class OptimizedGridViewCount extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final double? cacheExtent;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool primary;
  final Axis scrollDirection;
  final bool reverse;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;
  final bool addSemanticIndexes;
  
  const OptimizedGridViewCount({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.crossAxisCount,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.cacheExtent,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.primary = true,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.addSemanticIndexes = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return OptimizedGridView(
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: itemBuilder,
      cacheExtent: cacheExtent,
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      primary: primary,
      scrollDirection: scrollDirection,
      reverse: reverse,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addSemanticIndexes: addSemanticIndexes,
    );
  }
}

// Extension for GridView.extent
class OptimizedGridViewExtent extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final double? cacheExtent;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool primary;
  final Axis scrollDirection;
  final bool reverse;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;
  final bool addSemanticIndexes;
  
  const OptimizedGridViewExtent({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.cacheExtent,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.primary = true,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.addSemanticIndexes = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return OptimizedGridView(
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: itemBuilder,
      cacheExtent: cacheExtent,
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      primary: primary,
      scrollDirection: scrollDirection,
      reverse: reverse,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addSemanticIndexes: addSemanticIndexes,
    );
  }
}

// Optimized SingleChildScrollView for web
class OptimizedSingleChildScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool reverse;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool primary;
  
  const OptimizedSingleChildScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.primary = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web-optimized SingleChildScrollView
      return SingleChildScrollView(
        controller: controller,
        padding: padding,
        physics: physics ?? const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        scrollDirection: scrollDirection,
        reverse: reverse,
        dragStartBehavior: dragStartBehavior,
        clipBehavior: clipBehavior,
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        primary: primary,
        child: RepaintBoundary(child: child),
      );
    }
    
    return SingleChildScrollView(
      controller: controller,
      padding: padding,
      physics: physics,
      scrollDirection: scrollDirection,
      reverse: reverse,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      primary: primary,
      child: child,
    );
  }
}

// CustomScrollView optimized for web
class OptimizedCustomScrollView extends StatelessWidget {
  final List<Widget> slivers;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool reverse;
  final bool primary;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final double? cacheExtent;
  final int? semanticChildCount;
  
  const OptimizedCustomScrollView({
    super.key,
    required this.slivers,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary = true,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.cacheExtent,
    this.semanticChildCount,
  });
  
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return CustomScrollView(
        controller: controller,
        shrinkWrap: shrinkWrap,
        physics: physics ?? const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        scrollDirection: scrollDirection,
        reverse: reverse,
        primary: primary,
        dragStartBehavior: dragStartBehavior,
        clipBehavior: clipBehavior,
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        cacheExtent: cacheExtent ?? 500.0,
        semanticChildCount: semanticChildCount,
        slivers: slivers.map((sliver) {
          // Wrap each sliver in a RepaintBoundary for better performance
          return RepaintBoundary(child: sliver);
        }).toList(),
      );
    }
    
    return CustomScrollView(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      scrollDirection: scrollDirection,
      reverse: reverse,
      primary: primary,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      cacheExtent: cacheExtent,
      semanticChildCount: semanticChildCount,
      slivers: slivers,
    );
  }
}