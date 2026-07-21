enum ScanMode { qr, vision }

enum ScanViewState {
  searching,
  found,
  error,
  permissionDenied,
  lowLight,
  noMatch,
  visionCapturing,
  visionAnalyzing,
  visionFound,
  visionNoMatch,
}

enum AiGuideViewState { empty, conversation, listening, error }

enum NavigationViewState { setup, preview, active, rerouting, unavailable }

enum TicketCheckoutState { review, paymentMethod, processing, success }

class UiArtifactSummary {
  const UiArtifactSummary({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.period,
    this.imageUrl = '',
    this.saved = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final String period;
  final String imageUrl;
  final bool saved;
}

class UiScanRecord {
  const UiScanRecord({
    required this.artifactName,
    required this.scannedAt,
    required this.locationHint,
    this.status = 'Recognized',
  });

  final String artifactName;
  final String scannedAt;
  final String locationHint;
  final String status;
}

class UiEventItem {
  const UiEventItem({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.location,
    required this.description,
    this.imageUrl = '',
    this.isUnread = false,
  });

  final String id;
  final String title;
  final String dateLabel;
  final String location;
  final String description;
  final String imageUrl;
  final bool isUnread;
}

class UiTicketOrderDraft {
  const UiTicketOrderDraft({
    required this.adult,
    required this.student,
    required this.international,
    required this.donationLabel,
    required this.totalLabel,
    this.donationAmountUsd = 0,
    this.totalAmountMwk = 0,
    this.isMonthlyDonation = false,
  });

  final int adult;
  final int student;
  final int international;
  final String donationLabel;
  final String totalLabel;
  final int donationAmountUsd;
  final int totalAmountMwk;
  final bool isMonthlyDonation;
}

class UiRoutePreview {
  const UiRoutePreview({
    required this.start,
    required this.destination,
    required this.etaLabel,
    required this.distanceLabel,
  });

  final String start;
  final String destination;
  final String etaLabel;
  final String distanceLabel;
}

class UiAiMessage {
  const UiAiMessage({
    required this.id,
    required this.text,
    required this.isVisitor,
    this.timestamp = '',
  });

  final String id;
  final String text;
  final bool isVisitor;
  final String timestamp;
}
