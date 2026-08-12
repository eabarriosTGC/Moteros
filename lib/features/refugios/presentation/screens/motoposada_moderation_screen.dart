import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cola privada de moderación. La RPC verifica `is_admin()`; ocultar esta
/// pantalla en navegación es UX, no una frontera de autorización.
class MotoposadaModerationScreen extends StatefulWidget {
  const MotoposadaModerationScreen({super.key});
  @override
  State<MotoposadaModerationScreen> createState() => _MotoposadaModerationScreenState();
}

class _MotoposadaModerationScreenState extends State<MotoposadaModerationScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _queue = _load();
  String? _filter;

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await _db.rpc('get_motoposada_moderation_queue', params: {'p_status': _filter});
    return (data as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _queue = _load());

  Future<void> _decide(Map<String, dynamic> report) async {
    final result = await showDialog<_Decision>(context: context, builder: (_) => const _DecisionDialog());
    if (result == null || !mounted) return;
    try {
      await _db.rpc('decide_motoposada_incident', params: {
        'p_report_id': report['report_id'], 'p_action': result.action,
        'p_note': result.note, 'p_suspension_until': result.until?.toUtc().toIso8601String(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decisión registrada en el historial')));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo moderar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Moderación de Motoposadas')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<String?>(
        initialValue: _filter, decoration: const InputDecoration(labelText: 'Estado'),
        items: const [DropdownMenuItem(value: null, child: Text('Todos')), DropdownMenuItem(value: 'open', child: Text('Abiertos')), DropdownMenuItem(value: 'reviewing', child: Text('En revisión'))],
        onChanged: (v) { _filter = v; _reload(); },
      )),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _queue, builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Acceso no disponible: ${snap.error}'));
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Center(child: Text('No hay reportes pendientes'));
        return RefreshIndicator(onRefresh: () async { _reload(); await _queue; }, child: ListView.builder(
          itemCount: rows.length, itemBuilder: (_, i) { final r=rows[i]; return Card(child: ListTile(
            title: Text('${r['category']} · #${r['report_id']}'), subtitle: Text('${r['description']}\nEstado: ${r['status']}'),
            isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => _decide(r),
          )); },
        ));
      })),
    ]),
  );
}

class _Decision { final String action; final String note; final DateTime? until; const _Decision(this.action,this.note,this.until); }

class _DecisionDialog extends StatefulWidget { const _DecisionDialog(); @override State<_DecisionDialog> createState()=>_DecisionDialogState(); }
class _DecisionDialogState extends State<_DecisionDialog> {
  String _action='start_review'; final _note=TextEditingController(); DateTime? _until;
  @override void dispose(){_note.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('Decisión administrativa'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(initialValue:_action,items:const [
      DropdownMenuItem(value:'start_review',child:Text('Iniciar revisión')),DropdownMenuItem(value:'dismiss',child:Text('Descartar')),
      DropdownMenuItem(value:'warn',child:Text('Advertir')),DropdownMenuItem(value:'suspend',child:Text('Suspender temporalmente')),DropdownMenuItem(value:'ban',child:Text('Suspender permanentemente')),
    ],onChanged:(v)=>setState(()=>_action=v!)),
    TextField(controller:_note,maxLength:1000,minLines:3,maxLines:6,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Fundamento (mínimo 10 caracteres)')),
    if(_action=='suspend') ListTile(title:Text(_until==null?'Elegir fecha final':_until!.toLocal().toString()),trailing:const Icon(Icons.event),onTap:() async {final d=await showDatePicker(context:context,firstDate:DateTime.now().add(const Duration(days:1)),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)setState(()=>_until=d);}),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),FilledButton(onPressed:_note.text.trim().length<10||(_action=='suspend'&&_until==null)?null:onPressed,child:const Text('Registrar'))]);
  void onPressed()=>Navigator.pop(context,_Decision(_action,_note.text.trim(),_until));
}
