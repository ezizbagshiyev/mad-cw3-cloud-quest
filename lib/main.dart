import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Demo-only options: these are placeholders, not real project credentials.
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      // Synthetic format-valid value for native SDK validation; not a real key.
      apiKey: 'A00000000000000000000000000000000000000',
      appId: '1:1234567890:android:0000000000000000',
      messagingSenderId: '1234567890',
      projectId: 'demo-cloud-quest',
    ),
  );
  const host = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  // Always connect to emulators; this submission never accesses production.
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  runApp(const CloudQuestApp());
}

class CloudQuestApp extends StatelessWidget {
  const CloudQuestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cloud Quest',
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null
            ? const SignInScreen()
            : ChallengeScreen(key: ValueKey(user.uid), user: user);
      },
    ),
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String message = '';

  Future<void> authenticate(bool register) async {
    if (email.text.trim().isEmpty || password.text.length < 6) {
      setState(
        () =>
            message = 'Enter an email and a password of at least 6 characters.',
      );
      return;
    }
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final auth = FirebaseAuth.instance;
      if (register) {
        await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (_) {
      if (mounted)
        setState(
          () => message = 'Unable to sign in or register. Check your details and emulator connection, then retry.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => message = 'Service unavailable. Check the emulators and retry.',
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cloud Quest')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Sign in to view your challenge and private progress.'),
          const Text('Local Firebase emulators · use a test account only'),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          FilledButton(
            onPressed: loading ? null : () => authenticate(false),
            child: Text(loading ? 'Please wait…' : 'Sign in'),
          ),
          OutlinedButton(
            onPressed: loading ? null : () => authenticate(true),
            child: const Text('Register'),
          ),
          Text(message),
        ],
      ),
    ),
  );
}

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.user});
  final User user;
  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final question = TextEditingController();
  Map<String, dynamic>? challenge;
  Map<String, dynamic>? progress;
  bool busy = false;
  String message = '';
  String reply = '';
  String coachMode = 'unknown';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final db = FirebaseFirestore.instance;
      final quest = await db.doc('challenges/today').get();
      final state = await db
          .doc('users/${widget.user.uid}/progress/today')
          .get();
      if (!mounted) return;
      setState(() {
        challenge = quest.data();
        progress = state.data();
        if (challenge == null)
          message = 'Challenge missing. Run the seed script and retry.';
      });
    } catch (_) {
      if (mounted)
        setState(
          () => message =
              'Could not load the challenge. Check the emulators and retry.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(bool coach) async {
    final text = question.text.trim();
    if (coach && (text.isEmpty || text.length > 300)) {
      setState(() => message = 'Enter a question of 1–300 characters.');
      return;
    }
    setState(() {
      busy = true;
      message = '';
      if (coach) reply = '';
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable(coach ? 'askQuestCoach' : 'completeToday')
          .call<Map<String, dynamic>>(
            coach ? {'question': text} : {'challengeId': 'today'},
          );
      if (!mounted) return;
      setState(() {
        if (coach) {
          reply = result.data['reply'] as String;
          coachMode = result.data['mode'] as String? ?? 'demo';
        } else {
          progress = result.data;
          message = result.data['alreadyCompleted'] == true
              ? 'Already completed. No extra points or badge awarded.'
              : 'Completed! You earned 10 points and the First Quest badge.';
        }
      });
    } on FirebaseFunctionsException catch (error) {
      // Log only the code, never request data, tokens, or credentials.
      debugPrint('Cloud Quest callable failed: ${error.code}');
      if (mounted) {
        setState(
          () => message =
              'Service error (${error.code}). Check the emulators and retry.',
        );
      }
    } catch (error) {
      debugPrint('Cloud Quest callable failed: ${error.runtimeType}');
      if (mounted) {
        setState(
          () =>
              message = 'Request failed (${error.runtimeType}). Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) setState(() => message = 'Sign-out failed. Please retry.');
    }
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cloud Quest'),
      actions: [
        TextButton(
          onPressed: busy ? null : signOut,
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Signed in as ${widget.user.email ?? widget.user.uid}'),
          Text(
            "Today's challenge",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (busy) const LinearProgressIndicator(),
          if (challenge != null) ...[
            Text(challenge!['title'] as String? ?? ''),
            Text(challenge!['prompt'] as String? ?? ''),
            const SizedBox(height: 16),
            Text('Points: ${progress?['points'] ?? 0}'),
            Text(
              progress?['badgeId'] == 'first-quest'
                  ? 'Badge: First Quest'
                  : 'Badge: none',
            ),
            FilledButton(
              onPressed: busy ? null : () => act(false),
              child: Text(
                progress?['completed'] == true
                    ? 'Retry completion'
                    : 'Complete challenge',
              ),
            ),
            TextField(
              controller: question,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Ask the Quest Coach for a hint',
              ),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => act(true),
              child: const Text('Get hint'),
            ),
            Text(
              coachMode == 'unknown'
                  ? 'Coach mode is shown after a successful hint.'
                  : coachMode == 'demo'
                  ? 'Emulator coach demo - not a live AI model'
                  : 'Live AI coach',
            ),
            SelectableText(reply),
          ],
          Text(message),
          TextButton(
            onPressed: busy ? null : load,
            child: const Text('Reload / retry'),
          ),
        ],
      ),
    ),
  );
}
