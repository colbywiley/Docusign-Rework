@IsTest
private class FlowFileHelperTest {
    // Tiny, valid 1-page "Hello PDF!" Base64 (small & safe for tests)
    private static final String TINY_PDF_B64 =
        'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlIC9QYWdlL1BhcmVudCAyIDAgUi9Db250ZW50'
      + 'cyAzIDAgUi9NZWRpYUJveCBbMCAwIDUwMCA1MDBdPj4KZW5kb2JqCjMgMCBvYmoKPDwvTGVuZ3Ro'
      + 'IDQ0Pj4Kc3RyZWFtCkJUIApIZWxsbyBQRGYhCkVUCmVuZHN0cmVhbQplbmRvYmoKMiAwIG9iago8'
      + 'PC9UeXBlIC9QYWdlcy9LaWRzIFsgMSAwIFIgXS9Db3VudCAxPj4KZW5kb2JqCjQgMCBvYmoKPDwv'
      + 'VHlwZSAvQ2F0YWxvZy9QYWdlcyAyIDAgUj4+CmVuZG9iago1IDAgb2JqCjw8L1Byb2R1Y2VyIChU'
      + 'ZXN0IFBERik+PgplbmRvYmoKeHJlZgowIDYKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDEw'
      + 'IDAwMDAwIG4gCjAwMDAwMDA3NTAgMDAwMDAgbiAKMDAwMDAwMDE3NSAwMDAwMCBuIAowMDAwMDAw'
      + 'MTM0IDAwMDAwIG4gCjAwMDAwMDAyMzAgMDAwMDAgbiAKdHJhaWxlcgo8PC9Sb290IDQgMCBSL1Np'
      + 'emUgNj4+CnN0YXJ0eHJlZgozMTEKJSVFT0YK';

    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'FlowFileHelperTest Parent');
        insert a;
    }

    @IsTest
    static void testSavesPdfAndLinksToParent() {
        Account parent = [SELECT Id FROM Account LIMIT 1];

        // Prepare one request
        FlowFileHelper.FlowFileRequest r1 = new FlowFileHelper.FlowFileRequest();
        r1.base64Data     = TINY_PDF_B64;
        r1.fileName       = 'UnitTestSmartwaiver';
        r1.parentRecordId = parent.Id;

        // And a second request to ensure multiple items work
        FlowFileHelper.FlowFileRequest r2 = new FlowFileHelper.FlowFileRequest();
        r2.base64Data     = TINY_PDF_B64;
        r2.fileName       = 'UnitTestSmartwaiver2';
        r2.parentRecordId = parent.Id;

        Test.startTest();
        FlowFileHelper.savePdfFromBase64(new List<FlowFileHelper.FlowFileRequest>{ r1, r2 });
        Test.stopTest();

        // Assert ContentVersion records created
        List<ContentVersion> cvs = [
            SELECT Id, Title, PathOnClient, ContentDocumentId, IsLatest, VersionData
            FROM ContentVersion
            WHERE Title IN ('UnitTestSmartwaiver', 'UnitTestSmartwaiver2')
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(2, cvs.size(), 'Should create two ContentVersion rows');
        for (ContentVersion cv : cvs) {
            System.assertEquals(true, cv.IsLatest, 'Inserted version should be latest');
            System.assert(cv.Title == 'UnitTestSmartwaiver' || cv.Title == 'UnitTestSmartwaiver2');
            System.assert(cv.PathOnClient.endsWith('.pdf'), 'PathOnClient must end with .pdf');
            System.assertNotEquals(null, cv.ContentDocumentId, 'ContentDocumentId should be populated');
            System.assert(cv.VersionData != null && cv.VersionData.size() > 0, 'PDF blob should have bytes');
        }

        // Assert ContentDocumentLink auto-created for parent (FirstPublishLocationId)
        // There should be at least one link for the parent record
        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :parent.Id
        ];
        System.assert(links.size() >= 2, 'Expected links created to the parent record');

        // Cross-check that each ContentVersion's document is linked to the parent
        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : cvs) docIds.add(cv.ContentDocumentId);
        Integer matched = 0;
        for (ContentDocumentLink l : links) if (docIds.contains(l.ContentDocumentId)) matched++;
        System.assertEquals(2, matched, 'Both documents should be linked to the parent');
    }

    @IsTest
    static void testBadBase64Throws() {
        Account parent = [SELECT Id FROM Account LIMIT 1];

        FlowFileHelper.FlowFileRequest bad = new FlowFileHelper.FlowFileRequest();
        bad.base64Data     = 'not-base64!!!';
        bad.fileName       = 'ShouldFail';
        bad.parentRecordId = parent.Id;

        Boolean threw = false;
        Test.startTest();
        try {
            FlowFileHelper.savePdfFromBase64(new List<FlowFileHelper.FlowFileRequest>{ bad });
        } catch (Exception e) {
            threw = true;
            // Expect a base64 decode error
            System.assert(e.getMessage().toLowerCase().contains('invalid') || e.getMessage().toLowerCase().contains('base64'),
                'Should throw due to invalid Base64');
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Method should throw on invalid Base64 input');
    }
}