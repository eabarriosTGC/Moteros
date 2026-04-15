/**
 * HomeScreen - Main home screen with destinations, activity, and membership status.
 */
import React from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  FlatList,
  StyleSheet,
} from 'react-native';
import { Icon } from '../ui/Icons';
import { AnimatedView } from '../ui/AnimatedView';
import { colors, spacing, fontSize, borderRadius } from '../../styles/theme';

const destinations = [
  { name: 'Guatapé', department: 'Antioquia', gradient: [colors.blue[500], colors.cyan[500]] },
  { name: 'Tatacoa', department: 'Huila', gradient: [colors.orange[500], colors.red[600]] },
  { name: 'Valle de Cocora', department: 'Quindío', gradient: [colors.green[500], colors.emerald[600]] },
  { name: 'Cabo de la Vela', department: 'La Guajira', gradient: [colors.yellow[500], colors.orange[600]] },
];

const activities = [
  { user: 'Carlos M.', action: 'visitó Caño Cristales', time: 'Hace 2 horas' },
  { user: 'Ana R.', action: 'completó reto en Tatacoa', time: 'Hace 5 horas' },
  { user: 'Miguel S.', action: 'recomendó Taller Motos Pro', time: 'Hace 1 día' },
];

export function HomeScreen() {
  return (
    <View style={s.container}>
      {/* Header */}
      <View style={s.header}>
        <View style={s.headerRow}>
          <View>
            <Text style={s.headerTitle}>RUTA COLOMBIA MC</Text>
            <Text style={s.headerSubtitle}>Tu aventura en dos ruedas</Text>
          </View>
          <TouchableOpacity style={s.bellBtn}>
            <Icon name="Bell" size={20} color={colors.gray[300]} />
            <View style={s.bellDot} />
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView style={s.scroll} showsVerticalScrollIndicator={false}>
        {/* Hero Banner */}
        <AnimatedView type="slideUp" delay={0}>
          <View style={s.hero}>
            <View style={s.heroOverlay} />
            <View style={s.heroContent}>
              <Text style={s.heroTitle}>Descubre Colombia</Text>
              <Text style={s.heroSubtitle}>En cada curva, una nueva historia</Text>
            </View>
          </View>
        </AnimatedView>

        {/* Membership Status */}
        <AnimatedView type="slideUp" delay={100}>
          <View style={s.membership}>
            <View style={s.membershipHeader}>
              <View style={s.membershipStatus}>
                <View style={s.statusDot} />
                <Text style={s.membershipText}>Miembro Activo</Text>
              </View>
              <Text style={s.membershipDate}>Vence: 15 Dic 2024</Text>
            </View>
            <View style={s.statsRow}>
              <View style={s.statItem}>
                <Text style={s.statValue}>12</Text>
                <Text style={s.statLabel}>Lugares</Text>
              </View>
              <View style={s.statItem}>
                <Text style={s.statValue}>2,450</Text>
                <Text style={s.statLabel}>KM</Text>
              </View>
              <View style={s.statItem}>
                <Text style={s.statValue}>8m</Text>
                <Text style={s.statLabel}>Miembro</Text>
              </View>
            </View>
          </View>
        </AnimatedView>

        {/* Próximos Destinos */}
        <View style={s.section}>
          <View style={s.sectionHeader}>
            <Text style={s.sectionTitle}>Próximos Destinos</Text>
            <TouchableOpacity>
              <Text style={s.seeAll}>Ver todos</Text>
            </TouchableOpacity>
          </View>
          <FlatList
            data={destinations}
            horizontal
            showsHorizontalScrollIndicator={false}
            keyExtractor={(item) => item.name}
            renderItem={({ item, index }) => (
              <AnimatedView type="slideRight" delay={200 + index * 100}>
                <View style={s.destCard}>
                  <View style={[s.destImage, { backgroundColor: item.gradient[0] }]}>
                    <View style={s.destLabel}>
                      <Text style={s.destName}>{item.name}</Text>
                      <Text style={s.destDept}>{item.department}</Text>
                    </View>
                  </View>
                </View>
              </AnimatedView>
            )}
          />
        </View>

        {/* Recent Activity */}
        <View style={s.section}>
          <Text style={s.sectionTitle}>Actividad Reciente</Text>
          <View style={s.activityList}>
            {activities.map((activity, idx) => (
              <AnimatedView key={idx} type="slideRight" delay={300 + idx * 100}>
                <View style={s.activityItem}>
                  <View style={s.activityAvatar}>
                    <Text style={s.activityAvatarText}>{activity.user.charAt(0)}</Text>
                  </View>
                  <View style={s.activityContent}>
                    <Text style={s.activityText}>
                      <Text style={s.activityUser}>{activity.user}</Text>{' '}
                      <Text style={s.activityAction}>{activity.action}</Text>
                    </Text>
                    <Text style={s.activityTime}>{activity.time}</Text>
                  </View>
                  <Icon name="ChevronRight" size={16} color={colors.gray[600]} />
                </View>
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
  header: { paddingHorizontal: spacing.lg, paddingTop: 50, paddingBottom: spacing.lg, backgroundColor: colors.gray[900], borderBottomWidth: 1, borderBottomColor: colors.gray[700] },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  headerTitle: { fontSize: fontSize.xl, fontWeight: 'bold', color: colors.white },
  headerSubtitle: { fontSize: fontSize.xs, color: colors.gray[400] },
  bellBtn: { padding: spacing.sm, borderRadius: borderRadius.full, backgroundColor: colors.gray[800] },
  bellDot: { position: 'absolute', top: 4, right: 4, width: 8, height: 8, backgroundColor: colors.amber[500], borderRadius: borderRadius.full },
  scroll: { flex: 1, paddingHorizontal: spacing.lg, paddingTop: spacing['2xl'] },
  hero: { height: 192, borderRadius: borderRadius['2xl'], overflow: 'hidden', marginBottom: spacing['2xl'], backgroundColor: colors.amber[600] },
  heroOverlay: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.3)' },
  heroContent: { flex: 1, justifyContent: 'flex-end', padding: spacing['2xl'] },
  heroTitle: { fontSize: fontSize['2xl'], fontWeight: 'bold', color: colors.white, marginBottom: 4 },
  heroSubtitle: { fontSize: fontSize.sm, color: 'rgba(255,255,255,0.9)' },
  membership: { backgroundColor: 'rgba(245,158,11,0.1)', borderWidth: 1, borderColor: 'rgba(245,158,11,0.3)', borderRadius: borderRadius.xl, padding: spacing.lg, marginBottom: spacing['2xl'] },
  membershipHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.md },
  membershipStatus: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  statusDot: { width: 8, height: 8, backgroundColor: colors.green[500], borderRadius: borderRadius.full },
  membershipText: { fontSize: fontSize.sm, fontWeight: '600', color: colors.amber[500] },
  membershipDate: { fontSize: fontSize.xs, color: colors.gray[400] },
  statsRow: { flexDirection: 'row', justifyContent: 'space-around' },
  statItem: { alignItems: 'center' },
  statValue: { fontSize: fontSize['2xl'], fontWeight: 'bold', color: colors.white },
  statLabel: { fontSize: fontSize.xs, color: colors.gray[400] },
  section: { marginBottom: spacing['2xl'] },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.lg },
  sectionTitle: { fontSize: fontSize.lg, fontWeight: 'bold', color: colors.white },
  seeAll: { fontSize: fontSize.sm, color: colors.amber[500] },
  destCard: { width: 160, marginRight: spacing.md },
  destImage: { height: 128, borderRadius: borderRadius.xl, justifyContent: 'flex-end', padding: spacing.md },
  destLabel: { backgroundColor: 'rgba(0,0,0,0.5)', borderRadius: borderRadius.sm, paddingHorizontal: spacing.sm, paddingVertical: 4 },
  destName: { color: colors.white, fontWeight: '600', fontSize: fontSize.sm },
  destDept: { color: 'rgba(255,255,255,0.8)', fontSize: fontSize.xs },
  activityList: { gap: spacing.md },
  activityItem: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, backgroundColor: colors.gray[800], borderRadius: borderRadius.lg, padding: spacing.md },
  activityAvatar: { width: 40, height: 40, borderRadius: borderRadius.full, backgroundColor: colors.amber[500], alignItems: 'center', justifyContent: 'center' },
  activityAvatarText: { color: colors.white, fontWeight: 'bold', fontSize: fontSize.sm },
  activityContent: { flex: 1 },
  activityText: { fontSize: fontSize.sm, color: colors.white },
  activityUser: { fontWeight: '600' },
  activityAction: { color: colors.gray[400] },
  activityTime: { fontSize: fontSize.xs, color: colors.gray[500] },
});

export default HomeScreen;
