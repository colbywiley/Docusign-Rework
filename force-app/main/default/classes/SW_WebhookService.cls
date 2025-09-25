@RestResource(urlMapping='/smartwaiver/*')
global with sharing class SW_WebhookService {

    @HttpPost
    global static void receiveWebhook() {
        RestRequest req = RestContext.request;

        // The body is empty if they're using form-encoded data,
        // but the parameters exist in req.params
        String eventParam     = req.params.get('event');
        String uniqueIdParam  = req.params.get('unique_id');
        String credentialParam = req.params.get('credential');
        
        // Build a string or JSON out of these params for your record
        String eventType = eventParam;
        String uniqueId = uniqueIdParam;
        String credential = credentialParam;

        Smartwaiver_Event__c swe = new Smartwaiver_Event__c();
        swe.Event_Type__c = eventType; 
        swe.Unique_Id__c = uniqueId;
        swe.Credential__c = credential;
        swe.Status__c = 'Received';
        insert swe;
        
        RestContext.response.statusCode = 200;
        RestContext.response.responseBody = Blob.valueOf('OK');
    }
}