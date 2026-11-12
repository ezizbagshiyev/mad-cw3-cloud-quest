import {test} from 'node:test';
import assert from 'node:assert/strict';
import {coachMode, generateLiveHint} from '../modelGateway.js';

test('live mode requires configuration, with explicit demo override', () => {
  assert.equal(coachMode({}), 'unconfigured');
  assert.equal(coachMode({FUNCTIONS_EMULATOR:'true'}), 'demo');
  assert.equal(coachMode({GEMINI_API_KEY:'test-key-not-real'}), 'gemini');
  assert.equal(coachMode({COURSE_MODEL_GATEWAY_URL:'https://example.test'}), 'gateway');
  assert.equal(coachMode({QUEST_COACH_MODE:'demo', GEMINI_API_KEY:'test-key-not-real'}), 'demo');
});

test('Gemini adapter keeps key exclusively in server request header', async () => {
  const env = {GEMINI_API_KEY:'test-key-not-real'};
  const state = {challenge:{title:'Identity',prompt:'Compare Auth and Rules'},progress:{points:0}};
  const reply = await generateLiveHint('Help', state, env, async (url, options) => {
    assert.equal(options.headers['x-goog-api-key'], env.GEMINI_API_KEY);
    assert.ok(!url.includes(env.GEMINI_API_KEY));
    assert.ok(!options.body.includes(env.GEMINI_API_KEY));
    assert.deepEqual(JSON.parse(JSON.parse(options.body).contents[0].parts[0].text), {question:'Help',questState:state});
    return {ok:true,json:async()=>({candidates:[{content:{parts:[{text:'Consider which service verifies identity.'}]}}]})};
  });
  assert.equal(reply, 'Consider which service verifies identity.');
});

test('provider error details are not surfaced; no fallback fabricates live output', async () => {
  await assert.rejects(() => generateLiveHint('Help', {}, {}, async()=>{}), /not configured/);
  await assert.rejects(() => generateLiveHint('Help', {}, {GEMINI_API_KEY:'test-key-not-real'}, async()=>({ok:false})), /Model unavailable/);
  await assert.rejects(() => generateLiveHint('Help', {}, {GEMINI_API_KEY:'test-key-not-real'}, async()=>({ok:true,json:async()=>({})})), /Invalid model reply/);
});
