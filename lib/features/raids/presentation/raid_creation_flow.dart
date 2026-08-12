library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/raid_bloc.dart';
import 'bloc/raid_event.dart';
import 'screens/create_raid_screen.dart';

/// Abre la creación de un raid y recarga el [RaidBloc] global cuando la
/// pantalla confirmó una creación exitosa (`pop(true)`).
///
/// Sin este reload, el Radar y la lista de raids conservan datos viejos
/// aunque el raid ya exista en Supabase (el bloc global solo carga en
/// initState). [createScreenBuilder] es un seam de testabilidad: permite
/// sustituir [CreateRaidScreen] en pruebas por un stub que devuelve el
/// resultado del push.
Future<bool> openCreateRaidFlow(
  BuildContext context, {
  WidgetBuilder? createScreenBuilder,
}) async {
  final created = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: createScreenBuilder ?? (_) => const CreateRaidScreen(),
    ),
  );
  if (created == true && context.mounted) {
    context.read<RaidBloc>().add(const LoadRaids());
  }
  return created ?? false;
}
