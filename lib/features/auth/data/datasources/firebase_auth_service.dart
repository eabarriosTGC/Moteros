import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  Future<void> initialize() async {
    _googleSignIn = GoogleSignIn.instance;
    await _googleSignIn!.initialize();
  }

  Future<void> ensureInitialized() async {
    if (_googleSignIn == null) await initialize();
  }

  /// Inicia sesión con Google y retorna el ID token + datos del usuario
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      await ensureInitialized();

      // Flujo de autenticación Google (v7 API)
      final GoogleSignInAccount googleUser =
          await _googleSignIn!.authenticate();

      // Obtener ID token
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return {'success': false, 'error': 'No se pudo obtener el ID token'};
      }

      // Crear credencial de Firebase con el token de Google
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      // Iniciar sesión en Firebase
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final User? user = userCredential.user;

      return {
        'success': true,
        'idToken': idToken,
        'email': user?.email ?? googleUser.email,
        'displayName': user?.displayName ?? googleUser.displayName ?? '',
        'photoUrl': user?.photoURL ?? googleUser.photoUrl ?? '',
        'uid': user?.uid ?? googleUser.id,
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.message ?? 'Error de autenticación'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cerrar sesión en Google y Firebase
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _firebaseAuth.signOut();
  }
}
