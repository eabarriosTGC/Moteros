import React, { useState } from 'react';
import { ChevronDown, MapPin, Star, Users } from 'lucide-react';
import { motion } from 'framer-motion';
export function RecomendacionesScreen() {
  const [activeTab, setActiveTab] = useState<
    'restaurantes' | 'hoteles' | 'talleres'>(
    'restaurantes');
  const recommendations = {
    restaurantes: [
    {
      name: 'El Fogón Paisa',
      location: 'Medellín, Antioquia',
      rating: 4.8,
      members: 24,
      distance: '2.3 km'
    },
    {
      name: 'La Puerta Falsa',
      location: 'Bogotá, Cundinamarca',
      rating: 4.9,
      members: 31,
      distance: '5.1 km'
    },
    {
      name: 'Carbón de Palo',
      location: 'Cali, Valle del Cauca',
      rating: 4.7,
      members: 18,
      distance: '1.8 km'
    }],

    hoteles: [
    {
      name: 'Hotel Campestre',
      location: 'Villa de Leyva, Boyacá',
      rating: 4.6,
      members: 15,
      distance: '12 km'
    },
    {
      name: 'Posada del Camino',
      location: 'Salento, Quindío',
      rating: 4.8,
      members: 22,
      distance: '3.5 km'
    },
    {
      name: 'Refugio del Motero',
      location: 'San Gil, Santander',
      rating: 4.9,
      members: 28,
      distance: '8.2 km'
    }],

    talleres: [
    {
      name: 'Motos Pro',
      location: 'Bogotá, Cundinamarca',
      rating: 4.9,
      members: 42,
      distance: '4.2 km'
    },
    {
      name: 'Taller El Experto',
      location: 'Medellín, Antioquia',
      rating: 4.7,
      members: 35,
      distance: '6.8 km'
    },
    {
      name: 'Mecánica Rápida',
      location: 'Cali, Valle del Cauca',
      rating: 4.6,
      members: 19,
      distance: '2.1 km'
    }]

  };
  const tabs = [
  {
    id: 'restaurantes' as const,
    label: 'Restaurantes'
  },
  {
    id: 'hoteles' as const,
    label: 'Hoteles'
  },
  {
    id: 'talleres' as const,
    label: 'Talleres'
  }];

  return (
    <div className="h-full overflow-y-auto bg-gray-900">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-gray-900/95 backdrop-blur-sm border-b border-gray-800 px-6 py-4">
        <h1 className="text-xl font-bold text-white mb-4">Recomendaciones</h1>

        {/* Location Filter */}
        <button className="w-full flex items-center justify-between bg-gray-800 px-4 py-3 rounded-xl border border-gray-700 hover:border-gray-600 transition-colors mb-4">
          <div className="flex items-center gap-2">
            <MapPin className="w-5 h-5 text-amber-500" />
            <span className="text-white text-sm">Todas las ubicaciones</span>
          </div>
          <ChevronDown className="w-5 h-5 text-gray-400" />
        </button>

        {/* Tabs */}
        <div className="flex gap-2">
          {tabs.map((tab) =>
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex-1 px-4 py-2.5 rounded-lg text-sm font-medium transition-colors ${activeTab === tab.id ? 'bg-amber-500 text-white' : 'bg-gray-800 text-gray-400 hover:bg-gray-700'}`}>
            
              {tab.label}
            </button>
          )}
        </div>
      </div>

      {/* Recommendations List */}
      <div className="px-6 py-6 space-y-3">
        {recommendations[activeTab].map((rec, idx) =>
        <motion.div
          key={rec.name}
          initial={{
            opacity: 0,
            y: 20
          }}
          animate={{
            opacity: 1,
            y: 0
          }}
          transition={{
            delay: idx * 0.1
          }}
          className="bg-gray-800 rounded-xl p-4 border border-gray-700 hover:border-gray-600 transition-colors">
          
            <div className="flex items-start justify-between mb-3">
              <div className="flex-1">
                <h3 className="text-white font-semibold text-base mb-1">
                  {rec.name}
                </h3>
                <div className="flex items-center gap-1 text-gray-400 text-sm">
                  <MapPin className="w-3 h-3" />
                  <span>{rec.location}</span>
                </div>
              </div>
              <div className="flex items-center gap-1 bg-amber-500/20 px-2 py-1 rounded-lg">
                <Star className="w-4 h-4 text-amber-500 fill-amber-500" />
                <span className="text-amber-500 font-semibold text-sm">
                  {rec.rating}
                </span>
              </div>
            </div>

            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1 text-gray-400 text-sm">
                <Users className="w-4 h-4" />
                <span>Recomendado por {rec.members} miembros</span>
              </div>
              <span className="text-gray-500 text-sm">{rec.distance}</span>
            </div>
          </motion.div>
        )}
      </div>
    </div>);

}