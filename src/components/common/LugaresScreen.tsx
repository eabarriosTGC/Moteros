/**
 * LugaresScreen - Places to discover with filters and QR scanning.
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  StyleSheet,
} from 'react-native';
import { Icon } from '../ui/Icons';
import { AnimatedView } from '../ui/AnimatedView';
import { colors, spacing, fontSize, borderRadius } from '../../styles/theme';

const places = [
  { name: 'Caño Cristales', department: 'Meta', difficulty: 4, visited: true, gradient: [colors.pink[500], colors.red[600]] },
  { name: 'Desierto de la Tatacoa', department: 'Huila', difficulty: 3, visited: true, gradient: [colors.orange[500], colors.yellow[500]] },
  { name: 'Valle de Cocora', department: 'Quindío', difficulty: 2, visited: false, gradient: [colors.green[500], colors.emerald[600]] },
  { name: 'Guatapé', department: 'Antioquia', difficulty: 2, visited: false, gradient: [colors.blue[500], colors.cyan[500]] },
  { name: 'Cabo de la Vela', department: 'La Guajira', difficulty: 5, visited: false, gradient: [colors.yellow[500], colors.orange[600]] },
  { name: 'San Agustín', department: 'Huila', difficulty: 3, visited: false, gradient: [colors.purple[500], colors.purple[600]] },
];

const filters = [
  { id: 'todos', label: 'Todos' },
  { id: 'desbloqueados', label: 'Desbloqueados' },
  { id: 'por-visitar', label: 'Por Visitar' },
];

export function LugaresScreen() {
  const [activeFilter, setActiveFilter] = useState('todos');
  const [search, setSearch] = useState('');

  const renderStars = (difficulty: number) => {
    return [...Array(5)].map((_, i) => (
      <Icon key={i} name="Star" size={12} color={i < difficulty ? colors.amber[500] : colors.gray[600]} />
    ));
  };

  return (
    <View style={s.container}>
      {/* Header */}
      <View style={s.header}>
        <Text style={s.headerTitle}>Lugares por Conocer</Text>

        {/* Search Bar */}
        <View style={s.searchContainer}>
          <View style={s.searchIcon}>
            <Icon name="Search" size={20} color={colors.gray[400]} />
          </View>
          <TextInput
            value={search}
            onChangeText={setSearch}
            placeholder="Buscar destinos..."
            placeholderTextColor={colors.gray[400]}
            style={s.searchInput}
          />
        </View>

        {/* Filter Chips */}
        <View style={s.filterRow}>
          {filters.map((filter) => (
            <TouchableOpacity
              key={filter.id}
              onPress={() => setActiveFilter(filter.id)}
              style={[s.filterChip, activeFilter === filter.id && s.filterChipActive]}
            >
              <Text style={[s.filterText, activeFilter === filter.id && s.filterTextActive]}>
                {filter.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Places List */}
      <ScrollView style={s.scroll} showsVerticalScrollIndicator={false}>
        <View style={s.placesList}>
          {places.map((place, idx) => (
            <AnimatedView key={place.name} type="slideUp" delay={idx * 100}>
              <View style={s.placeCard}>
                <View style={s.placeRow}>
                  {/* Image */}
                  <View style={[s.placeImage, { backgroundColor: place.gradient[0] }]}>
                    {!place.visited && (
                      <View style={s.placeLockOverlay}>
                        <Icon name="Lock" size={24} color={colors.white} />
                      </View>
                    )}
                    {place.visited && (
                      <View style={s.placeCheck}>
                        <Icon name="CheckCircle" size={16} color={colors.white} />
                      </View>
                    )}
                  </View>

                  {/* Info */}
                  <View style={s.placeInfo}>
                    <Text style={s.placeName}>{place.name}</Text>
                    <View style={s.placeLocation}>
                      <Icon name="MapPin" size={12} color={colors.gray[400]} />
                      <Text style={s.placeDept}>{place.department}</Text>
                    </View>

                    {/* Difficulty */}
                    <View style={s.difficultyRow}>
                      {renderStars(place.difficulty)}
                      <Text style={s.difficultyLabel}>Dificultad</Text>
                    </View>

                    {/* Action Button */}
                    {place.visited ? (
                      <TouchableOpacity style={s.qrBtn}>
                        <Icon name="QrCode" size={16} color={colors.amber[500]} />
                        <Text style={s.qrBtnText}>Escanear QR</Text>
                      </TouchableOpacity>
                    ) : (
                      <View style={s.lockedBtn}>
                        <Icon name="Lock" size={16} color={colors.gray[500]} />
                        <Text style={s.lockedBtnText}>Bloqueado</Text>
                      </View>
                    )}
                  </View>
                </View>
              </View>
            </AnimatedView>
          ))}
        </View>

        {/* Floating QR Button */}
        <TouchableOpacity style={s.floatingQr}>
          <Icon name="QrCode" size={24} color={colors.white} />
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.gray[900] },
  header: { paddingHorizontal: spacing.lg, paddingTop: 50, paddingBottom: spacing.lg, backgroundColor: colors.gray[900], borderBottomWidth: 1, borderBottomColor: colors.gray[700] },
  headerTitle: { fontSize: fontSize.xl, fontWeight: 'bold', color: colors.white, marginBottom: spacing.lg },
  searchContainer: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.lg },
  searchIcon: { position: 'absolute', left: spacing.md, zIndex: 1 },
  searchInput: { flex: 1, backgroundColor: colors.gray[800], color: colors.white, paddingLeft: 40, paddingRight: spacing.lg, paddingVertical: 12, borderRadius: borderRadius.xl, borderWidth: 1, borderColor: colors.gray[700] },
  filterRow: { flexDirection: 'row', gap: spacing.sm },
  filterChip: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: borderRadius.full, backgroundColor: colors.gray[800] },
  filterChipActive: { backgroundColor: colors.amber[500] },
  filterText: { fontSize: fontSize.sm, fontWeight: '500', color: colors.gray[400] },
  filterTextActive: { color: colors.white },
  scroll: { flex: 1, paddingHorizontal: spacing.lg, paddingTop: spacing['2xl'] },
  placesList: { gap: spacing.lg },
  placeCard: { backgroundColor: colors.gray[800], borderRadius: borderRadius.xl, overflow: 'hidden', borderWidth: 1, borderColor: colors.gray[700] },
  placeRow: { flexDirection: 'row', gap: spacing.lg, padding: spacing.lg },
  placeImage: { width: 96, height: 96, borderRadius: borderRadius.lg, overflow: 'hidden' },
  placeLockOverlay: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.6)', alignItems: 'center', justifyContent: 'center' },
  placeCheck: { position: 'absolute', top: 8, right: 8, backgroundColor: colors.green[500], borderRadius: borderRadius.full, padding: 4 },
  placeInfo: { flex: 1 },
  placeName: { color: colors.white, fontWeight: '600', fontSize: fontSize.base, marginBottom: 4 },
  placeLocation: { flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 8 },
  placeDept: { color: colors.gray[400], fontSize: fontSize.sm },
  difficultyRow: { flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 12 },
  difficultyLabel: { fontSize: fontSize.xs, color: colors.gray[500], marginLeft: 4 },
  qrBtn: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(245,158,11,0.2)', borderRadius: borderRadius.lg },
  qrBtnText: { color: colors.amber[500], fontSize: fontSize.sm, fontWeight: '500' },
  lockedBtn: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(55,65,81,0.5)', borderRadius: borderRadius.lg },
  lockedBtnText: { color: colors.gray[500], fontSize: fontSize.sm },
  floatingQr: { position: 'absolute', bottom: 96, right: 32, width: 56, height: 56, backgroundColor: colors.amber[500], borderRadius: borderRadius.full, alignItems: 'center', justifyContent: 'center', shadowColor: colors.black, shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.3, shadowRadius: 8, elevation: 5 },
});

export default LugaresScreen;
