import React from 'react';
import { Bell, MapPin, Calendar, TrendingUp, ChevronRight } from 'lucide-react';
import { motion } from 'framer-motion';
export function HomeScreen() {
  const destinations = [
  {
    name: 'Guatapé',
    department: 'Antioquia',
    image: 'bg-gradient-to-br from-blue-500 to-cyan-600'
  },
  {
    name: 'Tatacoa',
    department: 'Huila',
    image: 'bg-gradient-to-br from-orange-500 to-red-600'
  },
  {
    name: 'Valle de Cocora',
    department: 'Quindío',
    image: 'bg-gradient-to-br from-green-500 to-emerald-600'
  },
  {
    name: 'Cabo de la Vela',
    department: 'La Guajira',
    image: 'bg-gradient-to-br from-yellow-500 to-orange-600'
  }];

  const activities = [
  {
    user: 'Carlos M.',
    action: 'visitó Caño Cristales',
    time: 'Hace 2 horas'
  },
  {
    user: 'Ana R.',
    action: 'completó reto en Tatacoa',
    time: 'Hace 5 horas'
  },
  {
    user: 'Miguel S.',
    action: 'recomendó Taller Motos Pro',
    time: 'Hace 1 día'
  }];

  return (
    <div className="h-full overflow-y-auto bg-gray-900">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-gray-900/95 backdrop-blur-sm border-b border-gray-800 px-6 py-4">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-white">RUTA COLOMBIA MC</h1>
            <p className="text-xs text-gray-400">Tu aventura en dos ruedas</p>
          </div>
          <button className="relative p-2 rounded-full bg-gray-800 hover:bg-gray-700 transition-colors">
            <Bell className="w-5 h-5 text-gray-300" />
            <span className="absolute top-1 right-1 w-2 h-2 bg-amber-500 rounded-full"></span>
          </button>
        </div>
      </div>

      <div className="px-6 py-6 space-y-6">
        {/* Hero Banner */}
        <motion.div
          initial={{
            opacity: 0,
            y: 20
          }}
          animate={{
            opacity: 1,
            y: 0
          }}
          className="relative h-48 rounded-2xl overflow-hidden bg-gradient-to-br from-amber-600 via-orange-600 to-red-700">
          
          <div className="absolute inset-0 bg-black/30"></div>
          <div className="relative h-full flex flex-col justify-end p-6">
            <h2 className="text-2xl font-bold text-white mb-1">
              Descubre Colombia
            </h2>
            <p className="text-sm text-white/90">
              En cada curva, una nueva historia
            </p>
          </div>
        </motion.div>

        {/* Membership Status */}
        <motion.div
          initial={{
            opacity: 0,
            y: 20
          }}
          animate={{
            opacity: 1,
            y: 0
          }}
          transition={{
            delay: 0.1
          }}
          className="bg-gradient-to-r from-amber-500/20 to-orange-500/20 border border-amber-500/30 rounded-xl p-4">
          
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              <span className="text-sm font-semibold text-amber-500">
                Miembro Activo
              </span>
            </div>
            <span className="text-xs text-gray-400">Vence: 15 Dic 2024</span>
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div className="text-center">
              <div className="text-2xl font-bold text-white">12</div>
              <div className="text-xs text-gray-400">Lugares</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-white">2,450</div>
              <div className="text-xs text-gray-400">KM</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-white">8m</div>
              <div className="text-xs text-gray-400">Miembro</div>
            </div>
          </div>
        </motion.div>

        {/* Próximos Destinos */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-bold text-white">Próximos Destinos</h3>
            <button className="text-sm text-amber-500 hover:text-amber-400 transition-colors">
              Ver todos
            </button>
          </div>
          <div className="flex gap-3 overflow-x-auto pb-2 -mx-6 px-6 scrollbar-hide">
            {destinations.map((dest, idx) =>
            <motion.div
              key={dest.name}
              initial={{
                opacity: 0,
                x: 20
              }}
              animate={{
                opacity: 1,
                x: 0
              }}
              transition={{
                delay: 0.2 + idx * 0.1
              }}
              className="flex-shrink-0 w-40">
              
                <div
                className={`${dest.image} h-32 rounded-xl mb-2 flex items-end p-3`}>
                
                  <div className="w-full">
                    <div className="bg-black/50 backdrop-blur-sm rounded-lg px-2 py-1">
                      <div className="text-white font-semibold text-sm">
                        {dest.name}
                      </div>
                      <div className="text-white/80 text-xs">
                        {dest.department}
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}
          </div>
        </div>

        {/* Recent Activity */}
        <div>
          <h3 className="text-lg font-bold text-white mb-4">
            Actividad Reciente
          </h3>
          <div className="space-y-3">
            {activities.map((activity, idx) =>
            <motion.div
              key={idx}
              initial={{
                opacity: 0,
                x: -20
              }}
              animate={{
                opacity: 1,
                x: 0
              }}
              transition={{
                delay: 0.3 + idx * 0.1
              }}
              className="flex items-center gap-3 bg-gray-800 rounded-lg p-3">
              
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center text-white font-bold text-sm">
                  {activity.user.charAt(0)}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-white">
                    <span className="font-semibold">{activity.user}</span>{' '}
                    <span className="text-gray-400">{activity.action}</span>
                  </p>
                  <p className="text-xs text-gray-500">{activity.time}</p>
                </div>
                <ChevronRight className="w-4 h-4 text-gray-600 flex-shrink-0" />
              </motion.div>
            )}
          </div>
        </div>
      </div>
    </div>);

}