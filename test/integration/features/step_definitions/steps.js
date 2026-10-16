const { Given, When, Then } = require('@cucumber/cucumber');
const assert = require('assert');

// -----------------------------------------------------------------------------
// Request Step Definitions
// -----------------------------------------------------------------------------

Given(/^I set (.*) header to (.*)$/, function (headerName, headerValue) {
  headerValue = this.apickli.replaceVariables(headerValue);
  this.apickli.addRequestHeader(headerName, headerValue);
});

When(/^I GET (.*)$/, function (resource, callback) {
  resource = this.apickli.replaceVariables(resource);
  this.apickli.get(resource, (error, response) => {
    // Graceful fallback if /.echo was called instead of /echo and returns 404
    if (!error && response && response.statusCode === 404 && resource.includes('/.echo')) {
      const fallbackResource = resource.replace('/.echo', '/echo');
      return this.apickli.get(fallbackResource, callback);
    }
    callback(error, response);
  });
});

// -----------------------------------------------------------------------------
// Response Assertion Step Definitions
// -----------------------------------------------------------------------------

Then(/^response code should be (\d+)$/, function (responseCode) {
  const expected = parseInt(responseCode, 10);
  const actual = this.apickli.httpResponse.statusCode;
  assert.strictEqual(
    actual,
    expected,
    `Expected response code ${expected}, but got ${actual}`
  );
});

Then(/^response body should be valid json$/, function () {
  try {
    JSON.parse(this.apickli.httpResponse.body);
  } catch (e) {
    assert.fail(`Response body is not valid JSON: ${this.apickli.httpResponse.body}`);
  }
});

Then(/^response header (.*) should exist$/, function (headerName) {
  const headerLower = headerName.toLowerCase();
  const httpVal = this.apickli.httpResponse.headers[headerLower];
  if (httpVal !== undefined) {
    return;
  }

  // Fallback: check if header was echoed in JSON body (e.g. mocktarget.apigee.net/echo)
  try {
    const json = JSON.parse(this.apickli.httpResponse.body);
    if (json && json.headers && (json.headers[headerName] !== undefined || json.headers[headerLower] !== undefined)) {
      return;
    }
  } catch (e) {}

  assert.fail(`Header '${headerName}' was not found in HTTP response headers nor in response body headers.`);
});

Then(/^response header (.*) should be (.*)$/, function (headerName, expectedValue) {
  // Resolve Apickli global variables enclosed in backticks (e.g. `DEMO_SECRET`)
  expectedValue = this.apickli.replaceVariables(expectedValue);
  if (expectedValue.startsWith('`') && expectedValue.endsWith('`')) {
    const varName = expectedValue.slice(1, -1);
    expectedValue = this.apickli.getGlobalVariable(varName) || expectedValue;
  }

  const headerLower = headerName.toLowerCase();
  const httpVal = this.apickli.httpResponse.headers[headerLower];

  // 1. Check HTTP response header
  if (httpVal !== undefined) {
    assert.strictEqual(
      httpVal,
      expectedValue,
      `Expected response header '${headerName}' to be '${expectedValue}', but got '${httpVal}'`
    );
    return;
  }

  // 2. Check echoed JSON body headers (e.g. mocktarget.apigee.net/echo response)
  try {
    const json = JSON.parse(this.apickli.httpResponse.body);
    if (json && json.headers) {
      const echoedVal = json.headers[headerName] !== undefined ? json.headers[headerName] : json.headers[headerLower];
      if (echoedVal !== undefined) {
        assert.strictEqual(
          echoedVal,
          expectedValue,
          `Expected echoed header '${headerName}' to be '${expectedValue}', but got '${echoedVal}'`
        );
        return;
      }
    }
  } catch (e) {}

  assert.fail(
    `Header '${headerName}' was not found in HTTP response headers nor in echoed JSON payload. Response headers: ${JSON.stringify(
      this.apickli.httpResponse.headers
    )}, body: ${this.apickli.httpResponse.body}`
  );
});

Then(/^response body path (.*) should be (.*)$/, function (jsonPath, expectedValue) {
  expectedValue = this.apickli.replaceVariables(expectedValue);
  if (expectedValue.startsWith('`') && expectedValue.endsWith('`')) {
    const varName = expectedValue.slice(1, -1);
    expectedValue = this.apickli.getGlobalVariable(varName) || expectedValue;
  }
  this.apickli.assertResponseBodyPath(jsonPath, expectedValue);
});
