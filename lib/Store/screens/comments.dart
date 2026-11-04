import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';
import 'package:mango/Store/controller/product_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';

class ProductComments extends StatelessWidget {
  final String productId;

  const ProductComments({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final productController = Get.find<ProductController>();
    
    return Obx(() {
      final comments = productController.productComments;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(comments.length.toString()),
                  backgroundColor: Colors.orange.withOpacity(0.1),
                ),
              ],
            ),
          ),
          
          
          if (comments.isEmpty)
            _buildEmptyComments()
          else
            _buildCommentsList(comments, productController),
          
          
          _buildAddCommentButton(context, productController),
        ],
      );
    });
  }

  Widget _buildEmptyComments() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.comment,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to share your thoughts!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(List<ProductComment> comments, ProductController controller) {
    return OptimizedListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildCommentItem(comment, controller);
      },
    );
  }

  Widget _buildCommentItem(ProductComment comment, ProductController controller) {
    final isOwnComment = comment.userId == controller.currentUserId;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange,
                  child: Text(
                    comment.userEmail[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userEmail.split('@').first,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (comment.rating > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              comment.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(comment.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            
            
            const SizedBox(height: 8),
            Text(comment.text),
            
            
            const SizedBox(height: 8),
            Row(
              children: [
                
                InkWell(
                  onTap: () => controller.toggleCommentLike(comment.id),
                  child: Row(
                    children: [
                      Obx(() {
                        final isLiked = controller.isCommentLiked(comment);
                        return Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                          color: isLiked ? Colors.blue : Colors.grey,
                          size: 16,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        comment.likeCount.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                
                if (isOwnComment) ...[
                  InkWell(
                    onTap: () => _showEditCommentDialog(comment, controller),
                    child: const Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => _showDeleteCommentDialog(comment, controller),
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCommentButton(BuildContext context, ProductController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () => _showAddCommentDialog(context, controller),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
        icon: const Icon(Icons.add_comment),
        label: const Text('Add Comment'),
      ),
    );
  }

  void _showAddCommentDialog(BuildContext context, ProductController controller) {
    final textController = TextEditingController();
    double rating = 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            const Text('Rating (optional):'),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setState) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1.0;
                        });
                      },
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Your comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                controller.addComment(
                  textController.text.trim(),
                  context,
                  rating: rating,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Post Comment'),
          ),
        ],
      ),
    );
  }

  void _showEditCommentDialog(ProductComment comment, ProductController controller) {
    final textController = TextEditingController(text: comment.text);

    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Your comment',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                controller.updateComment(comment.id, textController.text.trim(), context);
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCommentDialog(ProductComment comment, ProductController controller) {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteComment(comment.id, context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}