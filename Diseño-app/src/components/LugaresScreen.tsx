import React, { useState } from 'react';
import {
  Search,
  Filter,
  MapPin,
  Lock,
  CheckCircle,
  QrCode,
  Star } from
'lucide-react';
import { motion } from 'framer-motion';
export function LugaresScreen() {
  const [activeFilter, setActiveFilter] = useState('todos');
  const places = [
  {
    name: 'Caño Cristales',
    department: 'Meta',
    difficulty: 4,
    visited: true,
    image: 'bg-gradient-to-br from-pink-500 to-red-600'
  },
  {
    name: 'Desierto de la Tatacoa',
    department: 'Huila',
    difficulty: 3,
    visited: true,
    image: 'bg-gradient-to-br from-orange-500 to-yellow-600'
  },
  {
    name: 'Valle de Cocora',
    department: 'Quindío',
    difficulty: 2,
    visited: false,
    image: 'bg-gradient-to-br from-green-500 to-emerald-600'
  },
  {
    name: 'Guatapé',
    department: 'Antioquia',
    difficulty: 2,
    visited: false,
    image: 'bg-gradient-to-br from-blue-500 to-cyan-600'
  },
  {
    name: 'Cabo de la Vela',
    department: 'La Guajira',
    difficulty: 5,
    visited: false,
    image: 'bg-gradient-to-br from-yellow-500 to-orange-600'
  },
  {
    name: 'San Agustín',
    department: 'Huila',
    difficulty: 3,
    visited: false,
    image: 'bg-gradient-to-br from-purple-500 to-indigo-600'
  }];

  const filters = [
  {
    id: 'todos',
    label: 'Todos'
  },
  {
    id: 'desbloqueados',
    label: 'Desbloqueados'
  },
  {
    id: 'por-visitar',
    label: 'Por Visitar'
  }];

  return (
    <div className="h-full overflow-y-auto bg-gray-900">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-gray-900/95 backdrop-blur-sm border-b border-gray-800 px-6 py-4">
        <h1 className="text-xl font-bold text-white mb-4">
          Lugares por Conocer
        </h1>

        {/* Search Bar */}
        <div className="relative mb-4">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar destinos..."
            className="w-full bg-gray-800 text-white pl-10 pr-4 py-3 rounded-xl border border-gray-700 focus:border-amber-500 focus:outline-none transition-colors" />
          
        </div>

        {/* Filter Chips */}
        <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
          {filters.map((filter) =>
          <button
            key={filter.id}
            onClick={() => setActiveFilter(filter.id)}
            className={`flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium transition-colors ${activeFilter === filter.id ? 'bg-amber-500 text-white' : 'bg-gray-800 text-gray-400 hover:bg-gray-700'}`}>
            
              {filter.label}
            </button>
          )}
        </div>
      </div>

      {/* Places Grid */}
      <div className="px-6 py-6 space-y-4">
        {places.map((place, idx) =>
        <motion.div
          key={place.name}
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
          className="bg-gray-800 rounded-xl overflow-hidden border border-gray-700 hover:border-gray-600 transition-colors">
          
            <div className="flex gap-4 p-4">
              {/* Image */}
              <div
              className={`relative w-24 h-24 rounded-lg ${place.image} flex-shrink-0`}>
              
                {!place.visited &&
              <div className="absolute inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center">
                    <Lock className="w-6 h-6 text-white" />
                  </div>
              }
                {place.visited &&
              <div className="absolute top-2 right-2 bg-green-500 rounded-full p-1">
                    <CheckCircle className="w-4 h-4 text-white" />
                  </div>
              }
              </div>

              {/* Info */}
              <div className="flex-1 min-w-0">
                <h3 className="text-white font-semibold text-base mb-1">
                  {place.name}
                </h3>
                <div className="flex items-center gap-1 text-gray-400 text-sm mb-2">
                  <MapPin className="w-3 h-3" />
                  <span>{place.department}</span>
                </div>

                {/* Difficulty */}
                <div className="flex items-center gap-1 mb-3">
                  {[...Array(5)].map((_, i) =>
                <Star
                  key={i}
                  className={`w-3 h-3 ${i < place.difficulty ? 'text-amber-500 fill-amber-500' : 'text-gray-600'}`} />

                )}
                  <span className="text-xs text-gray-500 ml-1">Dificultad</span>
                </div>

                {/* Action Button */}
                {place.visited ?
              <button className="flex items-center gap-2 px-3 py-1.5 bg-amber-500/20 text-amber-500 rounded-lg text-sm font-medium hover:bg-amber-500/30 transition-colors">
                    <QrCode className="w-4 h-4" />
                    Escanear QR
                  </button> :

              <div className="flex items-center gap-2 px-3 py-1.5 bg-gray-700/50 text-gray-500 rounded-lg text-sm">
                    <Lock className="w-4 h-4" />
                    Bloqueado
                  </div>
              }
              </div>
            </div>
          </motion.div>
        )}
      </div>

      {/* Floating QR Button */}
      <motion.button
        initial={{
          scale: 0
        }}
        animate={{
          scale: 1
        }}
        transition={{
          delay: 0.5,
          type: 'spring'
        }}
        className="fixed bottom-24 right-8 w-14 h-14 bg-gradient-to-br from-amber-500 to-orange-600 rounded-full shadow-lg flex items-center justify-center hover:shadow-xl transition-shadow">
        
        <QrCode className="w-6 h-6 text-white" />
      </motion.button>
    </div>);

}