import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/club_workflow_repository.dart';

class CreateClubRequestScreen extends StatefulWidget {
  const CreateClubRequestScreen({super.key});
  @override
  State<CreateClubRequestScreen> createState() => _CreateClubRequestScreenState();
}

class _CreateClubRequestScreenState extends State<CreateClubRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _tag = TextEditingController();
  final _city = TextEditingController(), _description = TextEditingController();
  bool _accepted = false, _saving = false;
  @override
  void dispose() { _name.dispose(); _tag.dispose(); _city.dispose(); _description.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (!_form.currentState!.validate() || !_accepted) return;
    setState(() => _saving = true);
    try {
      await ClubWorkflowRepository().requestCreation(_name.text.trim(), _tag.text.trim(), _description.text.trim(), _city.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  String _message(Object e) {
    final s=e.toString();
    if(s.contains('already_in_club')) return 'Ya perteneces a un clan.';
    if(s.contains('creation_request_exists')) return 'Ya tienes una solicitud en revisión.';
    return 'No pudimos enviar la solicitud. Revisa los datos.';
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SOLICITAR CREAR CLAN')),
    body: Form(key:_form,child:ListView(padding:const EdgeInsets.all(AppSpacing.lg),children:[
      Text('El administrador verificará al presidente antes de activar el clan.',style:AppTypography.body.copyWith(color:AppColors.textSecondary)),
      const SizedBox(height:AppSpacing.lg),
      TextFormField(controller:_name,decoration:const InputDecoration(labelText:'Nombre del clan'),validator:(v)=>(v?.trim().length??0)<3?'Mínimo 3 caracteres':null),
      const SizedBox(height:AppSpacing.md),
      TextFormField(controller:_tag,textCapitalization:TextCapitalization.characters,maxLength:10,decoration:const InputDecoration(labelText:'Sigla o TAG'),validator:(v)=>(v?.trim().length??0)<2?'Mínimo 2 caracteres':null),
      TextFormField(controller:_city,decoration:const InputDecoration(labelText:'Ciudad principal'),validator:(v)=>(v?.trim().isEmpty??true)?'Indica la ciudad':null),
      const SizedBox(height:AppSpacing.md),
      TextFormField(controller:_description,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Descripción y evidencia del grupo'),validator:(v)=>(v?.trim().length??0)<20?'Explica el clan en al menos 20 caracteres':null),
      CheckboxListTile(value:_accepted,onChanged:(v)=>setState(()=>_accepted=v??false),title:const Text('Acepto administrar el clan y cumplir las reglas de la comunidad'),controlAffinity:ListTileControlAffinity.leading),
      const SizedBox(height:AppSpacing.md),
      ElevatedButton(onPressed:_saving?null:_submit,child:Text(_saving?'ENVIANDO…':'ENVIAR A VERIFICACIÓN')),
    ])),
  );
}
