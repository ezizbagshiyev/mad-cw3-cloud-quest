import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {awardOnce, validateQuestion} from './core.js';
import {runQuestCoach} from './questCoach.js';
import {coachMode} from './modelGateway.js';

initializeApp();
const db = getFirestore();
const fail = (code, message) => new HttpsError(code, message);

export const completeToday = onCall(async (request) => {
  if (!request.auth) throw fail('unauthenticated', 'Sign in first.');
  if (request.data?.challengeId !== 'today') throw fail('invalid-argument', 'Unknown challenge.');
  const ref = db.doc(`users/${request.auth.uid}/progress/today`);
  return db.runTransaction(async (transaction) => {
    const challenge = await transaction.get(db.doc('challenges/today'));
    if (!challenge.exists) throw fail('not-found', 'Challenge missing.');
    return awardOnce(transaction, ref, () => FieldValue.serverTimestamp());
  });
});

export const askQuestCoach = onCall(async (request) => {
  if (!request.auth) throw fail('unauthenticated', 'Sign in first.');
  const question = validateQuestion(request.data, fail);
  try {
    const read = async (path) => (await db.doc(path).get()).data();
    return {reply: await runQuestCoach(request.auth.uid, question, read), mode: coachMode()};
  } catch (_) {
    throw fail('unavailable', 'The coach is unavailable. Try again.');
  }
});
