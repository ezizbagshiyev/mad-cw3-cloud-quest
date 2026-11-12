import {genkit, z} from 'genkit';
import {emulatorHint, readMyQuestState} from './core.js';
import {coachMode, generateLiveHint} from './modelGateway.js';

// No UID/tool name from learner input. Each invocation closes over verified UID.
export async function runQuestCoach(uid, question, read) {
  const ai = genkit({});
  const readTool = ai.defineTool({
    name: `readMyQuestState`,
    description: 'Read only the verified caller\'s challenge and progress.',
    inputSchema: z.object({}),
  }, async () => readMyQuestState(uid, read));
  const flow = ai.defineFlow({name: 'questCoach', inputSchema: z.string()}, async (input) => {
    // Mandatory tool step; no generated hint is possible if this throws.
    const state = await readTool({});
    if (process.env.FUNCTIONS_EMULATOR === 'true' && input === '[simulate-model-failure]') {
      throw new Error('Simulated model failure.');
    }
    if (coachMode() === 'demo') {
      return emulatorHint(state);
    }
    // No course gateway was supplied. This is an adapter for its server endpoint.
    // Fail closed until the course gateway is configured; never use a client key.
    return generateLiveHint(input, state);
  });
  return flow(question);
}
