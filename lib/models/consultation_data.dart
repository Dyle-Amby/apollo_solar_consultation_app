class ConsultationData {
  // Step 1
  String fullName = '';
  String contactNumber = '';
  String email = '';
  String propertyType = '';
  String address = '';
  double latitude = 0;
  double longitude = 0;

  // Step 2
  String primaryGoal = '';
  String systemType = 'Grid-tied'; // or 'Hybrid'

  // Step 3
  double monthlyBill = 0;
  String distributionUtility = '';
  double ratePerKwh = 0;

  // Step 4
  String roofMaterial = '';
  double roofLength = 0;
  double roofWidth = 0;
  String roofDirection = '';
  String obstructions = '';

  // Step 5 (only if Hybrid)
  double backupHours = 0;

  // Step 6
  double budgetRange = 0;
  String timeline = '';

  // Step 7 calculator inputs
  double daysInMonth = 30;
  double sunPeakHours = 4.5;
  double systemLoss = 20;
  double wattsPerPanel = 550;
  double panelVmp = 41.6;
  double panelVoc = 49.8;
  double depthOfDischarge = 80;
  double inverterEfficiency = 95;
  double systemVoltage = 48;

  // Step 10
  String salesOutcome = ''; // 'closed' or 'lost'
  DateTime? deliveryDate;
}