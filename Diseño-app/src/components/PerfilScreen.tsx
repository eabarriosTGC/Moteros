import React from 'react';
import {
  Calendar,
  MapPin,
  Star,
  Trophy,
  Camera,
  Settings,
  LogOut,
  QrCode,
  ChevronRight,
  Crown } from
'lucide-react';
import { motion } from 'framer-motion';
export function PerfilScreen() {
  const stats = [
  {
    label: 'Lugares Visitados',
    value: '12',
    icon: MapPin
  },
  {
    label: 'Reseñas',
    value: '8',
    icon: Star
  },
  {
    label: 'Km Recorridos',
    value: '2,450',
    icon: Trophy
  },
  {
    label: 'Retos Completados',
    value: '15',
    icon: Trophy
  }];

  const menuItems = [
  {
    label: 'Mis Visitas',
    icon: MapPin
  },
  {
    label: 'Mis Fotos',
    icon: Camera
  },
  {
    label: 'Configuración',
    icon: Settings
  },
  {
    label: 'Cerrar Sesión',
    icon: LogOut,
    danger: true
  }];

  return (
    <div className="h-full overflow-y-auto bg-gray-900">
      {/* Header */}
      <div className="bg-gradient-to-br from-amber-600 via-orange-600 to-red-700 px-6 pt-8 pb-20">
        <div className="flex flex-col items-center">
          <div className="w-24 h-24 rounded-full bg-gradient-to-br from-white to-gray-200 flex items-center justify-center text-gray-800 font-bold text-3xl mb-3 border-4 border-white/30">
            JD
          </div>
          <h2 className="text-white text-xl font-bold">Juan Díaz</h2>
          <div className="flex items-center gap-1 text-white/90 text-sm mt-1">
            <Calendar className="w-4 h-4" />
            <span>Miembro desde Mar 2024</span>
          </div>
        </div>
      </div>

      <div className="px-6 -mt-12 pb-6 space-y-6">
        {/* Membership Card */}
        <motion.div
          initial={{
            opacity: 0,
            y: 20
          }}
          animate={{
            opacity: 1,
            y: 0
          }}
          className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-xl p-4 border border-amber-500/30 shadow-lg">
          
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <Crown className="w-5 h-5 text-amber-500" />
              <span className="text-white font-semibold">Plan Premium</span>
            </div>
            <span className="text-xs text-gray-400">Vence: 15 Dic 2024</span>
          </div>
          <p className="text-gray-400 text-sm mb-3">
            Acceso completo a todos los lugares y beneficios exclusivos
          </p>
          <button className="w-full py-2.5 bg-amber-500 hover:bg-amber-600 text-white rounded-lg font-medium text-sm transition-colors">
            Renovar Membresía
          </button>
        </motion.div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-3">
          {stats.map((stat, idx) => {
            const Icon = stat.icon;
            return (
              <motion.div
                key={stat.label}
                initial={{
                  opacity: 0,
                  scale: 0.9
                }}
                animate={{
                  opacity: 1,
                  scale: 1
                }}
                transition={{
                  delay: 0.1 + idx * 0.05
                }}
                className="bg-gray-800 rounded-xl p-4 border border-gray-700">
                
                <Icon className="w-5 h-5 text-amber-500 mb-2" />
                <div className="text-2xl font-bold text-white mb-1">
                  {stat.value}
                </div>
                <div className="text-xs text-gray-400">{stat.label}</div>
              </motion.div>);

          })}
        </div>

        {/* QR Code Section */}
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
            delay: 0.3
          }}
          className="bg-gray-800 rounded-xl p-4 border border-gray-700">
          
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-white font-semibold">Mi Código de Miembro</h3>
            <QrCode className="w-5 h-5 text-amber-500" />
          </div>
          <div className="bg-white rounded-lg p-4 flex items-center justify-center">
            <div className="w-32 h-32 bg-gradient-to-br from-gray-200 to-gray-300 rounded-lg flex items-center justify-center">
              <QrCode className="w-16 h-16 text-gray-600" />
            </div>
          </div>
          <p className="text-gray-400 text-xs text-center mt-3">
            Muestra este código para registrar tus visitas
          </p>
        </motion.div>

        {/* Menu Items */}
        <div className="space-y-2">
          {menuItems.map((item, idx) => {
            const Icon = item.icon;
            return (
              <motion.button
                key={item.label}
                initial={{
                  opacity: 0,
                  x: -20
                }}
                animate={{
                  opacity: 1,
                  x: 0
                }}
                transition={{
                  delay: 0.4 + idx * 0.05
                }}
                className={`w-full flex items-center justify-between bg-gray-800 hover:bg-gray-700 rounded-xl p-4 border border-gray-700 transition-colors ${item.danger ? 'hover:border-red-500/50' : ''}`}>
                
                <div className="flex items-center gap-3">
                  <Icon
                    className={`w-5 h-5 ${item.danger ? 'text-red-500' : 'text-gray-400'}`} />
                  
                  <span
                    className={`font-medium ${item.danger ? 'text-red-500' : 'text-white'}`}>
                    
                    {item.label}
                  </span>
                </div>
                <ChevronRight
                  className={`w-5 h-5 ${item.danger ? 'text-red-500' : 'text-gray-600'}`} />
                
              </motion.button>);

          })}
        </div>
      </div>
    </div>);

}