import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(LoadAllies());
  }

  void _onAllyCreated() {
    setState(() => _showForm = false);
    context.read<AdminBloc>().add(LoadAllies());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        if (state is AllyCreated) _onAllyCreated();
        if (state is AdminError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Panel Admin'),
          actions: [
            IconButton(
              icon: Icon(_showForm ? Icons.list : Icons.add),
              tooltip: _showForm ? 'Ver aliados' : 'Nuevo aliado',
              onPressed: () => setState(() => _showForm = !_showForm),
            ),
          ],
        ),
        body: _showForm ? _buildCreateForm() : _buildAllyList(),
      ),
    );
  }

  Widget _buildAllyList() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (state is AlliesLoaded) {
          if (state.allies.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No hay aliados registrados',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.allies.length,
            itemBuilder: (context, index) {
              final ally = state.allies[index];
              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Icon(_iconForCategory(ally.category),
                        color: AppColors.primary),
                  ),
                  title: Text(ally.businessName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(ally.category.toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 12)),
                      if (ally.benefit != null && ally.benefit!.isNotEmpty)
                        Text(ally.benefit!,
                            style:
                                const TextStyle(color: Colors.white54, fontSize: 13)),
                      if (ally.address != null)
                        Text(ally.address!,
                            style:
                                const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                ),
              );
            },
          );
        }
        if (state is AdminError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.message,
                    style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.read<AdminBloc>().add(LoadAllies()),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCreateForm() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final benefitCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final webCtrl = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nuevo aliado',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildField('Nombre del negocio *', nameCtrl),
          _buildField('Categoria (taller, restaurante, hotel...) *', catCtrl),
          _buildField('Descripcion', descCtrl, maxLines: 3),
          _buildField('Beneficio para miembros', benefitCtrl, maxLines: 2),
          _buildField('Direccion', addressCtrl),
          _buildField('Telefono', phoneCtrl),
          _buildField('Sitio web', webCtrl),
          const SizedBox(height: 24),
          BlocBuilder<AdminBloc, AdminState>(
            builder: (context, state) {
              final isLoading = state is AdminLoading;
              return ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        if (nameCtrl.text.isEmpty || catCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Nombre y categoria son obligatorios')),
                          );
                          return;
                        }
                        context.read<AdminBloc>().add(CreateAlly(
                              businessName: nameCtrl.text.trim(),
                              category: catCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              benefit: benefitCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              website: webCtrl.text.trim(),
                            ));
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Crear aliado'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    return switch (category.toLowerCase()) {
      'taller' => Icons.build,
      'restaurante' => Icons.restaurant,
      'hotel' || 'moto_posada' => Icons.hotel,
      'grua' => Icons.local_shipping,
      _ => Icons.business,
    };
  }
}
