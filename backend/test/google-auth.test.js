import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, createSign } from 'node:crypto';
import { OAuth2Client } from 'google-auth-library';
import { googleVerifier } from '../src/google-auth.js';

const {privateKey, publicKey} = generateKeyPairSync('rsa', {modulusLength:2048});
const client = new OAuth2Client();
// Use the real Google verifier with a local test signing certificate.
client.getFederatedSignonCertsAsync = async () => ({certs:{test:publicKey.export({type:'spki',format:'pem'})}});
const audience = 'test-web-client.apps.googleusercontent.com';
const verify = googleVerifier(audience, client);
function jwt(overrides = {}, signingKey = privateKey) {
  const now = Math.floor(Date.now()/1000);
  const payload = {iss:'https://accounts.google.com', aud:audience, sub:'123456',
    email:'Owner@gmail.com',email_verified:true,name:'Owner',iat:now,exp:now+3600,...overrides};
  const content = [ {alg:'RS256',kid:'test'}, payload].map(v=>Buffer.from(JSON.stringify(v)).toString('base64url')).join('.');
  return `${content}.${createSign('RSA-SHA256').update(content).sign(signingKey).toString('base64url')}`;
}
test('Google ID token verification validates signature, issuer, audience, expiry and email', async () => {
  assert.deepEqual(await verify(jwt()),{sub:'123456',email:'owner@gmail.com',name:'Owner'});
  for (const changes of [{aud:'other-client'}, {iss:'https://attacker.example'}, {email_verified:false},
    {sub:''}, {email:''}, {iat:1,exp:2}]) await assert.rejects(verify(jwt(changes)));
  const other = generateKeyPairSync('rsa',{modulusLength:2048});
  await assert.rejects(verify(jwt({},other.privateKey)));
  await assert.rejects(verify('not-a-token'));
});
