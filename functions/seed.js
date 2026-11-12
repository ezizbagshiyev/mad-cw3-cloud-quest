import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Seed only the local Firestore emulator.');
initializeApp({projectId: 'demo-cloud-quest'});
await getFirestore().doc('challenges/today').set({
  title: 'Identity and access',
  prompt: 'Explain the difference between Firebase Authentication and Firestore Security Rules in one sentence.',
});
console.log('Seeded challenges/today in the local emulator.');
