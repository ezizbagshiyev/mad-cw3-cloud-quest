import {COACH_INSTRUCTIONS} from './core.js';

export function coachMode(env = process.env) {
  if (env.QUEST_COACH_MODE === 'demo') return 'demo';
  if (env.COURSE_MODEL_GATEWAY_URL) return 'gateway';
  if (env.GEMINI_API_KEY) return 'gemini';
  return env.FUNCTIONS_EMULATOR === 'true' ? 'demo' : 'unconfigured';
}

// Server only. The key is a header, never part of a URL, reply, or log.
export async function generateLiveHint(question, state, env = process.env, send = fetch) {
  const mode = coachMode(env);
  let endpoint;
  let headers = {'Content-Type': 'application/json'};
  let body;
  if (mode === 'gemini') {
    const model = env.QUEST_COACH_MODEL || 'gemini-flash-latest';
    if (!/^[a-zA-Z0-9._-]+$/.test(model)) throw new Error('Invalid model configuration.');
    endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    headers['x-goog-api-key'] = env.GEMINI_API_KEY;
    body = {
      systemInstruction: {parts: [{text: COACH_INSTRUCTIONS}]},
      contents: [{role: 'user', parts: [{text: JSON.stringify({question, questState: state})}]}],
      generationConfig: {maxOutputTokens: 400, temperature: 0.2},
    };
  } else if (mode === 'gateway') {
    endpoint = env.COURSE_MODEL_GATEWAY_URL;
    if (!endpoint.startsWith('https://')) throw new Error('HTTPS gateway required.');
    body = {instructions: COACH_INSTRUCTIONS, question, state};
  } else {
    throw new Error('Live model is not configured.');
  }
  const response = await send(endpoint, {
    method: 'POST', signal: AbortSignal.timeout(25000), headers, body: JSON.stringify(body),
  });
  // Never surface provider bodies, which may include configuration details.
  if (!response.ok) throw new Error('Model unavailable.');
  const output = await response.json();
  const reply = mode === 'gemini'
    ? output.candidates?.[0]?.content?.parts?.filter(part => !part.thought).map(part => part.text || '').join('')
    : output.reply;
  if (typeof reply !== 'string' || !reply.trim() || reply.length > 1600) throw new Error('Invalid model reply.');
  return reply.trim();
}
