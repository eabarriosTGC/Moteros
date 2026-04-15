/**
 * ComunidadScreen - Moto Posada and aspirants community screen.
 */
import React, { useState } from 'react';
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

type TabType = 'motoposada' | 'aspirantes';

const motoPosadas = [
  { host: 'Carlos Mendoza', location: 'Medellín, Antioquia', capacity: 2, available: 1, date: '15-20 Dic' },
  { host: 'Ana Rodríguez', location: 'Bogotá, Cundinamarca', capacity: 3, available: 3, date: '22-28 Dic' },
  { host: 'Miguel Santos', location: 'Cali, Valle del Cauca', capacity: 2, available: 0, date: '10-15 Ene' },
];

const aspirantes = [
  { name: 'Juan Pérez', status: 'En Reto', progress: 60, challenges: '3/5', date: 'Nov 2024' },
  { name: 'Laura Gómez', status: 'Pendiente', progress: 0, challenges: '0/5', date: 'Dic 2024' },
  { name: 'Diego Torres', status: 'Aprobado', progress: 100, challenges: '5/5', date: 'Oct 2024' },
];

const getStatusStyle = (status: string) => {
  switch (status) {
    case 'Aprobado': return { backgroundColor: 'rgba(34,197,94,0.2)', color: colors.green[500], borderColor: 'rgba(34,197,94,0.3)' };
    case 'En Reto': return { backgroundColor: 'rgba(245,158,11,0.2)', color: colors.amber[500], borderColor: 'rgba(245,158,11,0.3)' };
    default: return { backgroundColor: 'rgba(107,114,128,0.2)', color: colors.gray[400], borderColor: 'rgba(107,114,128,0.3)' };
  }
};

export function ComunidadScreen() {
  const [activeTab, setActiveTab] = useState<TabType>('motoposada');

  return (
    <View style={s.container}>
      {/* Header */}
      <View style={s.header}>
        <Text style={s.headerTitle}>Comunidad</Text>

        {/* Tabs */}
        <View style={s.tabRow}>
          <TouchableOpacity onPress={() => setActiveTab('motoposada')} style={[s.tab, activeTab === 'motoposada' && s.tabActive]}>
            <Text style={[s.tabText, activeTab === 'motoposada' && s.tabTextActive]}>Moto Posada</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => setActiveTab('aspirantes')} style={[s.tab, activeTab === 'aspirantes' && s.tabActive]}>
            <Text style={[s.tabText, activeTab === 'aspirantes' && s.tabTextActive]}>Aspirantes</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Content */}
      <ScrollView style={s.scroll} showsVerticalScrollIndicator={false}>
        {activeTab === 'motoposada' ? (
          <View style={s.list}>
            {motoPosadas.map((posada, idx) => (
              <AnimatedView key={posada.host} type="slideUp" delay={idx * 100}>
                <View style={s.card}>
                  <View style={s.hostRow}>
                    <View style={s.avatar}>
                      <Text style={s.avatarText}>{posada.host.charAt(0)}</Text>
                    </View>
                    <View style={s.hostInfo}>
                      <Text style={s.hostName}>{posada.host}</Text>
                      <View style={s.locationRow}>
                        <Icon name="MapPin" size={12} color={colors.gray[400]} />
                        <Text style={s.locationText}>{posada.location}</Text>
                      </View>
                    </View>
                  </View>

                  <View style={s.statsGrid}>
                    <View style={s.statBox}>
                      <Text style={s.statValue}>{posada.capacity}</Text>
                      <Text style={s.statLabel}>Capacidad</Text>
                    </View>
                    <View style={s.statBox}>
                      <Text style={[s.statValue, posada.available > 0 ? { color: colors.green[500] } : { color: colors.red[500] }]}>
                        {posada.available}
                      </Text>
                      <Text style={s.statLabel}>Disponible</Text>
                    </View>
                    <View style={s.statBox}>
                      <Text style={s.statValue}>{posada.date}</Text>
                      <Text style={s.statLabel}>Fechas</Text>
                    </View>
                  </View>

                  <TouchableOpacity
                    disabled={posada.available === 0}
                    style={[s.requestBtn, posada.available === 0 && s.requestBtnDisabled]}
                  >
                    <Text style={[s.requestBtnText, posada.available === 0 && s.requestBtnTextDisabled]}>
                      {posada.available > 0 ? 'Solicitar Hospedaje' : 'No Disponible'}
                    </Text>
                  </TouchableOpacity>
                </View>
              </AnimatedView>
            ))}
          </View>
        ) : (
          <View style={s.list}>
            {aspirantes.map((aspirante, idx) => (
              <AnimatedView key={aspirante.name} type="slideUp" delay={idx * 100}>
                <View style={s.card}>
                  <View style={s.aspirantHeader}>
                    <View style={s.aspirantLeft}>
                      <View style={[s.avatar, { backgroundColor: colors.blue[500] }]}>
                        <Text style={s.avatarText}>{aspirante.name.charAt(0)}</Text>
                      </View>
                      <View>
                        <Text style={s.aspirantName}>{aspirante.name}</Text>
                        <View style={s.dateRow}>
                          <Icon name="Calendar" size={12} color={colors.gray[400]} />
                          <Text style={s.dateText}>{aspirante.date}</Text>
                        </View>
                      </View>
                    </View>
                    <View style={[s.statusBadge, { borderColor: getStatusStyle(aspirante.status).borderColor }]}>
                      <Icon name="Clock" size={12} color={getStatusStyle(aspirante.status).color} />
                      <Text style={[s.statusText, { color: getStatusStyle(aspirante.status).color }]}>
                        {aspirante.status}
                      </Text>
                    </View>
                  </View>

                  <View style={s.progressSection}>
                    <View style={s.progressHeader}>
                      <Text style={s.progressLabel}>Retos completados</Text>
                      <Text style={s.progressValue}>{aspirante.challenges}</Text>
                    </View>
                    <View style={s.progressBar}>
                      <View style={[s.progressFill, { width: `${aspirante.progress}%` }]} />
                    </View>
                  </View>

                  <TouchableOpacity style={s.detailsBtn}>
                    <Text style={s.detailsBtnText}>Ver Detalles</Text>
                  </TouchableOpacity>
                </View>
              </AnimatedView>
            ))}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.gray[900] },
  header: { paddingHorizontal: spacing.lg, paddingTop: 50, paddingBottom: spacing.lg, backgroundColor: colors.gray[900], borderBottomWidth: 1, borderBottomColor: colors.gray[700] },
  headerTitle: { fontSize: fontSize.xl, fontWeight: 'bold', color: colors.white, marginBottom: spacing.lg },
  tabRow: { flexDirection: 'row', gap: spacing.sm },
  tab: { flex: 1, paddingHorizontal: spacing.lg, paddingVertical: 10, borderRadius: borderRadius.lg, backgroundColor: colors.gray[800] },
  tabActive: { backgroundColor: colors.amber[500] },
  tabText: { fontSize: fontSize.sm, fontWeight: '500', textAlign: 'center', color: colors.gray[400] },
  tabTextActive: { color: colors.white },
  scroll: { flex: 1, paddingHorizontal: spacing.lg, paddingTop: spacing['2xl'] },
  list: { gap: spacing.lg },
  card: { backgroundColor: colors.gray[800], borderRadius: borderRadius.xl, padding: spacing.lg, borderWidth: 1, borderColor: colors.gray[700] },
  hostRow: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md, marginBottom: spacing.md },
  avatar: { width: 48, height: 48, borderRadius: borderRadius.full, backgroundColor: colors.amber[500], alignItems: 'center', justifyContent: 'center' },
  avatarText: { color: colors.white, fontWeight: 'bold', fontSize: fontSize.lg },
  hostInfo: { flex: 1 },
  hostName: { color: colors.white, fontWeight: '600', fontSize: fontSize.base },
  locationRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  locationText: { color: colors.gray[400], fontSize: fontSize.sm },
  statsGrid: { flexDirection: 'row', gap: spacing.md, marginBottom: spacing.md },
  statBox: { flex: 1, backgroundColor: 'rgba(55,65,81,0.5)', borderRadius: borderRadius.lg, padding: 8, alignItems: 'center' },
  statValue: { color: colors.white, fontWeight: '600', fontSize: fontSize.sm },
  statLabel: { color: colors.gray[400], fontSize: fontSize.xs },
  requestBtn: { width: '100%', paddingVertical: 10, borderRadius: borderRadius.lg, backgroundColor: colors.amber[500] },
  requestBtnDisabled: { backgroundColor: colors.gray[700] },
  requestBtnText: { color: colors.white, fontWeight: '500', fontSize: fontSize.sm, textAlign: 'center' },
  requestBtnTextDisabled: { color: colors.gray[500] },
  aspirantHeader: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: spacing.md },
  aspirantLeft: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md },
  aspirantName: { color: colors.white, fontWeight: '600', fontSize: fontSize.base },
  dateRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  dateText: { color: colors.gray[400], fontSize: fontSize.sm },
  statusBadge: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 8, paddingVertical: 4, borderRadius: borderRadius.lg, borderWidth: 1 },
  statusText: { fontSize: fontSize.xs, fontWeight: '500' },
  progressSection: { marginBottom: spacing.md },
  progressHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 },
  progressLabel: { color: colors.gray[400], fontSize: fontSize.sm },
  progressValue: { color: colors.white, fontWeight: '600' },
  progressBar: { width: '100%', backgroundColor: colors.gray[700], borderRadius: borderRadius.full, height: 8, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: colors.amber[500] },
  detailsBtn: { width: '100%', paddingVertical: 10, backgroundColor: colors.gray[700], borderRadius: borderRadius.lg },
  detailsBtnText: { color: colors.white, fontWeight: '500', fontSize: fontSize.sm, textAlign: 'center' },
});

export default ComunidadScreen;
