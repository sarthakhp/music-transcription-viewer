/// The instruments the transcriber can be told to look for. The [id]s are the
/// model's own group names and must match the backend's list
/// (src/instrument_transcription/muscriptor_instruments.py). Voice and drums are
/// left out: voice has its own transcriber and drums are not shown.
enum InstrumentFamily {
  keys('Keys'),
  guitars('Guitars'),
  basses('Basses'),
  strings('Strings'),
  brass('Brass'),
  reeds('Reeds'),
  winds('Winds'),
  synths('Synths'),
  percussion('Percussion');

  const InstrumentFamily(this.label);
  final String label;
}

class InstrumentOption {
  final String id;
  final String label;
  final InstrumentFamily family;

  /// Other words someone might search for, e.g. "harmonium" finds the organ.
  final List<String> aliases;

  const InstrumentOption(this.id, this.label, this.family, [this.aliases = const []]);

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label.toLowerCase().contains(q) ||
        id.replaceAll('_', ' ').contains(q) ||
        family.label.toLowerCase().contains(q) ||
        aliases.any((a) => a.contains(q));
  }
}

const instrumentCatalog = <InstrumentOption>[
  InstrumentOption('acoustic_piano', 'Piano', InstrumentFamily.keys, ['keyboard', 'grand', 'upright']),
  InstrumentOption('electric_piano', 'Electric piano', InstrumentFamily.keys, ['rhodes', 'keyboard']),
  InstrumentOption('organ', 'Organ / harmonium', InstrumentFamily.keys, ['harmonium', 'accordion', 'keyboard']),
  InstrumentOption('chromatic_percussion', 'Bells, vibraphone, marimba', InstrumentFamily.percussion,
      ['glockenspiel', 'xylophone', 'celesta', 'tuned percussion']),
  InstrumentOption('timpani', 'Timpani', InstrumentFamily.percussion, ['kettledrum']),
  InstrumentOption('acoustic_guitar', 'Acoustic guitar', InstrumentFamily.guitars, ['guitar', 'nylon', 'steel string']),
  InstrumentOption('clean_electric_guitar', 'Electric guitar (clean)', InstrumentFamily.guitars, ['guitar']),
  InstrumentOption('distorted_electric_guitar', 'Electric guitar (distorted)', InstrumentFamily.guitars,
      ['guitar', 'overdrive', 'rock']),
  InstrumentOption('acoustic_bass', 'Acoustic bass', InstrumentFamily.basses, ['upright', 'double bass']),
  InstrumentOption('electric_bass', 'Electric bass', InstrumentFamily.basses, ['bass guitar']),
  InstrumentOption('contrabass', 'Contrabass', InstrumentFamily.basses, ['double bass']),
  InstrumentOption('violin', 'Violin', InstrumentFamily.strings, ['fiddle']),
  InstrumentOption('viola', 'Viola', InstrumentFamily.strings),
  InstrumentOption('cello', 'Cello', InstrumentFamily.strings),
  InstrumentOption('orchestral_harp', 'Harp', InstrumentFamily.strings),
  InstrumentOption('string_ensemble', 'String section', InstrumentFamily.strings, ['orchestra', 'violins']),
  InstrumentOption('synth_strings', 'Synth strings', InstrumentFamily.synths),
  InstrumentOption('orchestra_hit', 'Orchestra hit', InstrumentFamily.brass, ['stab']),
  InstrumentOption('trumpet', 'Trumpet', InstrumentFamily.brass),
  InstrumentOption('trombone', 'Trombone', InstrumentFamily.brass),
  InstrumentOption('tuba', 'Tuba', InstrumentFamily.brass),
  InstrumentOption('french_horn', 'French horn', InstrumentFamily.brass, ['horn']),
  InstrumentOption('brass_section', 'Brass section', InstrumentFamily.brass),
  InstrumentOption('soprano_and_alto_sax', 'Soprano / alto sax', InstrumentFamily.reeds, ['saxophone']),
  InstrumentOption('tenor_sax', 'Tenor sax', InstrumentFamily.reeds, ['saxophone']),
  InstrumentOption('baritone_sax', 'Baritone sax', InstrumentFamily.reeds, ['saxophone']),
  InstrumentOption('oboe', 'Oboe', InstrumentFamily.reeds, ['shehnai', 'double reed']),
  InstrumentOption('english_horn', 'English horn', InstrumentFamily.reeds),
  InstrumentOption('bassoon', 'Bassoon', InstrumentFamily.reeds),
  InstrumentOption('clarinet', 'Clarinet', InstrumentFamily.reeds),
  InstrumentOption('flutes', 'Flute / bansuri', InstrumentFamily.winds, ['bansuri', 'flute', 'piccolo', 'recorder', 'whistle']),
  InstrumentOption('synth_lead', 'Synth lead', InstrumentFamily.synths),
  InstrumentOption('synth_pad', 'Synth pad', InstrumentFamily.synths),
];

/// The options matching [query] (all of them for an empty query), in catalogue order.
List<InstrumentOption> searchInstruments(String query) =>
    [for (final option in instrumentCatalog) if (option.matches(query)) option];

InstrumentOption? instrumentById(String id) {
  for (final option in instrumentCatalog) {
    if (option.id == id) return option;
  }
  return null;
}
