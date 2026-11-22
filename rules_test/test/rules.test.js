/**
 * Automated security-rules tests for the HW-02 message board.
 *
 * Proves the rules are their own authorization layer, independent of any UI:
 *   - a signed-out read is denied
 *   - a signed-in read is allowed
 *   - the author may create / update / delete their own message
 *   - a forged authorUid create is denied
 *   - a cross-uid update is denied
 *   - a cross-uid delete is denied
 *   - a user may read/write only their own private record
 */
const { readFileSync } = require('fs');
const { serverTimestamp } = require('firebase/firestore');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'message-board-rules-test';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

const authed = (uid) => testEnv.authenticatedContext(uid);
const unauthed = () => testEnv.unauthenticatedContext();

function validMessage(overrides = {}) {
  return {
    text: 'Hello board',
    authorUid: 'alice',
    authorName: 'Alice',
    createdAt: serverTimestamp(),
    editedAt: null,
    ...overrides,
  };
}

describe('messages: read', () => {
  it('denies a signed-out read', async () => {
    await assertFails(unauthed().firestore().collection('messages').get());
  });

  it('allows a signed-in read', async () => {
    await assertSucceeds(authed('alice').firestore().collection('messages').get());
  });
});

describe('messages: create', () => {
  it('allows the author to create their own message', async () => {
    const db = authed('alice').firestore();
    await assertSucceeds(db.collection('messages').doc('m1').set(validMessage()));
  });

  it('denies a forged authorUid (authorUid != auth.uid)', async () => {
    const db = authed('alice').firestore();
    await assertFails(
      db
        .collection('messages')
        .doc('forged')
        .set(validMessage({ authorUid: 'mallory' })),
    );
  });

  it('denies a client-supplied device timestamp instead of server time', async () => {
    const db = authed('alice').firestore();
    await assertFails(
      db
        .collection('messages')
        .doc('badclock')
        .set({ ...validMessage(), createdAt: new Date() }),
    );
  });
});

describe('messages: update and delete (ownership)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('messages')
        .doc('owned-by-alice')
        .set(validMessage());
    });
  });

  it('allows the author to update their own message', async () => {
    const db = authed('alice').firestore();
    await assertSucceeds(
      db.collection('messages').doc('owned-by-alice').update({ text: 'edited' }),
    );
  });

  it('denies a cross-uid update', async () => {
    const db = authed('bob').firestore();
    await assertFails(
      db.collection('messages').doc('owned-by-alice').update({ text: 'hacked' }),
    );
  });

  it('allows the author to delete their own message', async () => {
    const db = authed('alice').firestore();
    await assertSucceeds(db.collection('messages').doc('owned-by-alice').delete());
  });

  it('denies a cross-uid delete', async () => {
    const db = authed('bob').firestore();
    await assertFails(db.collection('messages').doc('owned-by-alice').delete());
  });
});

describe('users: private per-uid record', () => {
  it('allows a user to write their own record', async () => {
    const db = authed('alice').firestore();
    await assertSucceeds(
      db
        .collection('users')
        .doc('alice')
        .set({
          uid: 'alice',
          firstName: 'Alice',
          lastName: 'Doe',
          role: 'student',
          registrationDateTime: serverTimestamp(),
        }),
    );
  });

  it('denies a user writing another user\'s record', async () => {
    const db = authed('bob').firestore();
    await assertFails(
      db
        .collection('users')
        .doc('alice')
        .set({ uid: 'alice', firstName: 'Hacked' }),
    );
  });
});
