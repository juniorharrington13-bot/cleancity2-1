/// Payout rate (XAF per kg) for each `waste_type`, used both to credit
/// collectors on reception and to display the admin waste catalog.
const Map<String, int> wasteXafPerKg = {
  'mixed': 75,
  'plastic': 150,
  'paper': 90,
  'glass': 60,
  'organic': 50,
  'metal': 200,
  'ewaste': 300,
};
