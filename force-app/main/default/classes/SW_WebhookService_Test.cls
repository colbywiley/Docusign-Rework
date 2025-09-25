@IsTest
private class SW_WebhookService_Test {
    @IsTest static void testReceiveWebhook_InsertsEventAndReturnsOK() {
        // 1) Build the RestRequest
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/smartwaiver';
        req.httpMethod = 'POST';
        
        // 2) Populate the params map directly
        req.params.put('event',      'signed');
        req.params.put('unique_id',  'ABC123');
        req.params.put('credential', 'Cred001');
        
        // 3) Tie into the RestContext
        RestResponse resp = new RestResponse();
        RestContext.request  = req;
        RestContext.response = resp;

        Test.startTest();
            SW_WebhookService.receiveWebhook();
        Test.stopTest();

        // 4) Verify insertion of the event record
        List<Smartwaiver_Event__c> recs = [
            SELECT Event_Type__c, Unique_Id__c, Credential__c, Status__c
              FROM Smartwaiver_Event__c
             WHERE Unique_Id__c = 'ABC123'
        ];
        System.assertEquals(1, recs.size(), 'Should insert exactly one event record');
        System.assertEquals('signed',   recs[0].Event_Type__c);
        System.assertEquals('Cred001',  recs[0].Credential__c);
        System.assertEquals('Received', recs[0].Status__c);

        // 5) Verify the HTTP response
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('OK', RestContext.response.responseBody.toString());
    }
}