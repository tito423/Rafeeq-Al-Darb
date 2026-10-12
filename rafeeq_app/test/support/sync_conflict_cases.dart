import 'package:flutter_test/flutter_test.dart';
import 'sync_conflict_restore.dart';

void syncConflictRestoreCases() {
  test('A04 migrate existing local page before pulling an old snapshot', () {
    return verifySyncConflict(
      localPage: 541,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 541,
    );
  });
  test('A04 edit during a pending pull cannot be reverted by its reply', () {
    return verifySyncConflict(
      localPage: 541,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 543,
      editDuringPull: true,
    );
  });
  test('A04 first device restore accepts valid remote state', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 540,
    );
  });
  test('A04 rejects a malformed remote modification time', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: '100',
      expectedPage: null,
    );
  });
  test('A04 successful pull refreshes the already mounted reader state', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 540,
      observeLastPage: true,
    );
  });
  test('A04 successful pull refreshes the already mounted ayah notes', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 540,
      observeNotes: true,
    );
  });
  test('A04 successful pull refreshes the already mounted khatma progress', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 540,
      observeKhatma: true,
    );
  });
  test('A04 acknowledged counter increment survives an older pending GET', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 540,
      incrementDuringPull: true,
    );
  });
  for (final remoteTime in [100, 200, 300]) {
    test(
      'A04 compares persisted local timestamp200 with remote$remoteTime',
      () {
        return verifySyncConflict(
          localPage: 541,
          localTimestamp: 200,
          remotePage: 540,
          remoteTimestamp: remoteTime,
          expectedPage: remoteTime > 200 ? 540 : 541,
          observeLastPage: true,
        );
      },
    );
  }
  for (final invalidTime in [-1, 1.5, true, null, 9007199254740992]) {
    test('A04 ignores invalid remote timestamp$invalidTime', () {
      return verifySyncConflict(
        localPage: null,
        remotePage: 540,
        remoteTimestamp: invalidTime,
        expectedPage: null,
      );
    });
  }
  test(
    'A04 edit before debounce survives offline restart and old backend pull',
    () {
      return verifySyncConflict(
        localPage: 541,
        remotePage: 540,
        remoteTimestamp: 100,
        expectedPage: 543,
        offlineRestart: true,
      );
    },
  );
  test(
    'A04 pending data stay with their account through switch and switch back',
    () {
      return verifySyncConflict(
        localPage: 541,
        remotePage: 540,
        remoteTimestamp: 100,
        expectedPage: 541,
        switchAccounts: true,
        observeLastPage: true,
      );
    },
  );
  test('A04 sign out during GET cannot resurrect account data or journals', () {
    return verifySyncConflict(
      localPage: 541,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: null,
      signOutDuringPull: true,
      observeLastPage: true,
    );
  });
  test(
    'A04 custom target writes are captured without restamping other state',
    () {
      return verifySyncConflict(
        localPage: null,
        remotePage: 540,
        remoteTimestamp: 100,
        expectedPage: 540,
        writeCustomTargetDuringPull: true,
      );
    },
  );
  for (final invalidPage in [0, 605, '540', true, 1.5, <String, Object>{}]) {
    test(
      'A04 malformed remote page$invalidPage cannot replace valid local state',
      () {
        return verifySyncConflict(
          localPage: 541,
          localTimestamp: 200,
          remotePage: invalidPage,
          remoteTimestamp: 300,
          expectedPage: 541,
          observeLastPage: true,
        );
      },
    );
  }
  test(
    'A04 counter started before GET and acknowledged during GET cannot roll back',
    () {
      return verifySyncConflict(
        localPage: null,
        remotePage: 540,
        remoteTimestamp: 100,
        expectedPage: 540,
        incrementBeforePull: true,
      );
    },
  );
  test('A04 server total including a pending counter is not counted twice', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 540,
      counterReplyAfterPull: true,
    );
  });
  test('A04 edit during a remote preference reply keeps its dirty journal', () {
    return verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 543,
      observeLastPage: true,
      editDuringPreferenceReply: true,
    );
  });
  test(
    'A04 sign out during remote preference persistence cannot recreate a journal',
    () {
      return verifySyncConflict(
        localPage: null,
        remotePage: 540,
        remoteTimestamp: 100,
        expectedPage: null,
        observeLastPage: true,
        signOutDuringPreferenceReply: true,
      );
    },
  );
}
