const apickli = require('apickli');
const { Before: before, setDefaultTimeout } = require('@cucumber/cucumber');

// Set step timeout
setDefaultTimeout(30 * 1000);

// Disable TLS verification for test endpoints (e.g. nip.io)
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const apigeeHostname = process.env.APIGEE_HOSTNAME || '34.54.8.132.nip.io';
const demoSecret = process.env.DEMO_SECRET || '';

before(function () {
  this.apickli = new apickli.Apickli('https', apigeeHostname);
  this.apickli.setGlobalVariable('DEMO_SECRET', demoSecret);
  this.apickli.setGlobalVariable('APIGEE_HOSTNAME', apigeeHostname);
});
