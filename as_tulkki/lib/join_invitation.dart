/// QR-linkin tiedot esitäytetään, mutta liittyminen vaatii nimen ja painalluksen.
class JoinInvitation {
  const JoinInvitation(this.site, this.code);
  final String site;
  final String code;

  static JoinInvitation? parse(Uri location) {
    if (location.scheme != 'https' || location.host.isEmpty) return null;
    try {
      final fields = Uri.splitQueryString(location.fragment);
      final code = (fields['join'] ?? '').toUpperCase();
      final site = Uri.tryParse(fields['site'] ?? '');
      if (!RegExp(r'^[A-F0-9]{12}$').hasMatch(code) ||
          site == null ||
          site.scheme != 'https' ||
          site.host.isEmpty ||
          site.userInfo.isNotEmpty ||
          site.hasQuery ||
          site.hasFragment ||
          site.origin != location.origin)
        return null;
      return JoinInvitation(site.toString(), code);
    } on FormatException {
      return null;
    }
  }
}
