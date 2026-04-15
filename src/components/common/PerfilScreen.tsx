/**
 * PerfilScreen - User profile with stats, membership, and QR code.
 */
import React from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { Icon } from '../ui/Icons';
import { AnimatedView } from '../ui/AnimatedView';
import { colors, spacing, fontSize, borderRadius } from '../../styles/theme';

const stats = [
  { label: 'Lugares Visitados', value: '12', icon: 'MapPin' as const },
  { label: 'Reseñas', value: '8', icon: 'Star' as const },
  { label: 'Km Recorridos', value: '2,450', icon: 'Trophy' as const },
  { label: 'Retos Completados', value: '15', icon: 'Trophy' as const },
];

const menuItems = [
  { label: 'Mis Visitas', icon: 'MapPin' as const },
  { label: 'Mis Fotos', icon: 'Camera' as const },
  { label: 'Configuración', icon: 'Settings' as const },
  { label: 'Cerrar Sesión', icon: 'LogOut' as const, danger: true },
];

export function PerfilScreen() {
  return (
    <View style={s.container}>
      {/* Header Gradient */}
      <View style={s.headerGradient}>
        <View style={s.profileSection}>
          <View style={s.profileAvatar}>
            <Text style={s.profileAvatarText}>JD</Text>
          </View>
          <Text style={s.profileName}>Juan Díaz</Text>
          <View style={s.memberSince}>
            <Icon name="Calendar" size={16} color="rgba(255,255,255,0.9)" />
            <Text style={s.memberSinceText}>Miembro desde Mar 2024</Text>
          </View>
        </View>
      </View>

      <ScrollView style={s.scroll} showsVerticalScrollIndicator={false}>
        <View style={s.content}>
          {/* Membership Card */}
          <AnimatedView type="slideUp" delay={0}>
            <View style={s.membershipCard}>
              <View style={s.membershipHeader}>
                <View style={s.membershipLeft}>
                  <Icon name="Crown" size={20} color={colors.amber[500]} />
                  <Text style={s.membershipTitle}>Plan Premium</Text>
                </View>
                <Text style={s.membershipDate}>Vence: 15 Dic 2024</Text>
              </View>
              <Text style={s.membershipDesc}>
                Acceso completo a todos los lugares y beneficios exclusivos
              </Text>
              <TouchableOpacity style={s.renewBtn}>
                <Text style={s.renewBtnText}>Renovar Membresía</Text>
              </TouchableOpacity>
            </View>
          </AnimatedView>

          {/* Stats Grid */}
          <View style={s.statsGrid}>
            {stats.map((stat, idx) => (
              <AnimatedView key={stat.label} type="scale" delay={100 + idx * 50}>
                <View style={s.statCard}>
                  <Icon name={stat.icon} size={20} color={colors.amber[500]} />
                  <Text style={s.statValue}>{stat.value}</Text>
                  <Text style={s.statLabel}>{stat.label}</Text>
                </View>
              </AnimatedView>
            ))}
          </View>

          {/* QR Code Section */}
          <AnimatedView type="slideUp" delay={300}>
            <View style={s.qrSection}>
              <View style={s.qrHeader}>
                <Text style={s.qrTitle}>Mi Código de Miembro</Text>
                <Icon name="QrCode" size={20} color={colors.amber[500]} />
              </View>
              <View style={s.qrBox}>
                <View style={s.qrPlaceholder}>
                  <Icon name="QrCode" size={64} color={colors.gray[600]} />
                </View>
              </View>
              <Text style={s.qrHint}>Muestra este código para registrar tus visitas</Text>
            </View>
          </AnimatedView>

          {/* Menu Items */}
          <View style={s.menuList}>
            {menuItems.map((item, idx) => (
              <AnimatedView key={item.label} type="slideRight" delay={400 + idx * 50}>
                <TouchableOpacity style={[s.menuItem, item.danger && s.menuItemDanger]}>
                  <View style={s.menuLeft}>
                    <Icon name={item.icon} size={20} color={item.danger ? colors.red[500] : colors.gray[400]} />
                    <Text style={[s.menuLabel, item.danger && s.menuLabelDanger]}>
                      {item.label}
                    </Text>
                  </View>
                  <Icon name="ChevronRight" size={20} color={item.danger ? colors.red[500] : colors.gray[600]} />
                </TouchableOpacity>
              </AnimatedView>
            ))}
          </View>
        </View>
      </ScrollView>
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.gray[900] },
  headerGradient: { paddingHorizontal: spacing.lg, paddingTop: 50, paddingBottom: 80, backgroundColor: colors.amber[600] },
  profileSection: { alignItems: 'center' },
  profileAvatar: { width: 96, height: 96, borderRadius: borderRadius.full, backgroundColor: colors.white, alignItems: 'center', justifyContent: 'center', marginBottom: spacing.md, borderWidth: 4, borderColor: 'rgba(255,255,255,0.3)' },
  profileAvatarText: { color: colors.gray[800], fontWeight: 'bold', fontSize: fontSize['3xl'] },
  profileName: { color: colors.white, fontSize: fontSize.xl, fontWeight: 'bold' },
  memberSince: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 4 },
  memberSinceText: { color: 'rgba(255,255,255,0.9)', fontSize: fontSize.sm },
  scroll: { flex: 1, paddingHorizontal: spacing.lg },
  content: { marginTop: -48, gap: spacing['2xl'], paddingBottom: spacing['2xl'] },
  membershipCard: { backgroundColor: colors.gray[800], borderRadius: borderRadius.xl, padding: spacing.lg, borderWidth: 1, borderColor: 'rgba(245,158,11,0.3)' },
  membershipHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.md },
  membershipLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  membershipTitle: { color: colors.white, fontWeight: '600' },
  membershipDate: { fontSize: fontSize.xs, color: colors.gray[400] },
  membershipDesc: { color: colors.gray[400], fontSize: fontSize.sm, marginBottom: spacing.md },
  renewBtn: { width: '100%', paddingVertical: 10, backgroundColor: colors.amber[500], borderRadius: borderRadius.lg },
  renewBtnText: { color: colors.white, fontWeight: '500', fontSize: fontSize.sm, textAlign: 'center' },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', gap: spacing.md },
  statCard: { width: '48%', backgroundColor: colors.gray[800], borderRadius: borderRadius.xl, padding: spacing.lg, borderWidth: 1, borderColor: colors.gray[700] },
  statValue: { fontSize: fontSize['2xl'], fontWeight: 'bold', color: colors.white, marginVertical: 4 },
  statLabel: { fontSize: fontSize.xs, color: colors.gray[400] },
  qrSection: { backgroundColor: colors.gray[800], borderRadius: borderRadius.xl, padding: spacing.lg, borderWidth: 1, borderColor: colors.gray[700] },
  qrHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.md },
  qrTitle: { color: colors.white, fontWeight: '600' },
  qrBox: { backgroundColor: colors.white, borderRadius: borderRadius.lg, padding: spacing.lg, alignItems: 'center', justifyContent: 'center' },
  qrPlaceholder: { width: 128, height: 128, backgroundColor: colors.gray[200], borderRadius: borderRadius.lg, alignItems: 'center', justifyContent: 'center' },
  qrHint: { color: colors.gray[400], fontSize: fontSize.xs, textAlign: 'center', marginTop: spacing.md },
  menuList: { gap: spacing.sm },
  menuItem: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.gray[800], borderRadius: borderRadius.xl, padding: spacing.lg, borderWidth: 1, borderColor: colors.gray[700] },
  menuItemDanger: { borderColor: 'rgba(239,68,68,0.5)' },
  menuLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  menuLabel: { color: colors.white, fontWeight: '500' },
  menuLabelDanger: { color: colors.red[500] },
});

export default PerfilScreen;
