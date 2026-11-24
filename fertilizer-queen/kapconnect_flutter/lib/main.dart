import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/shell.dart';
import 'state/jobs_state.dart';
import 'theme.dart';

void main() => runApp(const KapConnectApp());

class KapConnectApp extends StatelessWidget {
  const KapConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JobsState()),
        ChangeNotifierProvider(create: (_) => AppNav()),
      ],
      child: MaterialApp(
        title: 'KapConnect',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Shell(),
      ),
    );
  }
}
