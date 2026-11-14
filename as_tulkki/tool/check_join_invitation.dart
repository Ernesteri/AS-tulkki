import '../lib/join_invitation.dart';
void main() {
  final value=JoinInvitation.parse(Uri.parse('https://example.fi/kerho/as-tulkki/#join=abcdef123456&site=https%3A%2F%2Fexample.fi%2Fkerho%2F'));
  if(value?.site!='https://example.fi/kerho/'||value?.code!='ABCDEF123456')throw StateError('Alikansio / koodi');
  for(final uri in ['https://example.fi/#join=ABCDEF123456&site=https%3A%2F%2Fevil.invalid%2F','https://example.fi/#join=xx&site=https%3A%2F%2Fexample.fi%2F','file:///app#join=ABCDEF123456&site=https%3A%2F%2Fexample.fi%2F','https://example.fi/#join=%ZZ']){
    if(JoinInvitation.parse(Uri.parse(uri))!=null)throw StateError('Virheellinen kutsu hyväksytty');
  }
  print('PASS: QR-linkin jäsennys, alikansio ja virheelliset linkit');
}
