import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import 'tv_settings_screen.dart';

class TvAccountScreen extends StatelessWidget {
  const TvAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 30, 30),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 18),
          const _SectionTitle('Koleksi Cepat'),
          _Panel(children: [
            _ActionRow(icon: Icons.history_rounded, title: 'Riwayat', subtitle: 'Lanjutkan tontonan terakhir.', autofocus: true, onTap: () {}),
            _ActionRow(icon: Icons.favorite_border_rounded, title: 'Favorit', subtitle: 'Buka judul yang disimpan.', onTap: () {}),
            _ActionRow(icon: Icons.settings_rounded, title: 'Pengaturan', subtitle: 'Tampilan, player, subtitle, dan source.', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TvSettingsScreen()))),
          ]),
          const SizedBox(height: 16),
          const _SectionTitle('Aplikasi'),
          _Panel(children: [
            _ActionRow(icon: Icons.download_rounded, title: 'Periksa Pembaruan', subtitle: 'Cek versi terbaru LiveGO.', onTap: () {}),
            _ActionRow(icon: Icons.info_outline_rounded, title: 'Tentang LiveGO', subtitle: 'LiveGO Premium • Anichin API • Android TV.', onTap: () {}),
          ]),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0B2634), Color(0xFF080D17)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E3850)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]), border: Border.all(color: AppTheme.cyan.withOpacity(0.65))),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Penggemar LiveGO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 5),
                Text('Default: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()}', style: const TextStyle(color: AppTheme.textSoft, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF09111E).withOpacity(0.94), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF1A2D43))),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool autofocus;
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.autofocus = false});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool focused = false;

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onKeyEvent: _key,
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 74,
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: focused ? const Color(0xFF102F45) : Colors.transparent, borderRadius: BorderRadius.circular(19), border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2)),
          child: Row(
            children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFF102033), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)), child: Icon(widget.icon, color: Colors.white, size: 25)),
              const SizedBox(width: 18),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 3),
                Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
              ])),
              Icon(Icons.arrow_forward_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 27),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1, decoration: TextDecoration.none)),
    );
  }
}
