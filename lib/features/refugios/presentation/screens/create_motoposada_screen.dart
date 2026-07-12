/// Create Motoposada Screen — ofrecer casa/parqueadero a la comunidad.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../bloc/motoposadas_bloc.dart';
import '../bloc/motoposadas_event.dart';
import '../bloc/motoposadas_state.dart';

class CreateMotoposadaScreen extends StatefulWidget {
  const CreateMotoposadaScreen({super.key});

  @override
  State<CreateMotoposadaScreen> createState() => _CreateMotoposadaScreenState();
}

class _CreateMotoposadaScreenState extends State<CreateMotoposadaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rulesController = TextEditingController();
  final _latController = TextEditingController(text: '4.60971');
  final _lngController = TextEditingController(text: '-74.08175');
  final _addressController = TextEditingController();
  String _type = 'casa';
  String _visibility = 'public';
  int _maxGuests = 1;

  final _types = ['casa', 'parqueadero', 'garage'];
  final _visibilities = ['public', 'clan_only', 'clan_specific'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    context.read<MotoposadasBloc>().add(CreateMotoposada(
      type: _type,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      rules: _rulesController.text.trim(),
      lat: double.tryParse(_latController.text.trim()) ?? 4.60971,
      lng: double.tryParse(_lngController.text.trim()) ?? -74.08175,
      address: _addressController.text.trim(),
      maxGuests: _maxGuests,
      visibility: _visibility,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MotoposadasBloc, MotoposadasState>(
      listener: (context, state) {
        if (state is MotoposadaCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Motoposada creada'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true);
        }
        if (state is MotoposadasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('OFRECER ${_type.toUpperCase()}',
            style: AppTypography.h2.copyWith(color: AppColors.primary)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('TIPO'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildToggle(_types, _type, (v) => setState(() => _type = v)),
                  const SizedBox(height: AppSpacing.lg),

                  _label('TÍTULO'),
                  const SizedBox(height: AppSpacing.sm),
                  _input(_titleController, 'Ej: Casa en La Calera', Icons.home_outlined),
                  const SizedBox(height: AppSpacing.lg),

                  _label('DESCRIPCIÓN'),
                  const SizedBox(height: AppSpacing.sm),
                  _inputMultiline(_descController, 'Contanos sobre el espacio...'),
                  const SizedBox(height: AppSpacing.lg),

                  _label('REGLAS'),
                  const SizedBox(height: AppSpacing.sm),
                  _inputMultiline(_rulesController, 'Ej: No fumadores, horario de llegada...'),
                  const SizedBox(height: AppSpacing.lg),

                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('LATITUD'),
                      const SizedBox(height: AppSpacing.sm),
                      _input(_latController, '4.60971', Icons.my_location, small: true),
                    ])),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('LONGITUD'),
                      const SizedBox(height: AppSpacing.sm),
                      _input(_lngController, '-74.08175', Icons.my_location, small: true),
                    ])),
                  ]),
                  const SizedBox(height: AppSpacing.lg),

                  _label('DIRECCIÓN'),
                  const SizedBox(height: AppSpacing.sm),
                  _input(_addressController, 'Dirección amigable', Icons.location_on_outlined),
                  const SizedBox(height: AppSpacing.lg),

                  _label('MÁXIMO HUÉSPEDES'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStepper(),
                  const SizedBox(height: AppSpacing.lg),

                  _label('VISIBILIDAD'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildToggle(_visibilities, _visibility, (v) => setState(() => _visibility = v)),
                  const SizedBox(height: AppSpacing.lg),

                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                      ),
                      child: Text('PUBLICAR', style: AppTypography.button.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: AppTypography.caption.copyWith(
    color: AppColors.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.w600));

  Widget _input(TextEditingController c, String h, IconData ic, {bool small = false}) => Container(
    decoration: BoxDecoration(color: AppColors.input, borderRadius: AppRadius.mdCircular, border: Border.all(color: AppColors.border)),
    child: TextField(
      controller: c, style: AppTypography.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: h, hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
        prefixIcon: Icon(ic, color: AppColors.textMuted, size: AppSpacing.iconSm),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: small ? AppSpacing.sm : AppSpacing.md),
      ),
    ),
  );

  Widget _inputMultiline(TextEditingController c, String h) => Container(
    decoration: BoxDecoration(color: AppColors.input, borderRadius: AppRadius.mdCircular, border: Border.all(color: AppColors.border)),
    child: TextField(
      controller: c, maxLines: 3,
      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: h, hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
    ),
  );

  Widget _buildToggle(List<String> options, String current, ValueChanged<String> onChanged) => Wrap(
    spacing: AppSpacing.sm,
    children: options.map((o) => GestureDetector(
      onTap: () => onChanged(o),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: o == current ? AppColors.primary.withAlpha(20) : AppColors.input,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: o == current ? AppColors.primary : AppColors.border, width: o == current ? 1.5 : 1),
        ),
        child: Text(_visibilityLabel(o).toUpperCase(),
          style: AppTypography.buttonSmall.copyWith(
            color: o == current ? AppColors.primary : AppColors.textSecondary,
            fontWeight: o == current ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    )).toList(),
  );

  Widget _buildStepper() => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    decoration: BoxDecoration(color: AppColors.input, borderRadius: AppRadius.mdCircular, border: Border.all(color: AppColors.border)),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.remove, color: AppColors.primary),
        onPressed: _maxGuests > 1 ? () => setState(() => _maxGuests--) : null,
      ),
      Text('$_maxGuests', style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
      IconButton(
        icon: const Icon(Icons.add, color: AppColors.primary),
        onPressed: () => setState(() => _maxGuests++),
      ),
    ]),
  );

  String _visibilityLabel(String v) {
    switch (v) {
      case 'public': return 'Público';
      case 'clan_only': return 'Solo mi clan';
      case 'clan_specific': return 'Clan específico';
      default: return v;
    }
  }
}
