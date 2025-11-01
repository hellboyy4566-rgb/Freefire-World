import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasData) return const HomeScreen();
        return SignInScreen();
      },
    );
  }
}

class SignInScreen extends StatelessWidget {
  Future<void> signIn() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;
    final auth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(idToken: auth.idToken, accessToken: auth.accessToken);
    await FirebaseAuth.instance.signInWithCredential(cred);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'wallet_balance': 20,
        'lastLoginBonusAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(child: const Text("Sign in with Google"), onPressed: signIn),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text("Freefire World")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final ref = FirebaseFirestore.instance.collection('users').doc(uid);
            final doc = await ref.get();
            final last = doc['lastLoginBonusAt'];
            final now = DateTime.now().toUtc();
            bool give = true;
            if (last != null) {
              final dt = (last as Timestamp).toDate().toUtc();
              give = dt.day != now.day || dt.month != now.month || dt.year != now.year;
            }
            if (give) {
              await ref.update({
                'wallet_balance': (doc['wallet_balance'] ?? 0) + 5,
                'lastLoginBonusAt': FieldValue.serverTimestamp(),
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily bonus added!')));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already claimed today')));
            }
          },
          child: const Text('Claim Daily Bonus'),
        ),
      ),
    );
  }
}
