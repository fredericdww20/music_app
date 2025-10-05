import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class DenonDevice {
  final String location;
  final String? friendlyName;
  final String? manufacturer;
  final String? modelName;
  final String? controlUrl;
  final String? renderingControlUrl;

  const DenonDevice({
    required this.location,
    this.friendlyName,
    this.manufacturer,
    this.modelName,
    this.controlUrl,
    this.renderingControlUrl,
  });
}

class PositionInfo {
  final Duration position;
  final Duration duration;
  const PositionInfo({required this.position, required this.duration});
}

class DenonCast {
  String? _controlUrl;
  String? _renderingControlUrl;
  DenonDevice? _device;

  bool get isReady => _controlUrl != null;
  DenonDevice? get device => _device;

  // ---------- Découverte ----------
  Future<List<DenonDevice>> discoverAll({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final found = <String, DenonDevice>{};
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    const searchRequest = '''
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: 2
ST: urn:schemas-upnp-org:device:MediaRenderer:1

''';

    socket.send(
      utf8.encode(searchRequest),
      InternetAddress('239.255.255.250'),
      1900,
    );

    final completer = Completer<List<DenonDevice>>();

    socket.listen((event) async {
      if (event != RawSocketEvent.read) return;
      final packet = socket.receive();
      if (packet == null) return;

      final data = utf8.decode(packet.data, allowMalformed: true);
      final lines = data.split(RegExp(r'\r?\n'));
      final locationLine = lines.firstWhere(
        (l) => l.toLowerCase().startsWith('location:'),
        orElse: () => '',
      );
      if (locationLine.isEmpty) return;

      final locationUrl = locationLine.split(':').sublist(1).join(':').trim();
      if (locationUrl.isEmpty || found.containsKey(locationUrl)) return;

      try {
        final device = await _parseDeviceDescription(locationUrl);
        if (device.controlUrl != null) {
          found[locationUrl] = device;
        }
      } catch (_) {}
    });

    Future.delayed(timeout, () {
      try {
        socket.close();
      } finally {
        if (!completer.isCompleted) {
          completer.complete(found.values.toList());
        }
      }
    });

    return completer.future;
  }

  Future<void> connect(DenonDevice device) async {
    final parsed =
        (device.controlUrl == null || device.renderingControlUrl == null)
        ? await _parseDeviceDescription(device.location)
        : device;

    _device = parsed;
    _controlUrl = parsed.controlUrl;
    _renderingControlUrl = parsed.renderingControlUrl;

    if (_controlUrl == null) {
      throw Exception("Pas de controlURL AVTransport pour cet appareil.");
    }
  }

  // ---------- Parsing device description ----------
  String? _findElementTextIgnoreCase(XmlElement root, String tag) {
    for (final el in root.findElements(tag)) {
      return el.innerText;
    }
    for (final el in root.findElements(tag.toLowerCase())) {
      return el.innerText;
    }
    for (final el in root.findElements(tag.toUpperCase())) {
      return el.innerText;
    }
    return null;
  }

  Future<DenonDevice> _parseDeviceDescription(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception("Impossible de charger $url (HTTP ${res.statusCode})");
    }

    final xmlDoc = XmlDocument.parse(res.body);
    final deviceElement = xmlDoc.findAllElements('device').firstOrNull;

    String? friendlyName = deviceElement != null
        ? _findElementTextIgnoreCase(deviceElement, 'friendlyName')
        : null;
    String? manufacturer = deviceElement != null
        ? _findElementTextIgnoreCase(deviceElement, 'manufacturer')
        : null;
    String? modelName = deviceElement != null
        ? _findElementTextIgnoreCase(deviceElement, 'modelName')
        : null;

    String? controlUrl;
    String? renderingControlUrl;
    final base = Uri.parse(url);

    for (final service in xmlDoc.findAllElements('service')) {
      final type = service.getElement('serviceType')?.innerText ?? '';
      final control = service.getElement('controlURL')?.innerText ?? '';
      if (control.isEmpty) continue;

      final controlUri = Uri.parse(control);
      final resolved = controlUri.hasScheme
          ? controlUri
          : base.resolve(control);

      if (type.toLowerCase().contains('avtransport')) {
        controlUrl = resolved.toString();
      } else if (type.toLowerCase().contains('renderingcontrol')) {
        renderingControlUrl = resolved.toString();
      }
    }

    return DenonDevice(
      location: url,
      friendlyName:
          friendlyName ?? modelName ?? manufacturer ?? "Appareil inconnu",
      manufacturer: manufacturer,
      modelName: modelName,
      controlUrl: controlUrl,
      renderingControlUrl: renderingControlUrl,
    );
  }

  // ---------- SOAP générique ----------
  Future<void> _sendSoap(
    String url,
    String service,
    String action,
    Map<String, String> args,
  ) async {
    final body =
        '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
   s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:$action xmlns:u="urn:schemas-upnp-org:service:$service:1">
      <InstanceID>0</InstanceID>
      ${args.entries.map((e) => "<${e.key}>${e.value}</${e.key}>").join()}
    </u:$action>
  </s:Body>
</s:Envelope>
''';

    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": 'text/xml; charset="utf-8"',
        "SOAPACTION": '"urn:schemas-upnp-org:service:$service:1#$action"',
      },
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception(
        "Erreur SOAP $action: HTTP ${res.statusCode} ${res.body}",
      );
    }
  }

  // ---------- AVTransport ----------
  Future<void> playUrl(
    String url, {
    Duration startPosition = Duration.zero,
  }) async {
    if (_controlUrl == null) throw Exception("Pas de controlURL AVTransport");
    await _sendSoap(_controlUrl!, "AVTransport", "SetAVTransportURI", {
      "CurrentURI": url,
      "CurrentURIMetaData": "",
    });
    if (startPosition > Duration.zero) {
      await seek(startPosition);
    }
    await play();
  }

  Future<void> play() async {
    if (_controlUrl == null) return;
    await _sendSoap(_controlUrl!, "AVTransport", "Play", {"Speed": "1"});
  }

  Future<void> pause() async {
    if (_controlUrl == null) return;
    await _sendSoap(_controlUrl!, "AVTransport", "Pause", {});
  }

  Future<void> stop() async {
    if (_controlUrl == null) return;
    await _sendSoap(_controlUrl!, "AVTransport", "Stop", {});
  }

  Future<void> next() async {
    if (_controlUrl == null) return;
    await _sendSoap(_controlUrl!, "AVTransport", "Next", {});
  }

  Future<void> previous() async {
    if (_controlUrl == null) return;
    await _sendSoap(_controlUrl!, "AVTransport", "Previous", {});
  }

  Future<void> seek(Duration position) async {
    if (_controlUrl == null) return;
    final h = position.inHours.toString().padLeft(2, '0');
    final m = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    final target = "$h:$m:$s";
    await _sendSoap(_controlUrl!, "AVTransport", "Seek", {
      "Unit": "REL_TIME",
      "Target": target,
    });
  }

  Future<String?> getTransportState() async {
    if (_controlUrl == null) return null;

    final body = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
   s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetTransportInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:GetTransportInfo>
  </s:Body>
</s:Envelope>
''';

    final res = await http.post(
      Uri.parse(_controlUrl!),
      headers: {
        "Content-Type": 'text/xml; charset="utf-8"',
        "SOAPACTION":
            '"urn:schemas-upnp-org:service:AVTransport:1#GetTransportInfo"',
      },
      body: body,
    );

    if (res.statusCode != 200) return null;

    final xmlDoc = XmlDocument.parse(res.body);
    final nodes = xmlDoc.findAllElements("CurrentTransportState");
    return nodes.isEmpty ? null : nodes.first.innerText.trim();
  }

  Future<PositionInfo?> getPositionInfo() async {
    if (_controlUrl == null) return null;

    final body = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
   s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:GetPositionInfo>
  </s:Body>
</s:Envelope>
''';

    final res = await http.post(
      Uri.parse(_controlUrl!),
      headers: {
        "Content-Type": 'text/xml; charset="utf-8"',
        "SOAPACTION":
            '"urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo"',
      },
      body: body,
    );

    if (res.statusCode != 200) return null;

    final xmlDoc = XmlDocument.parse(res.body);
    final rel = _firstElementText(xmlDoc, "RelTime");
    final dur = _firstElementText(xmlDoc, "TrackDuration");

    return PositionInfo(position: _parseHms(rel), duration: _parseHms(dur));
  }

  Future<Map<String, String>?> getMediaInfo() async {
    if (_controlUrl == null) return null;

    final body = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
   s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetMediaInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:GetMediaInfo>
  </s:Body>
</s:Envelope>
''';

    final res = await http.post(
      Uri.parse(_controlUrl!),
      headers: {
        "Content-Type": 'text/xml; charset="utf-8"',
        "SOAPACTION":
            '"urn:schemas-upnp-org:service:AVTransport:1#GetMediaInfo"',
      },
      body: body,
    );

    if (res.statusCode != 200) return null;

    final xmlDoc = XmlDocument.parse(res.body);
    String? nrTracks = _firstElementText(xmlDoc, "NrTracks");
    String? mediaDuration = _firstElementText(xmlDoc, "MediaDuration");
    String? currentUri = _firstElementText(xmlDoc, "CurrentURI");

    return {
      "NrTracks": nrTracks ?? "",
      "MediaDuration": mediaDuration ?? "",
      "CurrentURI": currentUri ?? "",
    };
  }

  // ---------- RenderingControl ----------
  Future<int?> getVolume() async {
    if (_renderingControlUrl == null) return null;

    final body = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
   s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
      <InstanceID>0</InstanceID>
      <Channel>Master</Channel>
    </u:GetVolume>
  </s:Body>
</s:Envelope>
''';

    final res = await http.post(
      Uri.parse(_renderingControlUrl!),
      headers: {
        "Content-Type": 'text/xml; charset="utf-8"',
        "SOAPACTION":
            '"urn:schemas-upnp-org:service:RenderingControl:1#GetVolume"',
      },
      body: body,
    );

    if (res.statusCode != 200) return null;

    final xmlDoc = XmlDocument.parse(res.body);
    final nodes = xmlDoc.findAllElements("CurrentVolume");
    if (nodes.isEmpty) return null;
    return int.tryParse(nodes.first.innerText);
  }

  Future<void> setVolume(int volume) async {
    if (_renderingControlUrl == null) return;
    final vol = volume.clamp(0, 100);
    await _sendSoap(_renderingControlUrl!, "RenderingControl", "SetVolume", {
      "Channel": "Master",
      "DesiredVolume": vol.toString(),
    });
  }

  Future<bool?> getMute() async {
    if (_renderingControlUrl == null) return null;

    final body = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
   s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetMute xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
      <InstanceID>0</InstanceID>
      <Channel>Master</Channel>
    </u:GetMute>
  </s:Body>
</s:Envelope>
''';

    final res = await http.post(
      Uri.parse(_renderingControlUrl!),
      headers: {
        "Content-Type": 'text/xml; charset="utf-8"',
        "SOAPACTION":
            '"urn:schemas-upnp-org:service:RenderingControl:1#GetMute"',
      },
      body: body,
    );

    if (res.statusCode != 200) return null;

    final xmlDoc = XmlDocument.parse(res.body);
    final nodes = xmlDoc.findAllElements("CurrentMute");
    if (nodes.isEmpty) return null;
    return nodes.first.innerText.trim() == "1";
  }

  Future<void> setMute(bool mute) async {
    if (_renderingControlUrl == null) return;
    await _sendSoap(_renderingControlUrl!, "RenderingControl", "SetMute", {
      "Channel": "Master",
      "DesiredMute": mute ? "1" : "0",
    });
  }

  // ---------- Helpers ----------
  String? _firstElementText(XmlDocument doc, String tag) {
    final nodes = doc.findAllElements(tag);
    return nodes.isEmpty ? null : nodes.first.innerText;
  }

  Duration _parseHms(String? v) {
    if (v == null || v.isEmpty || v.toUpperCase() == 'NOT_IMPLEMENTED') {
      return Duration.zero;
    }
    final parts = v.split(':');
    if (parts.length != 3) return Duration.zero;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return Duration(hours: h, minutes: m, seconds: s);
  }

  // ---------- Durée totale ----------
  Future<Duration> getDuration() async {
    final info = await getMediaInfo();
    if (info == null) return Duration.zero;
    return _parseHms(info["MediaDuration"]);
  }

  Stream<Duration?> getDurationStream({
    Duration interval = const Duration(seconds: 2),
  }) async* {
    while (true) {
      try {
        final dur = await getDuration();
        yield dur;
      } catch (_) {
        yield null;
      }
      await Future.delayed(interval);
    }
  }

  // ---------- Position actuelle (timeline) ----------
  Stream<Duration> getPositionStream({
    Duration interval = const Duration(seconds: 1),
  }) async* {
    while (true) {
      try {
        final info = await getPositionInfo(); // ⚡ requête UPnP à chaque tick
        if (info != null) {
          yield info.position;
        } else {
          yield Duration.zero;
        }
      } catch (_) {
        yield Duration.zero;
      }
      await Future.delayed(interval);
    }
  }
}
