import 'package:Bloomee/blocs/explore/cubit/explore_cubits.dart';
import 'package:Bloomee/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/country_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

class LanguageFilterChips extends StatelessWidget {
  const LanguageFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final allLanguages = settingsState.contentLanguages
            .where((lang) => lang != 'English' && lang != 'Hindi')
            .toList();

        if (allLanguages.isEmpty) {
          return const SizedBox.shrink();
        }

        return _LanguageChipsContent(allLanguages: allLanguages);
      },
    );
  }
}

class _LanguageChipsContent extends StatefulWidget {
  final List<String> allLanguages;

  const _LanguageChipsContent({required this.allLanguages});

  @override
  State<_LanguageChipsContent> createState() => _LanguageChipsContentState();
}

class _LanguageChipsContentState extends State<_LanguageChipsContent> {
  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    // Auto-select first language on load
    if (widget.allLanguages.isNotEmpty) {
      selectedLanguage = widget.allLanguages[0];
      // Trigger filter after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<YTMusicCubit>().filterByLanguage(selectedLanguage!);
        }
      });
    }
  }

  void _onLanguageSelected(String language) {
    setState(() {
      // Toggle selection - if already selected, deselect to show all
      if (selectedLanguage == language) {
        selectedLanguage = null;
        // Show all languages
        context.read<YTMusicCubit>().showAllLanguages();
      } else {
        selectedLanguage = language;
        // Filter to selected language
        context.read<YTMusicCubit>().filterByLanguage(language);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...widget.allLanguages.map((lang) {
              final isSelected = selectedLanguage == lang;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onLanguageSelected(lang),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Colors.white : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lang,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Settings chip
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CountrySettings()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MingCute.settings_3_line,
                            color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
