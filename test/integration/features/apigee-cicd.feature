Feature: Apigee CI/CD Demo - API Proxy Integration Tests

  Scenario: Verify API proxy deployment and KVM secret injection
    When I GET /mock/v1/echo
    Then response code should be 200
    And response body should be valid json
    And response header x-secret-demo should exist
    And response header x-secret-demo should be `DEMO_SECRET`
