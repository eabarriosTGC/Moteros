import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Home, MapPin, Star, Users, User } from 'lucide-react';
import { HomeScreen } from './components/HomeScreen';
import { LugaresScreen } from './components/LugaresScreen';
import { RecomendacionesScreen } from './components/RecomendacionesScreen';
import { ComunidadScreen } from './components/ComunidadScreen';
import { PerfilScreen } from './components/PerfilScreen';
type Screen = 'home' | 'lugares' | 'recomendaciones' | 'comunidad' | 'perfil';
export function App() {
  const [activeScreen, setActiveScreen] = useState<Screen>('home');
  const screens = {
    home: <HomeScreen />,
    lugares: <LugaresScreen />,
    recomendaciones: <RecomendacionesScreen />,
    comunidad: <ComunidadScreen />,
    perfil: <PerfilScreen />
  };
  const navItems = [
  {
    id: 'home' as Screen,
    icon: Home,
    label: 'Inicio'
  },
  {
    id: 'lugares' as Screen,
    icon: MapPin,
    label: 'Lugares'
  },
  {
    id: 'recomendaciones' as Screen,
    icon: Star,
    label: 'Recomen.'
  },
  {
    id: 'comunidad' as Screen,
    icon: Users,
    label: 'Comunidad'
  },
  {
    id: 'perfil' as Screen,
    icon: User,
    label: 'Perfil'
  }];

  return (
    <div className="w-full min-h-screen flex items-center justify-center p-4 sm:p-8">
      <div className="phone-frame relative w-full max-w-[390px] h-[844px] bg-gray-900 rounded-[3rem] overflow-hidden border-8 border-gray-800">
        {/* Screen Content */}
        <div className="relative h-full flex flex-col bg-gray-900">
          {/* Content Area */}
          <div className="flex-1 overflow-hidden">
            <AnimatePresence mode="wait">
              <motion.div
                key={activeScreen}
                initial={{
                  opacity: 0,
                  x: 20
                }}
                animate={{
                  opacity: 1,
                  x: 0
                }}
                exit={{
                  opacity: 0,
                  x: -20
                }}
                transition={{
                  duration: 0.2
                }}
                className="h-full">
                
                {screens[activeScreen]}
              </motion.div>
            </AnimatePresence>
          </div>

          {/* Bottom Navigation */}
          <div className="bg-gray-800 border-t border-gray-700 px-2 py-2 safe-area-bottom">
            <div className="flex items-center justify-around">
              {navItems.map((item) => {
                const Icon = item.icon;
                const isActive = activeScreen === item.id;
                return (
                  <button
                    key={item.id}
                    onClick={() => setActiveScreen(item.id)}
                    className="flex flex-col items-center gap-1 px-3 py-2 rounded-lg transition-colors relative">
                    
                    <Icon
                      className={`w-6 h-6 transition-colors ${isActive ? 'text-amber-500' : 'text-gray-400'}`} />
                    
                    <span
                      className={`text-[10px] font-medium transition-colors ${isActive ? 'text-amber-500' : 'text-gray-400'}`}>
                      
                      {item.label}
                    </span>
                    {isActive &&
                    <motion.div
                      layoutId="activeTab"
                      className="absolute inset-0 bg-amber-500/10 rounded-lg -z-10"
                      transition={{
                        type: 'spring',
                        stiffness: 300,
                        damping: 30
                      }} />

                    }
                  </button>);

              })}
            </div>
          </div>
        </div>
      </div>
    </div>);

}