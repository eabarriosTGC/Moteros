/**
 * RecomendacionesScreen - Restaurant, hotel, and workshop recommendations.
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

type TabType = 'restaurantes' | 'hoteles' | 'talleres';

const recommendations = {
  restaurantes: [
    { name: 'El Fogón Paisa', location: 'Medellín, Antioquia', rating: 4.8, members: 24, distance: '2.3 km' },
    { name: 'La Puerta Falsa', location: 'Bogotá, Cundinamarca', rating: 4.9, members: 31, distance: '5.1 km' },
    { name: 'Carbón de Palo', location: 'Cali, Valle del Cauca', rating: 4.7, members: 18, distance: '1.8 km' },
  ],
  hoteles: [
    { name: 'Hotel Campestre', location: 'Villa de Leyva, Boyacá', rating: 4.6, members: 15, distance: '12 km' },
    { name: 'Posada del Camino', location: 'Salento, Quindío', rating: 4.8, members: 22, distance: '3.5 km' },
    { name: 'Refugio del Motero', location: 'San Gil, Santander', rating: 4.9, members: 28, distance: '8.2 km' },
  ],
  talleres: [
    { name: 'Motos Pro', location: 'Bogotá, Cundinamarca', rating: 4.9, members: 42, distance: '4.2 km' },
    { name: 'Taller El Experto', location: 'Medellín, Antioquia', rating: 4.7, members: 35, distance: '6.8 km' },
    { name: 'Mecánica Rápida', location: 'Cali, Valle del Cauca', rating: 4.6, members: 19, distance: '2.1 km' },
  ],
};

const tabs: { id: TabType; label: string }[] = [
  { id: 'restaurantes', label: 'Restaurantes' },
  { id: 'hoteles', label: 'Hoteles' },
  { id: 'talleres', label: 'Talleres' },
];

export function RecomendacionesScreen() {
  const [activeTab, setActiveTab] = useState<TabType>('restaurantes');

  return (
    <View style={s.container}>
      {/* Header */}
      <View style={s.header}>
        <Text style={s.headerTitle}>Recomendaciones</Text>

        {/* Location Filter */}
        <TouchableOpacity style={s.locationBtn}>
          <View style={s.locationLeft}>
            <Icon name="MapPin" size={20} color={colors.amber[500]} />
            <Text style={s.locationText}>Todas las ubicaciones</Text>
          </View>
          <Icon name="ChevronDown" size={20} color={colors.gray[400]} />
        </TouchableOpacity>

        {/* Tabs */}
        <View style={s.tabRow}>
          {tabs.map((tab) => (
            <TouchableOpacity
              key={tab.id}
              onPress={() => setActiveTab(tab.id)}
              style={[s.tab, activeTab === tab.id && s.tabActive]}
            >
              <Text style={[s.tabText, activeTab === tab.id && s.tabTextActive]}>
                {tab.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Recommendations List */}
      <ScrollView style={s.scroll} showsVerticalScrollIndicator={false}>
        <View style={s.list}>
          {recommendations[activeTab].map((rec, idx) => (
            <AnimatedView key={rec.name} type="slideUp" delay={idx * 100}>
              <View style={s.card}>
                <View style={s.cardHeader}>
                  <View style={s.cardInfo}>
                    <Text style={s.cardName}>{rec.name}</Text>
                    <View style={s.cardLocation}>
                      <Icon name="MapPin" size={12} color={colors.gray[400]} />
                      <Text style={s.cardLocationText}>{rec.location}</Text>
                    </View>
                  </View>
                  <View style={s.ratingBadge}>
                    <Icon name="Star" size={16} color={colors.amber[500]} />
                    <Text style={s.ratingText}>{rec.rating}</Text>
                  </View>
                </View>

                <View style={s.cardFooter}>
                  <View style={s.membersRow}>
                    <Icon name="Users" size={16} color={colors.gray[400]} />
                    <Text style={s.membersText}>Recomendado por {rec.members} miembros</Text>
                  </View>
                  <Text style={s.distance}>{rec.distance}</Text>
                </View>
              </View>
            </AnimatedView>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.gray[900] },
  header: { paddingHorizontal: spacing.lg, paddingTop: 50, paddingBottom: spacing.lg, backgroundColor: colors.gray[900], borderBottomWidth: 1, borderBottomColor: colors.gray[700] },
  headerTitle: { fontSize: fontSize.xl, fontWeight: 'bold', color: colors.white, marginBottom: spacing.lg },
  locationBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.gray[800], paddingHorizontal: spacing.lg, paddingVertical: 12, borderRadius: borderRadius.xl, borderWidth: 1, borderColor: colors.gray[700], marginBottom: spacing.lg },
  locationLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  locationText: { color: colors.white, fontSize: fontSize.sm },
  tabRow: { flexDirection: 'row', gap: spacing.sm },
  tab: { flex: 1, paddingHorizontal: spacing.lg, paddingVertical: 10, borderRadius: borderRadius.lg, backgroundColor: colors.gray[800] },
  tabActive: { backgroundColor: colors.amber[500] },
  tabText: { fontSize: fontSize.sm, fontWeight: '500', textAlign: 'center', color: colors.gray[400] },
  tabTextActive: { color: colors.white },
  scroll: { flex: 1, paddingHorizontal: spacing.lg, paddingTop: spacing['2xl'] },
  list: { gap: spacing.md },
  card: { backgroundColor: colors.gray[800], borderRadius: borderRadius.xl, padding: spacing.lg, borderWidth: 1, borderColor: colors.gray[700] },
  cardHeader: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 12 },
  cardInfo: { flex: 1 },
  cardName: { color: colors.white, fontWeight: '600', fontSize: fontSize.base, marginBottom: 4 },
  cardLocation: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  cardLocationText: { color: colors.gray[400], fontSize: fontSize.sm },
  ratingBadge: { flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: 'rgba(245,158,11,0.2)', paddingHorizontal: 8, paddingVertical: 4, borderRadius: borderRadius.sm },
  ratingText: { color: colors.amber[500], fontWeight: '600', fontSize: fontSize.sm },
  cardFooter: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  membersRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  membersText: { color: colors.gray[400], fontSize: fontSize.sm },
  distance: { color: colors.gray[500], fontSize: fontSize.sm },
});

export default RecomendacionesScreen;
