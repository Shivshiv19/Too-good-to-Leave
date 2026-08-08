/// Consumer Protection (E-commerce) Rules 2020 — mandated disclosure.
///
/// **Amendment A19.** Lives in `core/domain` (no repository, no owning
/// feature — §8.3.3) because it's read from `PolicyValues` by both Contact
/// Us (§5f.8) and the Legal grievance document (§5f.9); a single source
/// prevents the two surfaces from independently drifting.
final class GrievanceOfficer {
  const GrievanceOfficer({
    required this.name,
    required this.designation,
    required this.email,
    required this.phone,
    required this.address,
  });

  final String name;
  final String designation;
  final String email;
  final String phone;
  final String address;
}
