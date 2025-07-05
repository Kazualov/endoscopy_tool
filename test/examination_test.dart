import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endoscopy_tool/pages/main_page.dart';

void main() {
  group('Examination model', () {
    test('fromJson should parse correctly', () {
      final json = {
        'id': '123',
        'patient_id': '456',
        'description': 'Тестовое обследование',
        'video_id': '789',
      };

      final exam = Examination.fromJson(json);

      expect(exam.id, '123');
      expect(exam.patientId, '456');
      expect(exam.description, 'Тестовое обследование');
      expect(exam.video_id, '789');
    });
  });

  group('Patient model', () {
    test('fromJson should parse correctly', () {
      final json = {
        'id': '1',
        'name': 'Иван Иванов',
      };

      final patient = Patient.fromJson(json);

      expect(patient.id, '1');
      expect(patient.name, 'Иван Иванов');
    });
  });

  group('ExaminationGridScreen logic', () {
    final exampleExaminations = [
      Examination(id: 'EX123', patientId: 'P1'),
      Examination(id: 'EX456', patientId: 'P2'),
      Examination(id: 'TEST789', patientId: 'P3'),
    ];

    test('filteredExamination filters by search query', () {
      final state = _MockExaminationGridScreenState();
      state.examinations = exampleExaminations;
      state.searchQuery = 'EX';

      final result = state.filteredExamination;

      expect(result.length, 2);
      expect(result[0].id, 'EX123');
      expect(result[1].id, 'EX456');
    });

    test('getPatientName returns name by ID or fallback', () {
      final state = _MockExaminationGridScreenState();
      state.patients = [
        Patient(id: '1', name: 'Анна'),
        Patient(id: '2', name: 'Борис'),
      ];

      expect(state.getPatientName('1'), 'Анна');
      expect(state.getPatientName('999'), 'Неизвестный пациент');
    });
  });
}

// Вспомогательный мок состояния без UI
class _MockExaminationGridScreenState {
  List<Examination> examinations = [];
  List<Patient> patients = [];
  String searchQuery = '';

  List<Examination> get filteredExamination {
    if (searchQuery.isEmpty) return examinations;
    return examinations
        .where((e) => e.id.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  String getPatientName(String patientId) {
    final patient = patients.firstWhere(
          (p) => p.id == patientId,
      orElse: () => Patient(id: '', name: 'Неизвестный пациент'),
    );
    return patient.name;
  }
}
