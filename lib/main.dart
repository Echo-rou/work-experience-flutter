import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'services/local_repository.dart';
import 'ui/library_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = WorkLibraryState(LocalRepository());
  await state.initialize();
  runApp(WorkExperienceApp(state: state));
}

class WorkExperienceApp extends StatelessWidget {
  const WorkExperienceApp({super.key, required this.state});
  final WorkLibraryState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Work Experience Library',
        theme: buildTheme(),
        home: LibraryShell(state: state),
      );
}
