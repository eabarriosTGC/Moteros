import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Suspensiones propias y apelación. RLS limita la lectura al sancionado.
class MyMotoposadaAppealsScreen extends StatefulWidget {
  const MyMotoposadaAppealsScreen({super.key});
  @override State<MyMotoposadaAppealsScreen> createState()=>_MyMotoposadaAppealsScreenState();
}
class _MyMotoposadaAppealsScreenState extends State<MyMotoposadaAppealsScreen> {
  final _db=Supabase.instance.client;
  late Future<List<Map<String,dynamic>>> _items=_load();
  Future<List<Map<String,dynamic>>> _load() async => (await _db.from('motoposada_user_suspensions').select('id,kind,starts_at,ends_at,lifted_at,motoposada_moderation_appeals(id,status,reason)').order('starts_at',ascending:false) as List).cast();
  Future<void> _appeal(int id) async {
    final c=TextEditingController();
    final reason=await showDialog<String>(context:context,builder:(context)=>AlertDialog(title:const Text('Apelar suspensión'),content:TextField(controller:c,minLines:4,maxLines:8,maxLength:1500,decoration:const InputDecoration(hintText:'Explica por qué debe revisarse (mínimo 20 caracteres)')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,c.text.trim()),child:const Text('Enviar'))]));
    c.dispose(); if(reason==null||reason.length<20)return;
    try { await _db.rpc('appeal_motoposada_suspension',params:{'p_suspension_id':id,'p_reason':reason}); setState(()=>_items=_load()); }
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se pudo apelar: $e')));}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Mis sanciones')),body:FutureBuilder<List<Map<String,dynamic>>>(future:_items,builder:(context,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final rows=s.data!;if(rows.isEmpty)return const Center(child:Text('No tienes sanciones'));return ListView.builder(itemCount:rows.length,itemBuilder:(_,i){final x=rows[i], appeals=(x['motoposada_moderation_appeals'] as List? ?? const []);return Card(child:ListTile(title:Text(x['kind']=='permanent'?'Suspensión permanente':'Suspensión temporal'),subtitle:Text(appeals.isEmpty?'Puedes solicitar una revisión':'Apelación: ${(appeals.first as Map)['status']}'),trailing:appeals.isEmpty&&x['lifted_at']==null?TextButton(onPressed:()=>_appeal(x['id'] as int),child:const Text('APELAR')):null));});}));
}

/// Cola privada de apelaciones para administradores.
class MotoposadaAppealReviewScreen extends StatefulWidget { const MotoposadaAppealReviewScreen({super.key}); @override State<MotoposadaAppealReviewScreen> createState()=>_MotoposadaAppealReviewScreenState(); }
class _MotoposadaAppealReviewScreenState extends State<MotoposadaAppealReviewScreen>{
  final _db=Supabase.instance.client; late Future<List<Map<String,dynamic>>> _items=_load();
  Future<List<Map<String,dynamic>>> _load() async=>(await _db.from('motoposada_moderation_appeals').select('id,reason,status,created_at,suspension_id').eq('status','pending').order('created_at') as List).cast();
  Future<void> _review(int id,bool accept) async {final c=TextEditingController();final note=await showDialog<String>(context:context,builder:(context)=>AlertDialog(title:Text(accept?'Aceptar apelación':'Rechazar apelación'),content:TextField(controller:c,minLines:3,maxLines:6,maxLength:1000),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,c.text.trim()),child:const Text('Confirmar'))]));c.dispose();if(note==null||note.length<10)return;await _db.rpc('review_motoposada_appeal',params:{'p_appeal_id':id,'p_accept':accept,'p_note':note});setState(()=>_items=_load());}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Apelaciones')),body:FutureBuilder<List<Map<String,dynamic>>>(future:_items,builder:(context,s){if(s.hasError)return Center(child:Text('Acceso no disponible: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());return ListView(children:s.data!.map((a)=>Card(child:ListTile(title:Text('Apelación #${a['id']}'),subtitle:Text(a['reason'] as String),isThreeLine:true,trailing:PopupMenuButton<bool>(onSelected:(v)=>_review(a['id'] as int,v),itemBuilder:(_)=>const [PopupMenuItem(value:true,child:Text('Aceptar y levantar')),PopupMenuItem(value:false,child:Text('Rechazar'))])))).toList());}));
}
