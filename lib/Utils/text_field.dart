import 'package:flutter/material.dart';




class CustomTextField extends StatefulWidget {
  final String? placeholder;
  final Widget? leading;
  final Widget? suffix;
  final bool isPassword;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final String? errorText;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    this.placeholder,
    this.leading,
    this.suffix,
    this.isPassword = false,
    this.controller,
    this.onChanged,
    this.autofocus = false,
    this.keyboardType,
    this.validator,
    this.enabled = true,
    this.errorText,
    this.focusNode,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isFocused = false;
  bool _obscureText = true;
  late FocusNode _focusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _errorText = widget.errorText;
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != oldWidget.errorText) {
      setState(() => _errorText = widget.errorText);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() => _isFocused = _focusNode.hasFocus);

  String? _validate(String? value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() => _errorText = error);
      return error;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = _errorText != null && _errorText!.isNotEmpty;

    final borderColor = hasError
        ? theme.colorScheme.error
        : _isFocused
            ? theme.colorScheme.primary
            : theme.dividerColor;

    final backgroundColor = _isFocused
        ? theme.colorScheme.surfaceVariant
        : theme.colorScheme.surface;

    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final hintColor = theme.hintColor;
    final iconColor = theme.iconTheme.color ?? Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: hasError ? 2 : 1),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                const SizedBox(width: 12),
                widget.leading!,
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  onChanged: (value) {
                    _validate(value);
                    widget.onChanged?.call(value);
                  },
                  obscureText: widget.isPassword && _obscureText,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  enabled: widget.enabled,
                  focusNode: _focusNode,
                  validator: _validate,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: TextStyle(color: hintColor),
                    contentPadding: EdgeInsets.zero,
                    isCollapsed: true,
                    errorText: null,
                  ),
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 8),
                widget.suffix!,
                const SizedBox(width: 12),
              ] else if (widget.isPassword) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                    color: iconColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 16),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              _errorText!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}




class CustomMultilineTextField extends StatefulWidget {
  final String? placeholder;
  final Widget? leading;
  final Widget? suffix;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final double? height;
  final String? Function(String?)? validator;
  final bool enabled;
  final String? errorText;
  final FocusNode? focusNode;

  const CustomMultilineTextField({
    super.key,
    this.placeholder,
    this.leading,
    this.suffix,
    this.controller,
    this.onChanged,
    this.autofocus = false,
    this.maxLines,
    this.minLines,
    this.height,
    this.validator,
    this.enabled = true,
    this.errorText,
    this.focusNode,
  });

  @override
  State<CustomMultilineTextField> createState() =>
      _CustomMultilineTextFieldState();
}

class _CustomMultilineTextFieldState extends State<CustomMultilineTextField> {
  bool _isFocused = false;
  late FocusNode _focusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _errorText = widget.errorText;
  }

  @override
  void didUpdateWidget(covariant CustomMultilineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != oldWidget.errorText) {
      setState(() => _errorText = widget.errorText);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() => _isFocused = _focusNode.hasFocus);

  String? _validate(String? value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() => _errorText = error);
      return error;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = _errorText != null && _errorText!.isNotEmpty;

    final borderColor = hasError
        ? theme.colorScheme.error
        : _isFocused
            ? theme.colorScheme.primary
            : theme.dividerColor;

    final backgroundColor = _isFocused
        ? theme.colorScheme.surfaceVariant
        : theme.colorScheme.surface;

    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final hintColor = theme.hintColor;
    final iconColor = theme.iconTheme.color ?? Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: widget.height ?? 120,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: hasError ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.leading != null) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: widget.leading!,
                ),
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextFormField(
                    controller: widget.controller,
                    onChanged: (value) {
                      _validate(value);
                      widget.onChanged?.call(value);
                    },
                    autofocus: widget.autofocus,
                    maxLines: widget.maxLines ?? 5,
                    minLines: widget.minLines ?? 3,
                    enabled: widget.enabled,
                    focusNode: _focusNode,
                    validator: _validate,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: widget.placeholder,
                      hintStyle: TextStyle(color: hintColor),
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                      alignLabelWithHint: true,
                      errorText: null,
                    ),
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: widget.suffix!,
                ),
                const SizedBox(width: 12),
              ] else
                const SizedBox(width: 16),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              _errorText!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}




class CustomDropdown<T> extends StatefulWidget {
  final String? placeholder;
  final Widget? leading;
  final Widget? suffix;
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;
  final String? Function(T?)? validator;
  final bool enabled;
  final String? errorText;

  const CustomDropdown({
    super.key,
    this.placeholder,
    this.leading,
    this.suffix,
    this.value,
    this.items,
    this.onChanged,
    this.isExpanded = true,
    this.validator,
    this.enabled = true,
    this.errorText,
  });

  @override
  State<CustomDropdown> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>> {
  bool _isFocused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _errorText = widget.errorText;
  }

  @override
  void didUpdateWidget(covariant CustomDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != oldWidget.errorText) {
      setState(() => _errorText = widget.errorText);
    }
  }

  String? _validate(T? value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() => _errorText = error);
      return error;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = _errorText != null && _errorText!.isNotEmpty;

    final borderColor = hasError
        ? theme.colorScheme.error
        : _isFocused
            ? theme.colorScheme.primary
            : theme.dividerColor;

    final backgroundColor = _isFocused
        ? theme.colorScheme.surfaceVariant
        : theme.colorScheme.surface;

    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final hintColor = theme.hintColor;
    final iconColor = theme.iconTheme.color ?? Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: hasError ? 2 : 1),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                const SizedBox(width: 12),
                widget.leading!,
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<T>(
                    value: widget.value,
                    items: widget.items,
                    onChanged: widget.enabled
                        ? (T? newValue) {
                            _validate(newValue);
                            widget.onChanged?.call(newValue);
                          }
                        : null,
                    isExpanded: widget.isExpanded,
                    validator: _validate,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                      errorText: null,
                    ),
                    hint: widget.placeholder != null
                        ? Text(
                            widget.placeholder!,
                            style: TextStyle(color: hintColor, fontSize: 16),
                          )
                        : null,
                    icon: widget.suffix ??
                        Icon(Icons.arrow_drop_down,
                            color: widget.enabled ? iconColor : hintColor),
                    style: TextStyle(color: textColor, fontSize: 16),
                    onTap: () => setState(() => _isFocused = true),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              _errorText!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
