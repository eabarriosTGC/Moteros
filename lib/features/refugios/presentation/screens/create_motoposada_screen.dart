/// Create Motoposada Screen — ofrecer casa/parqueadero a la comunidad.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/map_picker_screen.dart';
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
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  String _type = 'casa';
  String _visibility = 'public';
  int _maxGuests = 1;
  double _lat = 4.60971;
  double _lng = -74.08175;
  String _locationLabel = 'Seleccionar en el mapa';
  bool _isTourist = false;

  final _types = ['casa', 'parqueadero', 'garage'];
  final _visibilities = ['public', 'clan_only', 'clan_specific'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    if (_isTourist) {
      context.read<MotoposadasBloc>().add(CreateTouristPoi(
        type: _type,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        rules: _rulesController.text.trim(),
        lat: _lat,
        lng: _lng,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
      ));
    } else {
      context.read<MotoposadasBloc>().add(CreateMotoposada(
        type: _type,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        rules: _rulesController.text.trim(),
        lat: _lat,
        lng: _lng,
        address: _addressController.text.trim(),
        maxGuests: _maxGuests,
        visibility: _visibility,
      ));
    }
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
        if (state is TouristPoiCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Lugar turístico creado'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true);
        }
        if (state is TouristPoiForbidden) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⛔ No tienes permisos de curador para esta ciudad'), backgroundColor: AppColors.error),
          );
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
                      _label('UBICACIÓN'),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push<List<double>>(
                              context,
                              MaterialPageRoute(builder: (_) => MapPickerScreen(
                                initialLat: _lat,
                                initialLng: _lng,
                              )),
                            );
                            if (result != null && result.length == 2) {
                              setState(() {
                                _lat = result[0];
                                _lng = result[1];
                                _locationLabel = '${result[0].toStringAsFixed(5)}, ${result[1].toStringAsFixed(5)}';
                              });
                            }
                          },
                          icon: const Icon(Icons.map, color: AppColors.primary),
                          label: Text(_locationLabel,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ])),
                  ]),
                  const SizedBox(height: AppSpacing.lg),

                  _label('DIRECCIÓN'),
                  const SizedBox(height: AppSpacing.sm),
                  _input(_addressController, 'Dirección amigable', Icons.location_on_outlined),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Tourist POI toggle ──
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text('¿Es un lugar de visita obligada?',
                          style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
                      ),
                      Switch(
                        value: _isTourist,
                        activeColor: AppColors.warning,
                        onChanged: (v) => setState(() => _isTourist = v),
                      ),
                    ],
                  ),
                  if (_isTourist) ...[
                    const SizedBox(height: AppSpacing.md),
                    _label('CIUDAD'),
                    const SizedBox(height: AppSpacing.sm),
                    _input(_cityController, 'Ej: Bogotá, Medellín...', Icons.location_city_outlined),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const SizedBox(height: AppSpacing.sm),

                  if (!_isTourist) ...[
                    _label('MÁXIMO HUÉSPEDES'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildStepper(),
                    const SizedBox(height: AppSpacing.lg),

                    _label('VISIBILIDAD'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildToggle(_visibilities, _visibility, (v) => setState(() => _visibility = v)),
                    const SizedBox(height: AppSpacing.lg),
                  ],

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
