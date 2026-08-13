import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/club_workflow_repository.dart';
import 'create_club_request_screen.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});
  @override State<ClubsScreen> createState()=>_ClubsScreenState();
}
class _ClubsScreenState extends State<ClubsScreen> with SingleTickerProviderStateMixin {
  final _repo=ClubWorkflowRepository(); late final TabController _tabs;
  bool _loading=true,_admin=false; String? _error; Map<String,dynamic>? _membership;
  List<Map<String,dynamic>> _clubs=[],_myRequests=[],_incoming=[],_members=[],_pending=[];
  bool get _manager => ['presidente','oficial'].contains(_membership?['role']);
  @override void initState(){super.initState();_tabs=TabController(length:3,vsync:this);_load();}
  @override void dispose(){_tabs.dispose();super.dispose();}
  Future<void> _load() async {setState((){_loading=true;_error=null;});try{
    final clubs=await _repo.clubs(), membership=await _repo.myMembership(), requests=await _repo.myRequests(), admin=await _repo.isAdmin();
    List<Map<String,dynamic>> incoming=[],members=[],pending=[];
    if(membership!=null){final id=membership['club_id'] as int;members=await _repo.members(id);if(['presidente','oficial'].contains(membership['role']))incoming=await _repo.requestsFor(id);}
    if(admin) pending=await _repo.pendingClubs();
    if(mounted)setState((){_clubs=clubs;_membership=membership;_myRequests=requests;_admin=admin;_incoming=incoming;_members=members;_pending=pending;_loading=false;});
  }catch(e){if(mounted)setState((){_error=e.toString();_loading=false;});}}
  Future<void> _act(Future<void> Function() action,String ok) async {try{await action();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok)));await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se pudo completar: ${e.toString().split('\n').first}')));}}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('CLANES'),bottom:TabBar(controller:_tabs,isScrollable:true,tabs:[const Tab(text:'DESCUBRIR'),Tab(text:_manager?'MI CLAN · GESTIÓN':'MI CLAN'),Tab(text:_admin?'VERIFICAR':'SOLICITUDES')])),
    body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?_failure():TabBarView(controller:_tabs,children:[_discover(),_mine(),_admin?_verification():_requests()]),
    floatingActionButton:_membership==null?FloatingActionButton.extended(onPressed:()async{if(await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>const CreateClubRequestScreen()))==true)_load();},icon:const Icon(Icons.add),label:const Text('CREAR CLAN')):null,
  );
  Widget _failure()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.cloud_off,color:AppColors.error,size:48),const SizedBox(height:12),const Text('No pudimos cargar los clanes'),OutlinedButton(onPressed:_load,child:const Text('REINTENTAR'))]));
  Widget _discover()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
    if (_clubs.isEmpty) const _Empty(icon: Icons.groups_outlined, text: 'Todavía no hay clanes verificados.'),
    ..._clubs.map(
      (c) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text((c['tag'] ?? '?').toString().substring(0, 1))),
          title: Text(c['name'] ?? ''),
          subtitle: Text(
            '[${c['tag']}] · ${c['description'] ?? 'Sin descripción'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _membership == null
              ? TextButton(onPressed: () => _join(c), child: const Text('SOLICITAR'))
              : null,
        ),
      ),
    ),
  ]));
  Future<void> _join(Map<String,dynamic> c) async {final ctl=TextEditingController();final send=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Ingresar a ${c['name']}'),content:TextField(controller:ctl,maxLength:500,minLines:2,maxLines:4,decoration:const InputDecoration(hintText:'Cuéntales por qué quieres ingresar')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('CANCELAR')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ENVIAR'))]));final msg=ctl.text;ctl.dispose();if(send==true)await _act(()=>_repo.requestJoin(c['id'] as int,msg),'Solicitud enviada al presidente.');}
  Widget _mine(){if(_membership==null)return const _Empty(icon:Icons.group_off_outlined,text:'Aún no perteneces a un clan. Busca uno y envía tu solicitud.');final club=Map<String,dynamic>.from(_membership!['clubs'] as Map);return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(club['name']??'',style:AppTypography.h2),Text('[${club['tag']}] · Rol: ${_membership!['role']}'),if(_membership!['role']!='presidente')Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>_act(()=>_repo.leave(club['id'] as int),'Saliste del clan.'),child:const Text('SALIR DEL CLAN')))]))),
    if(_manager)...[const _Heading('SOLICITUDES PENDIENTES'),if(_incoming.isEmpty)const Text('No hay solicitudes pendientes.'),..._incoming.map((r)=>Card(child:ListTile(title:Text(_userName(r['users'])),subtitle:Text(r['message']?.toString().isEmpty==false?r['message']:'Sin mensaje'),trailing:Wrap(children:[IconButton(tooltip:'Rechazar',icon:const Icon(Icons.close,color:AppColors.error),onPressed:()=>_act(()=>_repo.reviewJoin(r['id'] as int,false),'Solicitud rechazada.')),IconButton(tooltip:'Aceptar',icon:const Icon(Icons.check,color:AppColors.success),onPressed:()=>_act(()=>_repo.reviewJoin(r['id'] as int,true),'Nuevo miembro aceptado.'))]))))],
    const _Heading('MIEMBROS'),..._members.map((m)=>ListTile(leading:const Icon(Icons.person_outline),title:Text(_userName(m['users'])),subtitle:Text(m['role']??''))),
  ]));}
  Widget _requests()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[const _Heading('MIS SOLICITUDES'),if(_myRequests.isEmpty)const _Empty(icon:Icons.mark_email_unread_outlined,text:'No has enviado solicitudes.'),..._myRequests.map((r){final c=Map<String,dynamic>.from(r['clubs'] as Map);return Card(child:ListTile(title:Text(c['name']??''),subtitle:Text('Estado: ${r['status']}'),trailing:_statusIcon(r['status'])));})]));
  Widget _verification() => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Heading('CLANES POR VERIFICAR'),
            if (_pending.isEmpty)
              const _Empty(icon: Icons.verified_outlined, text: 'No hay solicitudes pendientes.'),
            ..._pending.map(
              (c) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c['name']} [${c['tag']}]', style: AppTypography.h3),
                      Text(c['description'] ?? ''),
                      Text('Presidente: ${_userName(c['users'])}'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => _rejectClub(c), child: const Text('RECHAZAR')),
                          ElevatedButton(
                            onPressed: () => _act(
                                () => _repo.reviewClub(c['id'] as int, true, ''),
                                'Clan y presidente verificados.'),
                            child: const Text('APROBAR'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  Future<void> _rejectClub(Map<String,dynamic> c) async {final ctl=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Motivo del rechazo'),content:TextField(controller:ctl,minLines:2,maxLines:4),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('CANCELAR')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('RECHAZAR'))]));final reason=ctl.text;ctl.dispose();if(ok==true)await _act(()=>_repo.reviewClub(c['id'] as int,false,reason),'Solicitud rechazada.');}
  String _userName(dynamic raw){if(raw is! Map)return 'Motero';return (raw['full_name']??raw['username']??'Motero').toString();}
  Widget _statusIcon(dynamic s)=>Icon(s=='approved'?Icons.check_circle:s=='rejected'?Icons.cancel:Icons.schedule,color:s=='approved'?AppColors.success:s=='rejected'?AppColors.error:AppColors.warning);
}
class _Heading extends StatelessWidget{const _Heading(this.text);final String text;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(top:20,bottom:10),child:Text(text,style:AppTypography.caption.copyWith(color:AppColors.textMuted,letterSpacing:1.4)));}
class _Empty extends StatelessWidget{const _Empty({required this.icon,required this.text});final IconData icon;final String text;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(32),child:Column(children:[Icon(icon,size:48,color:AppColors.textMuted),const SizedBox(height:12),Text(text,textAlign:TextAlign.center,style:AppTypography.body.copyWith(color:AppColors.textSecondary))]));}
