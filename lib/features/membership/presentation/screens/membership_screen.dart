import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/membership_bloc.dart';
import '../bloc/membership_event.dart';
import '../bloc/membership_state.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MembershipBloc>().add(LoadMembership());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MembershipBloc, MembershipState>(
      builder: (context, state) {
        return switch (state) {
          MembershipInitial() || MembershipLoading() => _buildLoading(),
          NoMembership() => _buildPlans(),
          MembershipActive() => _buildActive(state),
          MembershipActivating() => _buildActivating(),
          MembershipError() => _buildError(state),
        };
      },
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      appBar: AppBar(title: const Text('Membresia')),
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildPlans() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Membresia')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Icon(Icons.workspace_premium,
                size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Elige tu plan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desbloquea beneficios exclusivos en talleres,\nrestaurantes y moto-posadas',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _PlanCard(
              plan: 'Basic',
              price: '\$29.900/mes',
              benefits: const [
                'Acceso a mapa de lugares',
                'Descuentos basicos en aliados',
                'Validacion de destinos',
                'Perfil de motero',
              ],
              isPopular: false,
              onTap: () => context
                  .read<MembershipBloc>()
                  .add(const ActivateMembership(plan: 'basic')),
            ),
            const SizedBox(height: 16),
            _PlanCard(
              plan: 'Premium',
              price: '\$49.900/mes',
              benefits: const [
                'Todo lo del plan Basic',
                'Descuentos premium en aliados',
                'Rutas exclusivas curadas',
                'Acceso anticipado a eventos',
                'Insignia Premium en perfil',
              ],
              isPopular: true,
              onTap: () => context
                  .read<MembershipBloc>()
                  .add(const ActivateMembership(plan: 'premium')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActive(MembershipActive state) {
    final m = state.membership;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Membresia')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.verified,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Plan ${m.plan.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.isActive ? 'Activo' : 'Expirado',
                    style: TextStyle(
                      color: m.isActive ? Colors.green : Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _InfoTile(Icons.calendar_today, 'Inicio',
                _formatDate(m.startDate)),
            _InfoTile(
                Icons.event, 'Vence', _formatDate(m.endDate)),
            _InfoTile(Icons.timer, 'Dias restantes',
                '${m.daysRemaining} dias'),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Beneficios activos',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  _BenefitItem('Descuentos en talleres aliados'),
                  _BenefitItem('Acceso a rutas exclusivas'),
                  _BenefitItem('Validacion de destinos'),
                  _BenefitItem('Perfil destacado'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivating() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Membresia')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 24),
            Text('Activando membresia...',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(MembershipError state) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Membresia')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    context.read<MembershipBloc>().add(LoadMembership()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _PlanCard extends StatelessWidget {
  final String plan;
  final String price;
  final List<String> benefits;
  final bool isPopular;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.price,
    required this.benefits,
    required this.isPopular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppColors.primary : Colors.white12,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('POPULAR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(price,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...benefits.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(b,
                                  style:
                                      const TextStyle(color: Colors.white70))),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular
                          ? AppColors.primary
                          : Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Suscribirse',
                      style: TextStyle(
                        color: isPopular ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;

  const _BenefitItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.star, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
