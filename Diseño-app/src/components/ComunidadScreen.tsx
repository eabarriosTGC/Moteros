import React, { useState } from 'react';
import {
  MapPin,
  Users,
  Calendar,
  CheckCircle,
  Clock,
  XCircle } from
'lucide-react';
import { motion } from 'framer-motion';
export function ComunidadScreen() {
  const [activeTab, setActiveTab] = useState<'motoposada' | 'aspirantes'>(
    'motoposada'
  );
  const motoPosadas = [
  {
    host: 'Carlos Mendoza',
    location: 'Medellín, Antioquia',
    capacity: 2,
    available: 1,
    date: '15-20 Dic'
  },
  {
    host: 'Ana Rodríguez',
    location: 'Bogotá, Cundinamarca',
    capacity: 3,
    available: 3,
    date: '22-28 Dic'
  },
  {
    host: 'Miguel Santos',
    location: 'Cali, Valle del Cauca',
    capacity: 2,
    available: 0,
    date: '10-15 Ene'
  }];

  const aspirantes = [
  {
    name: 'Juan Pérez',
    status: 'En Reto',
    progress: 60,
    challenges: '3/5',
    date: 'Nov 2024'
  },
  {
    name: 'Laura Gómez',
    status: 'Pendiente',
    progress: 0,
    challenges: '0/5',
    date: 'Dic 2024'
  },
  {
    name: 'Diego Torres',
    status: 'Aprobado',
    progress: 100,
    challenges: '5/5',
    date: 'Oct 2024'
  }];

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Aprobado':
        return 'bg-green-500/20 text-green-500 border-green-500/30';
      case 'En Reto':
        return 'bg-amber-500/20 text-amber-500 border-amber-500/30';
      case 'Pendiente':
        return 'bg-gray-500/20 text-gray-400 border-gray-500/30';
      default:
        return 'bg-gray-500/20 text-gray-400 border-gray-500/30';
    }
  };
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'Aprobado':
        return <CheckCircle className="w-4 h-4" />;
      case 'En Reto':
        return <Clock className="w-4 h-4" />;
      case 'Pendiente':
        return <XCircle className="w-4 h-4" />;
      default:
        return null;
    }
  };
  return (
    <div className="h-full overflow-y-auto bg-gray-900">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-gray-900/95 backdrop-blur-sm border-b border-gray-800 px-6 py-4">
        <h1 className="text-xl font-bold text-white mb-4">Comunidad</h1>

        {/* Tabs */}
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('motoposada')}
            className={`flex-1 px-4 py-2.5 rounded-lg text-sm font-medium transition-colors ${activeTab === 'motoposada' ? 'bg-amber-500 text-white' : 'bg-gray-800 text-gray-400 hover:bg-gray-700'}`}>
            
            Moto Posada
          </button>
          <button
            onClick={() => setActiveTab('aspirantes')}
            className={`flex-1 px-4 py-2.5 rounded-lg text-sm font-medium transition-colors ${activeTab === 'aspirantes' ? 'bg-amber-500 text-white' : 'bg-gray-800 text-gray-400 hover:bg-gray-700'}`}>
            
            Aspirantes
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="px-6 py-6">
        {activeTab === 'motoposada' ?
        <div className="space-y-4">
            {motoPosadas.map((posada, idx) =>
          <motion.div
            key={posada.host}
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
            className="bg-gray-800 rounded-xl p-4 border border-gray-700">
            
                <div className="flex items-start gap-3 mb-3">
                  <div className="w-12 h-12 rounded-full bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center text-white font-bold">
                    {posada.host.charAt(0)}
                  </div>
                  <div className="flex-1">
                    <h3 className="text-white font-semibold text-base">
                      {posada.host}
                    </h3>
                    <div className="flex items-center gap-1 text-gray-400 text-sm">
                      <MapPin className="w-3 h-3" />
                      <span>{posada.location}</span>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-3 mb-3">
                  <div className="bg-gray-700/50 rounded-lg p-2 text-center">
                    <div className="text-white font-semibold text-sm">
                      {posada.capacity}
                    </div>
                    <div className="text-gray-400 text-xs">Capacidad</div>
                  </div>
                  <div className="bg-gray-700/50 rounded-lg p-2 text-center">
                    <div
                  className={`font-semibold text-sm ${posada.available > 0 ? 'text-green-500' : 'text-red-500'}`}>
                  
                      {posada.available}
                    </div>
                    <div className="text-gray-400 text-xs">Disponible</div>
                  </div>
                  <div className="bg-gray-700/50 rounded-lg p-2 text-center">
                    <div className="text-white font-semibold text-sm">
                      {posada.date}
                    </div>
                    <div className="text-gray-400 text-xs">Fechas</div>
                  </div>
                </div>

                <button
              disabled={posada.available === 0}
              className={`w-full py-2.5 rounded-lg font-medium text-sm transition-colors ${posada.available > 0 ? 'bg-amber-500 text-white hover:bg-amber-600' : 'bg-gray-700 text-gray-500 cursor-not-allowed'}`}>
              
                  {posada.available > 0 ?
              'Solicitar Hospedaje' :
              'No Disponible'}
                </button>
              </motion.div>
          )}
          </div> :

        <div className="space-y-4">
            {aspirantes.map((aspirante, idx) =>
          <motion.div
            key={aspirante.name}
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
            className="bg-gray-800 rounded-xl p-4 border border-gray-700">
            
                <div className="flex items-start justify-between mb-3">
                  <div className="flex items-start gap-3">
                    <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white font-bold">
                      {aspirante.name.charAt(0)}
                    </div>
                    <div>
                      <h3 className="text-white font-semibold text-base">
                        {aspirante.name}
                      </h3>
                      <div className="flex items-center gap-1 text-gray-400 text-sm">
                        <Calendar className="w-3 h-3" />
                        <span>{aspirante.date}</span>
                      </div>
                    </div>
                  </div>
                  <div
                className={`flex items-center gap-1 px-2 py-1 rounded-lg border text-xs font-medium ${getStatusColor(aspirante.status)}`}>
                
                    {getStatusIcon(aspirante.status)}
                    {aspirante.status}
                  </div>
                </div>

                <div className="mb-3">
                  <div className="flex items-center justify-between text-sm mb-2">
                    <span className="text-gray-400">Retos completados</span>
                    <span className="text-white font-semibold">
                      {aspirante.challenges}
                    </span>
                  </div>
                  <div className="w-full bg-gray-700 rounded-full h-2 overflow-hidden">
                    <motion.div
                  initial={{
                    width: 0
                  }}
                  animate={{
                    width: `${aspirante.progress}%`
                  }}
                  transition={{
                    delay: 0.3 + idx * 0.1,
                    duration: 0.5
                  }}
                  className="h-full bg-gradient-to-r from-amber-500 to-orange-600" />
                
                  </div>
                </div>

                <button className="w-full py-2.5 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium text-sm transition-colors">
                  Ver Detalles
                </button>
              </motion.div>
          )}
          </div>
        }
      </div>
    </div>);

}