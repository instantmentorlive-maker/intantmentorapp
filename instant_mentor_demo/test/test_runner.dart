import 'unit/core/models/user_test.dart' as user_tests;
import 'unit/core/utils/result_test.dart' as result_tests;
import 'unit/data/repositories/mock_auth_repository_test.dart'
    as mock_auth_tests;

void main() {
  // Run all unit tests
  result_tests.main();
  user_tests.main();
  mock_auth_tests.main();
}
