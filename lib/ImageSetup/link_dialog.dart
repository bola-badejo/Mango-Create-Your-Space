
import 'package:flutter/material.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class LinkDialog extends StatefulWidget {
  const LinkDialog({super.key});

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _commonTypes = [
    'website',
    'article',
    'video',
    'music',
    'product',
    'event',
    'other'
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Link',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a URL';
                  }
                  if (!_isValidUrl(value)) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              
              DropdownButtonFormField<String>(
                value: _typeController.text.isEmpty ? null : _typeController.text,
                decoration: const InputDecoration(
                  labelText: 'Link Type',
                  border: OutlineInputBorder(),
                ),
                items: _commonTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type[0].toUpperCase() + type.substring(1)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _typeController.text = value ?? 'website';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a link type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addLink,
                    child: const Text('Add Link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidUrl(String url) {
    final urlRegex = RegExp(
      r'^(https?://)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*/?$',
      caseSensitive: false,
    );
    return urlRegex.hasMatch(url);
  }

  void _addLink() {
    if (_formKey.currentState!.validate()) {
      String url = _urlController.text.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      
      Navigator.pop(context, {
        'url': url,
        'type': _typeController.text.isEmpty ? 'website' : _typeController.text,
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _typeController.dispose();
    super.dispose();
  }
}