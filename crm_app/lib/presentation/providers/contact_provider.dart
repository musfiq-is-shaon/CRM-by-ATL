import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contact_model.dart';
import '../../data/models/company_model.dart';
import '../../data/repositories/contact_repository.dart';
import '../../data/repositories/company_repository.dart';

class ContactsState {
  final List<Contact> contacts;
  final bool isLoading;
  final String? error;
  final String? searchQuery;
  final String? companyIdFilter;

  const ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
    this.companyIdFilter,
  });

  ContactsState copyWith({
    List<Contact>? contacts,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? companyIdFilter,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      companyIdFilter: companyIdFilter ?? this.companyIdFilter,
    );
  }

  List<Contact> get filteredContacts {
    return contacts.where((contact) {
      if (companyIdFilter != null && contact.companyId != companyIdFilter) {
        return false;
      }
      if (searchQuery != null && searchQuery!.isNotEmpty) {
        final query = searchQuery!.toLowerCase();
        return contact.name.toLowerCase().contains(query) ||
            (contact.email?.toLowerCase().contains(query) ?? false) ||
            (contact.mobile?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();
  }
}

class ContactsNotifier extends StateNotifier<ContactsState> {
  final ContactRepository _contactRepository;
  final CompanyRepository _companyRepository;

  ContactsNotifier(this._contactRepository, this._companyRepository)
    : super(const ContactsState());

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final contacts = await _contactRepository.getContacts();

      // Collect all unique company IDs needed
      final companyIds = <String>{};

      for (final contact in contacts) {
        if (contact.companyId != null) {
          companyIds.add(contact.companyId!);
        }
      }

      // Batch fetch all companies in parallel
      final companiesMap = companyIds.isNotEmpty
          ? await _companyRepository.getCompaniesByIds(companyIds.toList())
          : <String, Company>{};

      // Now map contacts with pre-fetched data
      final contactsWithCompany = contacts.map((contact) {
        Company? company;

        // Get company from map
        if (contact.companyId != null &&
            companiesMap.containsKey(contact.companyId)) {
          company = companiesMap[contact.companyId];
        }

        return Contact(
          id: contact.id,
          name: contact.name,
          companyId: contact.companyId,
          company: company,
          designation: contact.designation,
          mobile: contact.mobile,
          email: contact.email,
          createdAt: contact.createdAt,
          updatedAt: contact.updatedAt,
        );
      }).toList();

      state = state.copyWith(contacts: contactsWithCompany, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCompanyFilter(String? companyId) {
    state = state.copyWith(companyIdFilter: companyId);
  }

  void clearFilters() {
    state = state.copyWith(searchQuery: null, companyIdFilter: null);
  }

  Future<void> createContact({
    required String name,
    required String companyId,
    String? designation,
    String? mobile,
    String? email,
  }) async {
    try {
      final contact = await _contactRepository.createContact(
        name: name,
        companyId: companyId,
        designation: designation,
        mobile: mobile,
        email: email,
      );
      state = state.copyWith(contacts: [contact, ...state.contacts]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateContact({
    required String id,
    String? name,
    String? companyId,
    String? designation,
    String? mobile,
    String? email,
  }) async {
    try {
      final contact = await _contactRepository.updateContact(
        id: id,
        name: name,
        companyId: companyId,
        designation: designation,
        mobile: mobile,
        email: email,
      );
      final updatedContacts = state.contacts
          .map((c) => c.id == id ? contact : c)
          .toList();
      state = state.copyWith(contacts: updatedContacts);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      await _contactRepository.deleteContact(id);
      final updatedContacts = state.contacts.where((c) => c.id != id).toList();
      state = state.copyWith(contacts: updatedContacts);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>(
  (ref) {
    final contactRepository = ref.watch(contactRepositoryProvider);
    final companyRepository = ref.watch(companyRepositoryProvider);
    return ContactsNotifier(contactRepository, companyRepository);
  },
);

final contactDetailProvider = FutureProvider.family<Contact, String>((
  ref,
  id,
) async {
  final contactRepository = ref.watch(contactRepositoryProvider);
  return contactRepository.getContactById(id);
});
