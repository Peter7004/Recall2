import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recall/bundled_vocabulary.dart';
import 'package:recall/recall_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'v1 to 834-term v2 preserves old IDs, edits, reviews and source references',
    () async {
      final old = BundledVocabulary(
        version: 1,
        csvText: [
          recallV3Columns.join(','),
          [
            'Absorption',
            'technical',
            '기존 뜻',
            'noun',
            '',
            '',
            '',
            'medium',
            '',
            'include',
            '',
            '',
            '',
          ].join(','),
          [
            'Legacy-only term',
            'technical',
            '옛 용어',
            'noun',
            '',
            '',
            '',
            'medium',
            '',
            'include',
            '',
            '',
            '',
          ].join(','),
        ].join('\n'),
      );
      final store = await RecallStore.load(bundledVocabulary: old);
      final absorption = store.searchCards('Absorption').single.card;
      final legacy = store.searchCards('Legacy-only term').single.card;
      await store.updateCard(
        deckId: '',
        cardId: absorption.id,
        front: absorption.front,
        meaning: '사용자가 수정한 뜻',
        example: 'Keep my sentence.',
      );
      await store.toggleBookmark(absorption.id);
      await store.markReviewed(absorption.id);
      await store.recordCardViewed(legacy.id);
      await store.createDeck('My collection');
      await store.addEntryToDeck(
        deckId: store.decks.last.id,
        cardId: absorption.id,
      );
      final deckId = store.decks.last.id;
      final before = {
        for (final e in store.allCards) e.card.id: e.card.toJson(),
      };
      final prefs = await SharedPreferences.getInstance();
      final reader =
          '{"cardId":"${absorption.id}","documentId":"my-pdf","page":2}';
      await prefs.setString('recall.reader.learning.v1', reader);
      store.dispose();
      final catalog = BundledVocabulary(
        version: 2,
        csvText: File('assets/vocabulary/recall_core_v1.csv')
            .readAsStringSync(),
      );
      expect(catalog.rows.length, 834);
      final upgraded = await RecallStore.load(bundledVocabulary: catalog);
      for (final entry in before.entries) {
        expect(upgraded.cardById(entry.key)?.toJson(), entry.value);
      }
      expect(
        upgraded.totalCards,
        835,
      ); // 834 catalog terms plus the retained legacy term.
      expect(upgraded.deckById(deckId)!.cards.single.id, absorption.id);
      expect(upgraded.reviewsToday, 1);
      expect(upgraded.recentCards.single.card.id, legacy.id);
      expect(prefs.getString('recall.reader.learning.v1'), reader);
      final serialized = prefs.getString('recall.data.v3');
      upgraded.dispose();
      final reloaded = await RecallStore.load(bundledVocabulary: catalog);
      expect(reloaded.cardById(absorption.id)?.toJson(), before[absorption.id]);
      expect(prefs.getString('recall.data.v3'), serialized);
    },
  );
}
