/// Fields and buttons the account screens share. Emails, passwords and codes
/// read left to right in both languages, aligned to the start side; labels
/// sit above the fields; passwords live only in memory.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/raad_theme.dart';

TextAlign _startAlign(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? TextAlign.right
    : TextAlign.left;

class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      autofillHints: const [AutofillHints.email],
      textDirection: TextDirection.ltr,
      textAlign: _startAlign(context),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 3,
        prefixIcon: const Icon(
          Icons.alternate_email_rounded,
          color: RaadColors.textSecondary,
          size: 20,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.newPassword = false,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;

  /// Shown under the field before anything is typed, such as the rule.
  final String? helperText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// A password being chosen rather than recalled.
  final bool newPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textDirection: TextDirection.ltr,
      textAlign: _startAlign(context),
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 3,
        helperText: widget.errorText == null ? widget.helperText : null,
        helperMaxLines: 3,
        helperStyle: const TextStyle(color: RaadColors.textSecondary),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: RaadColors.textSecondary,
          size: 20,
        ),
        suffixIcon: IconButton(
          tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: RaadColors.textSecondary,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}

class CodeField extends StatelessWidget {
  const CodeField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.oneTimeCode],
      textDirection: TextDirection.ltr,
      textAlign: _startAlign(context),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 3,
        prefixIcon: const Icon(
          Icons.pin_outlined,
          color: RaadColors.textSecondary,
          size: 20,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// The one main action of a screen, with a spinner and a "…ing" label
/// while it runs; taps are ignored then.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: RaadColors.background,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Semantics(liveRegion: true, child: Text(busyLabel)),
                ),
              ],
            )
          : Text(label),
    );
  }
}
