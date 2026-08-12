/// Create Motoposada Screen — ofrecer casa/parqueadero a la comunidad, y
/// casa_motero (F-M9): alias/descripción/capacidad/WhatsApp/disponible/
/// map-picker con jitter, disclaimer obligatorio, SIN address y SIN cédula.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/location/blur_coordinates.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/map_picker_screen.dart';
import '../../data/models/casa_motero_payload.dart';
import '../bloc/motoposadas_bloc.dart';
import '../bloc/motoposadas_event.dart';
import '../bloc/motoposadas_state.dart';
import 'my_motoposada_screen.dart';

/// Form mode: `standard` = casa/parqueadero/garage (+ tourist POI toggle);
/// `casaMotero` = casa de motero field set (M-CRUD-5) — no address, no
/// cédula (M-CRUD-4), disclaimer-gated create (M-CRUD-3).
enum CreateMotoposadaMode { standard, casaMotero }

class CreateMotoposadaScreen extends StatefulWidget {
  final CreateMotoposadaMode mode;
  final MotoposadaModel? existing;

  const CreateMotoposadaScreen({
    super.key,
    this.mode = CreateMotoposadaMode.standard,
    this.existing,
  });

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
  final _phoneController = TextEditingController();
  String _type = 'casa';
  String _visibility = 'public';
  int _maxGuests = 1;
  double _lat = 4.60971;
  double _lng = -74.08175;
  String _locationLabel = 'Seleccionar en el mapa';
  bool _isTourist = false;

  // ── Casa de motero (F-M9) ──
  bool _disclaimerAccepted = false;
  bool _isActive = true;
  double _latExact = 4.60971; // exact (private, owner-only table)
  double _lngExact = -74.08175;
  bool _detailsLoaded = false; // edit prefill (LoadCasaMoteroDetails)

  final _types = ['casa', 'parqueadero', 'garage'];
  final _visibilities = ['public', 'clan_only', 'clan_specific'];

  bool get _isCasaMotero => widget.mode == CreateMotoposadaMode.casaMotero;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isCasaMotero) {
      final existing = widget.existing;
      if (existing != null) {
        // Edit mode: public fields prefill; owner-only details (phone +
        // exact coords) arrive via LoadCasaMoteroDetails (reviewer fix).
        _titleController.text = existing.title;
        _descController.text = existing.description;
        _maxGuests = existing.maxGuests;
        _lat = existing.lat;
        _lng = existing.lng;
        _isActive = existing.isActive;
        context.read<MotoposadasBloc>().add(
          LoadCasaMoteroDetails(id: existing.id),
        );
      } else {
        // Create mode: max-1 UX pre-check (M-CRUD-1).
        context.read<MotoposadasBloc>().add(const CheckCasaMoteroEligibility());
      }
    } else if (_isEditing) {
      final existing = widget.existing!;
      _titleController.text = existing.title;
      _descController.text = existing.description;
      _rulesController.text = existing.rules;
      _addressController.text = existing.address;
      _type = existing.type;
      _visibility = existing.visibility;
      _maxGuests = existing.maxGuests;
      _lat = existing.lat;
      _lng = existing.lng;
      _locationLabel = existing.city?.trim().isNotEmpty == true
          ? existing.city!.trim()
          : 'Cambiar ubicación en el mapa';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    if (_isEditing) {
      final existing = widget.existing!;
      context.read<MotoposadasBloc>().add(
        UpdateMotoposada(
          id: existing.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          rules: _rulesController.text.trim(),
          lat: _lat,
          lng: _lng,
          address: _addressController.text.trim(),
          maxGuests: _maxGuests,
          visibility: _visibility,
          isActive: existing.isActive,
        ),
      );
    } else if (_isTourist) {
      context.read<MotoposadasBloc>().add(
        CreateTouristPoi(
          type: _type,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          rules: _rulesController.text.trim(),
          lat: _lat,
          lng: _lng,
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
        ),
      );
    } else {
      context.read<MotoposadasBloc>().add(
        CreateMotoposada(
          type: _type,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          rules: _rulesController.text.trim(),
          lat: _lat,
          lng: _lng,
          address: _addressController.text.trim(),
          maxGuests: _maxGuests,
          visibility: _visibility,
        ),
      );
    }
  }

  /// Casa de motero submit (F-M9): jitter exact → approx, normalize phone
  /// BEFORE dispatch (M-WA-1), disclaimer gating (M-CRUD-3), create via RPC
  /// event or edit via public + private update events (M-CRUD-2/5).
  void _submitCasaMotero() {
    if (!_formKey.currentState!.validate()) return;
    if (_isEditing && !_detailsLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavía cargando los datos de tu casa de motero…'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final phone = normalizePhoneDigits(_phoneController.text.trim());
    if (phone.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresá un número de WhatsApp válido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();

    // Jitter UX (M-MAPA-1): the exact pick never reaches the public row.
    final approx = blurCoordinates(_latExact, _lngExact);

    if (_isEditing) {
      final existing = widget.existing!;
      context.read<MotoposadasBloc>().add(
        UpdateCasaMotero(
          id: existing.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          maxGuests: _maxGuests,
          lat: approx.lat,
          lng: approx.lng,
          isActive: _isActive,
        ),
      );
      context.read<MotoposadasBloc>().add(
        UpdateCasaMoteroDetails(
          motoposadaId: existing.id,
          whatsappPhone: phone,
          latExact: _latExact,
          lngExact: _lngExact,
        ),
      );
    } else {
      context.read<MotoposadasBloc>().add(
        CreateCasaMotero(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          maxGuests: _maxGuests,
          lat: approx.lat,
          lng: approx.lng,
          latExact: _latExact,
          lngExact: _lngExact,
          whatsappPhone: phone,
          disclaimerAcceptedAt: _disclaimerAccepted ? DateTime.now() : null,
        ),
      );
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _isCasaMotero ? _latExact : _lat,
          initialLng: _isCasaMotero ? _lngExact : _lng,
        ),
      ),
    );
    if (result != null && result.length == 2) {
      setState(() {
        if (_isCasaMotero) {
          // Exact pick — the form jitters before submit (M-MAPA-1).
          _latExact = result[0];
          _lngExact = result[1];
          _lat = result[0];
          _lng = result[1];
          _locationLabel =
              '${result[0].toStringAsFixed(5)}, ${result[1].toStringAsFixed(5)}';
        } else {
          _lat = result[0];
          _lng = result[1];
          _locationLabel =
              '${result[0].toStringAsFixed(5)}, ${result[1].toStringAsFixed(5)}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MotoposadasBloc, MotoposadasState>(
      listener: (context, state) {
        if (state is MotoposadaCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Motoposada creada'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
        if (state is TouristPoiCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Lugar turístico creado'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
        if (state is TouristPoiForbidden) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⛔ No tienes permisos de curador para esta ciudad'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (state is MotoposadasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
        // ── Casa de motero (F-M9) ──
        if (state is CasaMoteroEligibilityLoaded) {
          // BlocBuilder body reacts to the same state for the blocked UI.
        }
        if (state is CasaMoteroDetailsLoaded) {
          setState(() {
            _phoneController.text = state.whatsappPhone;
            _latExact = state.latExact;
            _lngExact = state.lngExact;
            _detailsLoaded = true;
          });
        }
        if (state is CasaMoteroAlreadyExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya tienes una casa de motero publicada'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        if (state is MotoposadaUpdated && _isCasaMotero && _isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Cambios guardados'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
        if (state is MotoposadaUpdated && !_isCasaMotero && _isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Publicación actualizada'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _isCasaMotero
                ? (_isEditing
                      ? 'EDITAR CASA DE MOTERO'
                      : 'OFRECER CASA DE MOTERO')
                : (_isEditing
                      ? 'EDITAR ${_type.toUpperCase()}'
                      : 'OFRECER ${_type.toUpperCase()}'),
            style: AppTypography.h2.copyWith(color: AppColors.primary),
          ),
        ),
        body: SafeArea(
          child: _isCasaMotero && !_isEditing
              ? BlocBuilder<MotoposadasBloc, MotoposadasState>(
                  builder: (context, state) {
                    if (state is CasaMoteroEligibilityLoaded && state.has) {
                      return _buildEligibilityBlocked();
                    }
                    return _buildForm(context);
                  },
                )
              : _buildForm(context),
        ),
      ),
    );
  }

  /// Max-1 UX (M-CRUD-1): the user already owns a casa_motero — blocked UI
  /// with a link to My casa. The DB partial unique index is the real
  /// boundary; this is UX only.
  Widget _buildEligibilityBlocked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_work_outlined,
              size: 56,
              color: AppColors.secondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ya tenés una casa de motero publicada',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cada motero puede ofrecer una sola casa.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyMotoposadaScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
              ),
              child: const Text(
                'IR A MI CASA',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isCasaMotero) ...[
              // ── Casa de motero field set (M-CRUD-5) ──
              _label('TÍTULO'),
              const SizedBox(height: AppSpacing.sm),
              _input(
                _titleController,
                'Ej: Casa en La Calera',
                Icons.home_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('DESCRIPCIÓN'),
              const SizedBox(height: AppSpacing.sm),
              _inputMultiline(_descController, 'Contanos sobre el espacio...'),
              const SizedBox(height: AppSpacing.lg),

              _label('MÁXIMO HUÉSPEDES'),
              const SizedBox(height: AppSpacing.sm),
              _buildStepper(),
              const SizedBox(height: AppSpacing.lg),

              _label('WHATSAPP'),
              const SizedBox(height: AppSpacing.sm),
              _input(
                _phoneController,
                'Ej: +57 300 123 4567',
                Icons.chat_bubble_outline,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('UBICACIÓN'),
              const SizedBox(height: AppSpacing.sm),
              _buildMapPicker(),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'La ubicación se publica difuminada (aprox. 300–500 m) para '
                'proteger tu privacidad.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('DISPONIBLE'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isActive
                          ? 'Tu casa se muestra en el mapa'
                          : 'Tu casa queda oculta del mapa',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Disclaimer (M-CRUD-3): mandatory before the first insert.
              if (!_isEditing) ...[
                FormField<bool>(
                  initialValue: _disclaimerAccepted,
                  validator: (v) => v == true
                      ? null
                      : 'Debés aceptar el descargo de responsabilidad para publicar',
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        value: field.value ?? false,
                        onChanged: (v) {
                          field.didChange(v);
                          setState(() => _disclaimerAccepted = v ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Acepto el descargo de responsabilidad: mi ubicación '
                          'exacta se mantiene privada y se publica difuminada.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                            top: AppSpacing.xs,
                          ),
                          child: Text(
                            field.errorText!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ] else ...[
              // ── Standard field set (casa/parqueadero/garage + tourist) ──
              _label('TIPO'),
              const SizedBox(height: AppSpacing.sm),
              _buildToggle(_types, _type, (v) => setState(() => _type = v)),
              const SizedBox(height: AppSpacing.lg),

              _label('TÍTULO'),
              const SizedBox(height: AppSpacing.sm),
              _input(
                _titleController,
                'Ej: Casa en La Calera',
                Icons.home_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('DESCRIPCIÓN'),
              const SizedBox(height: AppSpacing.sm),
              _inputMultiline(_descController, 'Contanos sobre el espacio...'),
              const SizedBox(height: AppSpacing.lg),

              _label('REGLAS'),
              const SizedBox(height: AppSpacing.sm),
              _inputMultiline(
                _rulesController,
                'Ej: No fumadores, horario de llegada...',
              ),
              const SizedBox(height: AppSpacing.lg),

              _label('UBICACIÓN'),
              const SizedBox(height: AppSpacing.sm),
              _buildMapPicker(),
              const SizedBox(height: AppSpacing.lg),

              _label('DIRECCIÓN'),
              const SizedBox(height: AppSpacing.sm),
              _input(
                _addressController,
                'Dirección amigable',
                Icons.location_on_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Tourist POI toggle ──
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '¿Es un lugar de visita obligada?',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isTourist,
                    activeThumbColor: AppColors.warning,
                    onChanged: (v) => setState(() => _isTourist = v),
                  ),
                ],
              ),
              if (_isTourist) ...[
                const SizedBox(height: AppSpacing.md),
                _label('CIUDAD'),
                const SizedBox(height: AppSpacing.sm),
                _input(
                  _cityController,
                  'Ej: Bogotá, Medellín...',
                  Icons.location_city_outlined,
                ),
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
                _buildToggle(
                  _visibilities,
                  _visibility,
                  (v) => setState(() => _visibility = v),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],

            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: _isCasaMotero ? _submitCasaMotero : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnAmber,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdCircular,
                  ),
                ),
                child: Text(
                  _isCasaMotero && _isEditing ? 'GUARDAR' : 'PUBLICAR',
                  style: AppTypography.button.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPicker() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openMapPicker,
        icon: const Icon(Icons.map, color: AppColors.primary),
        label: Text(
          _locationLabel,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: AppTypography.caption.copyWith(
      color: AppColors.textMuted,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _input(
    TextEditingController c,
    String h,
    IconData ic, {
    bool small = false,
    TextInputType? keyboardType,
  }) => Container(
    decoration: BoxDecoration(
      color: AppColors.input,
      borderRadius: AppRadius.mdCircular,
      border: Border.all(color: AppColors.border),
    ),
    child: TextField(
      controller: c,
      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: h,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
        prefixIcon: Icon(
          ic,
          color: AppColors.textMuted,
          size: AppSpacing.iconSm,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: small ? AppSpacing.sm : AppSpacing.md,
        ),
      ),
    ),
  );

  Widget _inputMultiline(TextEditingController c, String h) => Container(
    decoration: BoxDecoration(
      color: AppColors.input,
      borderRadius: AppRadius.mdCircular,
      border: Border.all(color: AppColors.border),
    ),
    child: TextField(
      controller: c,
      maxLines: 3,
      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: h,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
    ),
  );

  Widget _buildToggle(
    List<String> options,
    String current,
    ValueChanged<String> onChanged,
  ) => Wrap(
    spacing: AppSpacing.sm,
    children: options
        .map(
          (o) => GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: o == current
                    ? AppColors.primary.withAlpha(20)
                    : AppColors.input,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(
                  color: o == current ? AppColors.primary : AppColors.border,
                  width: o == current ? 1.5 : 1,
                ),
              ),
              child: Text(
                _visibilityLabel(o).toUpperCase(),
                style: AppTypography.buttonSmall.copyWith(
                  color: o == current
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: o == current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        )
        .toList(),
  );

  Widget _buildStepper() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.input,
      borderRadius: AppRadius.mdCircular,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, color: AppColors.primary),
          onPressed: _maxGuests > 1 ? () => setState(() => _maxGuests--) : null,
        ),
        Text(
          '$_maxGuests',
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
        IconButton(
          icon: const Icon(Icons.add, color: AppColors.primary),
          onPressed: () => setState(() => _maxGuests++),
        ),
      ],
    ),
  );

  String _visibilityLabel(String v) {
    switch (v) {
      case 'public':
        return 'Público';
      case 'clan_only':
        return 'Solo mi clan';
      case 'clan_specific':
        return 'Clan específico';
      default:
        return v;
    }
  }
}
