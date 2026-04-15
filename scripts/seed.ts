import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL || 'http://localhost:54321';
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || 'your-anon-key';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'your-service-role-key';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function seed() {
  console.log('🌱 Seeding database with test data...');

  // Seed users
  const { data: users, error: usersError } = await supabase
    .from('users')
    .insert([
      {
        email: 'admin@moteros.com',
        full_name: 'Admin User',
        phone: '+1234567890',
        membership_status: 'active',
        role: 'admin',
      },
      {
        email: 'member@moteros.com',
        full_name: 'Test Member',
        phone: '+1234567891',
        membership_status: 'active',
        role: 'user',
      },
      {
        email: 'aspirant@moteros.com',
        full_name: 'Test Aspirant',
        phone: '+1234567892',
        membership_status: 'pending',
        role: 'user',
      },
    ])
    .select();

  if (usersError) {
    console.error('Error seeding users:', usersError);
  } else {
    console.log(`✅ Seeded ${users.length} users`);
  }

  // Seed places
  const { data: places, error: placesError } = await supabase
    .from('places')
    .insert([
      {
        name: 'Café Motero Central',
        description: 'El punto de encuentro favorito de los moteros',
        address: 'Calle Principal 123, Ciudad',
        latitude: 40.4168,
        longitude: -3.7038,
        category: 'cafe',
        is_approved: true,
      },
      {
        name: 'Mirador del Puerto',
        description: 'Vista espectacular al mar, perfecto para fotos con motos',
        address: 'Puerto Deportivo, Muelle 5',
        latitude: 40.4530,
        longitude: -3.6883,
        category: 'mirador',
        is_approved: true,
      },
      {
        name: 'Restaurante La Ruta',
        description: 'Comida abundante para después de una ruta en moto',
        address: 'Av. de la Moto 456',
        latitude: 40.4300,
        longitude: -3.7100,
        category: 'restaurante',
        is_approved: true,
      },
    ])
    .select();

  if (placesError) {
    console.error('Error seeding places:', placesError);
  } else {
    console.log(`✅ Seeded ${places.length} places`);
  }

  // Seed posadas
  const { data: posadas, error: posadasError } = await supabase
    .from('posadas')
    .insert([
      {
        name: 'Ruta por la Sierra - Enero 2026',
        description: 'Ruta de fin de semana por la sierra norte',
        location: 'Sierra Norte',
        date: '2026-01-15T10:00:00Z',
        organizer_id: users?.[0]?.id || '',
        max_participants: 30,
        images: [],
      },
    ])
    .select();

  if (posadasError) {
    console.error('Error seeding posadas:', posadasError);
  } else {
    console.log(`✅ Seeded ${posadas.length} posadas`);
  }

  // Seed challenges
  if (users && users[2]) {
    const { data: aspirants, error: aspirantsError } = await supabase
      .from('aspirants')
      .insert([
        {
          user_id: users[2].id,
          status: 'in_review',
        },
      ])
      .select();

    if (aspirantsError) {
      console.error('Error seeding aspirants:', aspirantsError);
    } else {
      console.log(`✅ Seeded ${aspirants.length} aspirants`);

      if (aspirants && aspirants[0]) {
        const { data: challenges, error: challengesError } = await supabase
          .from('challenges')
          .insert([
            {
              aspirant_id: aspirants[0].id,
              title: 'Primera ruta grupal',
              description: 'Participar en al menos una ruta grupal',
              status: 'pending',
            },
            {
              aspirant_id: aspirants[0].id,
              title: 'Foto en lugar emblemático',
              description: 'Tomar una foto en un lugar motero reconocido',
              status: 'pending',
            },
          ])
          .select();

        if (challengesError) {
          console.error('Error seeding challenges:', challengesError);
        } else {
          console.log(`✅ Seeded ${challenges.length} challenges`);
        }
      }
    }
  }

  console.log('\n🎉 Database seeding completed!');
  console.log('\nTest accounts:');
  console.log('  Admin: admin@moteros.com');
  console.log('  Member: member@moteros.com');
  console.log('  Aspirant: aspirant@moteros.com');
}

seed().catch(console.error);
