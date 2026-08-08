import 'package:url_launcher/url_launcher.dart';

/// Opens the device's map app centred on [lat]/[lng] (§5d.1/§5d.2/§5d.3's
/// "Directions" action).
///
/// **Deliberately a deep link, not an embedded `google_maps_flutter`
/// view** — launching an external maps app needs no API key, unlike
/// rendering a map surface in-app (the still-open D-32/D-40 gap). Returns
/// whether the launch succeeded so the caller can fall back to showing the
/// address as text.
Future<bool> openDirections(double lat, double lng) {
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$lat,$lng',
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
